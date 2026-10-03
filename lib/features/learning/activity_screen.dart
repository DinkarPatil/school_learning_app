import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:school_learning_app/app/app_controller.dart';
import 'package:school_learning_app/app/app_scope.dart';
import 'package:school_learning_app/app/route_names.dart';
import 'package:school_learning_app/app/theme.dart';
import 'package:school_learning_app/core/errors/app_failure.dart';
import 'package:school_learning_app/core/haptics/haptics_service.dart';
import 'package:school_learning_app/core/speech/speech_service.dart';
import 'package:school_learning_app/data/content/content_models.dart';
import 'package:school_learning_app/features/learning/learning_shell.dart';
import 'package:school_learning_app/features/learning/lesson_audio.dart';

const String kSaveFailureMessage =
    'We could not save that yet. Please try again.';
const String kMissingActivityTitle = 'Let us choose something else';
const int kQuizAttempts = 2;
const Duration kSaveTimeout = Duration(seconds: 4);

enum ActivityStep { story, flashcards, quiz, practice, reward }

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({
    super.key,
    this.activityId,
    this.onGoHome,
    this.onBack,
  });

  final String? activityId;
  final VoidCallback? onGoHome;
  final VoidCallback? onBack;

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  late final AppController _controller;
  late final LessonAudioController _audio;
  late final HapticsService _haptics;
  final Map<int, int> _answers = <int, int>{};
  final Map<int, int> _attempts = <int, int>{};
  final Set<int> _scored = <int>{};
  final Set<int> _locked = <int>{};

  ActivityStep? _step;
  int _stepIndex = 0;
  int _score = 0;
  int _cardIndex = 0;
  int _questionIndex = 0;
  bool _cardRevealed = false;
  bool _quizScoreSaved = false;
  bool _quizSaveInFlight = false;
  bool _practiceRecorded = false;
  bool _practiceSaveInFlight = false;
  bool _completionRequested = false;
  bool _saved = false;
  String? _quizError;
  String? _practiceError;
  String? _saveError;
  String? _activityId;

  @override
  void initState() {
    super.initState();
    final controller = AppScope.read(context);
    _controller = controller;
    _haptics = controller.haptics;
    _audio = LessonAudioController(
      audio: controller.audio,
      speech: controller.speech,
    );
  }

  @override
  void dispose() {
    unawaited(_audio.stop());
    unawaited(_persistQuizScoreOnDispose());
    _audio.dispose();
    super.dispose();
  }

  Future<void> _persistQuizScoreOnDispose() async {
    if (_quizScoreSaved || _quizSaveInFlight) {
      return;
    }
    final activityId = _activityId;
    if (activityId == null || activityId.isEmpty) {
      return;
    }
    _quizSaveInFlight = true;
    await _trySave(
      () => _controller.recordQuizScore(activityId, _score),
    );
    _quizSaveInFlight = false;
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final activity = _resolveActivity(controller);
    if (activity == null) {
      return _missingScaffold(context, controller);
    }
    final text = controller.textFor(activity);
    final steps = buildSteps(activity);
    final step = _step ?? steps.first;
    final index = _stepIndex;
    return LearningScaffold(
      title: text.title,
      onGoHome: () => _goHome(context, controller),
      onBack: () => _goBack(context, controller),
      body: _buildStep(
        context,
        controller,
        activity,
        text,
        steps,
        step,
        index,
      ),
    );
  }

  ActivityContent? _resolveActivity(AppController controller) {
    final id = widget.activityId ?? controller.activeActivityId;
    if (id == null || id.trim().isEmpty) {
      _activityId = null;
      return null;
    }
    final activity = controller.activityById(id);
    _activityId = activity?.id;
    return activity;
  }

  Widget _missingScaffold(BuildContext context, AppController controller) {
    return LearningScaffold(
      title: 'Activity',
      onGoHome: () => _goHome(context, controller),
      onBack: () => _goBack(context, controller),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const Expanded(
            child: LearningMessage(
              icon: Icons.explore_outlined,
              title: kMissingActivityTitle,
              body: 'This activity is not here right now.',
            ),
          ),
          LearningActionBar(
            actions: <Widget>[
              FilledButton(
                onPressed: () => _goHome(context, controller),
                child: const Text('Go home'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStep(
    BuildContext context,
    AppController controller,
    ActivityContent activity,
    ActivityText text,
    List<ActivityStep> steps,
    ActivityStep step,
    int index,
  ) {
    switch (step) {
      case ActivityStep.story:
        return _buildStory(context, activity, text, steps, index);
      case ActivityStep.flashcards:
        return _buildFlashcards(context, activity, text, steps, index);
      case ActivityStep.quiz:
        return _buildQuiz(context, controller, activity, steps, index);
      case ActivityStep.practice:
        return _buildPractice(context, controller, activity, steps, index);
      case ActivityStep.reward:
        return _buildReward(context, controller, activity, text, steps, index);
    }
  }

  int _stepBackIndex(List<ActivityStep> steps, int index) {
    final target = index - 1;
    if (target < 0) {
      return 0;
    }
    if (steps[target] == ActivityStep.practice && _practiceRecorded) {
      return (target - 1).clamp(0, steps.length - 1);
    }
    return target;
  }

  Widget _buildStory(
    BuildContext context,
    ActivityContent activity,
    ActivityText text,
    List<ActivityStep> steps,
    int index,
  ) {
    return LearningStepBody(
      key: const ValueKey('story'),
      actions: <Widget>[
        FilledButton(
          onPressed: () => _goToStep(steps, index + 1),
          child: const Text('Next step'),
        ),
        if (index > 0)
          OutlinedButton(
            onPressed: () => _goToStep(steps, index - 1),
            child: const Text('Previous step'),
          ),
      ],
      children: <Widget>[
        StepHeader(
          index: index + 1,
          total: steps.length,
          label: 'Listen to the story',
        ),
        const SizedBox(height: 16),
        Text(
          text.story,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 16),
        LessonAudioBar(
          controller: _audio,
          audioAsset: activity.audioAsset,
          speechText: text.story,
          language: SpeechService.mapLanguage(text.language),
        ),
      ],
    );
  }

  Widget _buildFlashcards(
    BuildContext context,
    ActivityContent activity,
    ActivityText text,
    List<ActivityStep> steps,
    int index,
  ) {
    final cards = activity.flashcards;
    final safeIndex = _cardIndex.clamp(0, cards.length - 1);
    final card = cards[safeIndex];
    final isLast = safeIndex == cards.length - 1;
    return LearningStepBody(
      key: const ValueKey('flashcards'),
      actions: <Widget>[
        if (!_cardRevealed)
          FilledButton(
            onPressed: () => setState(() => _cardRevealed = true),
            child: const Text('Show the answer'),
          )
        else
          FilledButton(
            onPressed: () {
              if (isLast) {
                _goToStep(steps, index + 1);
                return;
              }
              setState(() {
                _cardIndex = safeIndex + 1;
                _cardRevealed = false;
              });
            },
            child: Text(isLast ? 'Next step' : 'Next card'),
          ),
        OutlinedButton(
          onPressed: () => _goToStep(steps, index - 1),
          child: const Text('Previous step'),
        ),
      ],
      children: <Widget>[
        StepHeader(
          index: index + 1,
          total: steps.length,
          label: 'Learn the words',
        ),
        const SizedBox(height: 16),
        Semantics(
          container: true,
          label: 'Card ${safeIndex + 1} of ${cards.length}',
          child: ExcludeSemantics(
            child: Text(
              'Card ${safeIndex + 1} of ${cards.length}',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  card.front,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 12),
                if (_cardRevealed)
                  Text(
                    card.back,
                    style: Theme.of(context).textTheme.titleLarge,
                  )
                else
                  const Text('Tap to see the answer.'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        LessonAudioBar(
          controller: _audio,
          audioAsset: card.audioAsset,
          speechText:
              _cardRevealed ? '${card.front}. ${card.back}' : card.front,
          language: SpeechService.mapLanguage(text.language),
        ),
      ],
    );
  }

  Widget _buildQuiz(
    BuildContext context,
    AppController controller,
    ActivityContent activity,
    List<ActivityStep> steps,
    int index,
  ) {
    final questions = activity.questions;
    final safeIndex = _questionIndex.clamp(0, questions.length - 1);
    final question = questions[safeIndex];
    final locked = _locked.contains(safeIndex);
    final answer = _answers[safeIndex];
    final attempts = _attempts[safeIndex] ?? 0;
    final isLast = safeIndex == questions.length - 1;
    final correct = locked && answer == question.answerIndex;
    return LearningStepBody(
      key: const ValueKey('quiz'),
      actions: <Widget>[
        if (locked)
          FilledButton(
            onPressed: _quizSaveInFlight
                ? null
                : () async {
                    if (isLast) {
                      final saved = await _persistQuizScore(
                        controller,
                        activity,
                      );
                      if (!mounted || !saved) {
                        return;
                      }
                      _goToStep(steps, index + 1);
                      return;
                    }
                    setState(() => _questionIndex = safeIndex + 1);
                  },
            child: Text(isLast ? 'Next step' : 'Next question'),
          ),
        OutlinedButton(
          onPressed: () =>
              _leaveQuiz(context, controller, activity, steps, index),
          child: const Text('Previous step'),
        ),
      ],
      children: <Widget>[
        StepHeader(
          index: index + 1,
          total: steps.length,
          label: 'Try the quiz',
        ),
        const SizedBox(height: 16),
        if (_quizError != null) _SaveRetryNotice(message: _quizError!),
        Semantics(
          container: true,
          label: 'Question ${safeIndex + 1} of ${questions.length}',
          child: ExcludeSemantics(
            child: Text(
              'Question ${safeIndex + 1} of ${questions.length}',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          question.prompt,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 16),
        if (attempts > 0)
          _QuizFeedback(
            correct: correct,
            retry: !locked,
            hint: question.hint,
            answer: question.options[question.answerIndex],
          ),
        if (!locked) ...<Widget>[
          if (attempts > 0) const SizedBox(height: 16),
          ResponsiveTileGrid(
            minItemWidth: 160,
            spacing: 12,
            maxColumns: 2,
            itemCount: question.options.length,
            itemBuilder: (context, optionIndex) => OptionButton(
              label: question.options[optionIndex],
              haptics: _haptics,
              onTap: () => _answerQuestion(
                controller,
                activity,
                safeIndex,
                optionIndex,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPractice(
    BuildContext context,
    AppController controller,
    ActivityContent activity,
    List<ActivityStep> steps,
    int index,
  ) {
    return LearningStepBody(
      key: const ValueKey('practice'),
      actions: <Widget>[
        FilledButton(
          onPressed: _practiceRecorded || _practiceSaveInFlight
              ? null
              : () => _recordPractice(controller, activity, steps, index),
          child: const Text('I finished practicing'),
        ),
        OutlinedButton(
          onPressed: () => _goToStep(steps, index - 1),
          child: const Text('Previous step'),
        ),
      ],
      children: <Widget>[
        StepHeader(
          index: index + 1,
          total: steps.length,
          label: 'Your turn to practice',
        ),
        const SizedBox(height: 16),
        if (_practiceError != null) _SaveRetryNotice(message: _practiceError!),
        Text(
          activity.practicePrompt.isEmpty
              ? 'Write or draw what you remember.'
              : activity.practicePrompt,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        if (activity.practiceHint.isNotEmpty) ...<Widget>[
          const SizedBox(height: 8),
          Text(activity.practiceHint),
        ],
        const SizedBox(height: 16),
        const DrawingPad(),
      ],
    );
  }

  Widget _buildReward(
    BuildContext context,
    AppController controller,
    ActivityContent activity,
    ActivityText text,
    List<ActivityStep> steps,
    int index,
  ) {
    final alreadyCompleted =
        controller.progress.completedActivityIds.contains(activity.id);
    final backIndex = _stepBackIndex(steps, index);
    return LearningStepBody(
      key: const ValueKey('reward'),
      actions: <Widget>[
        if (alreadyCompleted)
          OutlinedButton(
            onPressed: () => _goToStep(steps, backIndex),
            child: const Text('Practice again'),
          )
        else
          FilledButton(
            onPressed: _completionRequested ? null : _finish,
            child: const Text('Finish'),
          ),
        FilledButton(
          onPressed: () => _goHome(context, controller),
          child: const Text('Go home'),
        ),
        OutlinedButton(
          onPressed: () => _goToStep(steps, backIndex),
          child: const Text('Previous step'),
        ),
      ],
      children: <Widget>[
        StepHeader(
          index: index + 1,
          total: steps.length,
          label: 'You did it!',
        ),
        const SizedBox(height: 16),
        const _RewardBadge(),
        const SizedBox(height: 12),
        Text(
          'Great job! You finished ${text.title}.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          'You answered $_score of ${activity.questions.length} quiz questions.',
          textAlign: TextAlign.center,
        ),
        if (alreadyCompleted) ...<Widget>[
          const SizedBox(height: 12),
          const Text(
            'You finished this activity before.',
            textAlign: TextAlign.center,
          ),
        ],
        if (_saved) ...<Widget>[
          const SizedBox(height: 12),
          Text(
            'Saved. You finished this activity.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.success,
                  fontWeight: FontWeight.w800,
                ),
          ),
        ],
        if (_saveError != null) ...<Widget>[
          const SizedBox(height: 12),
          Text(
            _saveError!,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.error,
                  fontWeight: FontWeight.w800,
                ),
          ),
        ],
      ],
    );
  }

  void _answerQuestion(
    AppController controller,
    ActivityContent activity,
    int questionIndex,
    int optionIndex,
  ) {
    if (_locked.contains(questionIndex)) {
      return;
    }
    final attempts = (_attempts[questionIndex] ?? 0) + 1;
    if (attempts > kQuizAttempts) {
      return;
    }
    final question = activity.questions[questionIndex];
    final isCorrect = optionIndex == question.answerIndex;
    setState(() {
      _attempts[questionIndex] = attempts;
      if (isCorrect) {
        _answers[questionIndex] = optionIndex;
        _locked.add(questionIndex);
        if (_scored.add(questionIndex)) {
          _score++;
        }
        return;
      }
      if (attempts >= kQuizAttempts) {
        _answers[questionIndex] = optionIndex;
        _locked.add(questionIndex);
      }
    });
    if (isCorrect) {
      unawaited(_haptics.success());
    }
    unawaited(
      _audio.speak(isCorrect ? 'Great job!' : 'Not yet, try again.'),
    );
  }

  Future<bool> _persistQuizScore(
    AppController controller,
    ActivityContent activity,
  ) async {
    if (_quizScoreSaved) {
      return true;
    }
    if (_quizSaveInFlight) {
      return false;
    }
    _quizSaveInFlight = true;
    if (mounted) {
      setState(() => _quizError = null);
    }
    final saved = await _trySave(
      () => controller.recordQuizScore(activity.id, _score),
    );
    _quizSaveInFlight = false;
    if (saved) {
      _quizScoreSaved = true;
    }
    if (mounted) {
      setState(() {
        if (!saved) {
          _quizError = kSaveFailureMessage;
        }
      });
    }
    return saved;
  }

  Future<void> _leaveQuiz(
    BuildContext context,
    AppController controller,
    ActivityContent activity,
    List<ActivityStep> steps,
    int index,
  ) async {
    await _settle(() => _persistQuizScore(controller, activity));
    if (!mounted) {
      return;
    }
    _goToStep(steps, index - 1);
  }

  Future<void> _recordPractice(
    AppController controller,
    ActivityContent activity,
    List<ActivityStep> steps,
    int index,
  ) async {
    if (_practiceRecorded || _practiceSaveInFlight) {
      return;
    }
    _practiceSaveInFlight = true;
    setState(() => _practiceError = null);
    final saved = await _trySave(
      () => controller.recordPractice(activity.id),
    );
    _practiceSaveInFlight = false;
    if (!mounted) {
      return;
    }
    if (!saved) {
      setState(() {
        _practiceRecorded = false;
        _practiceError = kSaveFailureMessage;
      });
      return;
    }
    setState(() {
      _practiceRecorded = true;
      _practiceError = null;
    });
    unawaited(_haptics.success());
    _goToStep(steps, index + 1);
  }

  Future<void> _finish() async {
    if (_completionRequested) {
      return;
    }
    _completionRequested = true;
    final controller = AppScope.read(context);
    final activity = _resolveActivity(controller);
    if (activity == null) {
      return;
    }
    try {
      await controller.completeActivity(activity.id);
      if (!mounted) {
        return;
      }
      setState(() {
        _saved = true;
        _saveError = null;
      });
      unawaited(_haptics.success());
      unawaited(_audio.speak('Great job! You finished this activity.'));
    } on Object {
      if (!mounted) {
        return;
      }
      setState(() {
        _saved = false;
        _saveError = kSaveFailureMessage;
        _completionRequested = false;
      });
    }
  }

  void _goToStep(List<ActivityStep> steps, int index) {
    if (index < 0 || index >= steps.length) {
      return;
    }
    setState(() {
      _step = steps[index];
      _stepIndex = index;
      _cardRevealed = false;
      if (steps[index] != ActivityStep.flashcards) {
        _cardIndex = 0;
      }
      if (steps[index] != ActivityStep.quiz) {
        _questionIndex = 0;
      }
    });
  }

  Future<bool> _trySave(Future<void> Function() work) async {
    try {
      await work();
      return true;
    } on AppFailure {
      return false;
    } on Object {
      return false;
    }
  }

  Future<void> _settle(Future<bool> Function() work) async {
    try {
      await work().timeout(kSaveTimeout);
    } on Object {
      return;
    }
  }

  void _goBack(BuildContext context, AppController controller) {
    unawaited(_leave(context, controller, home: false));
  }

  void _goHome(BuildContext context, AppController controller) {
    unawaited(_leave(context, controller, home: true));
  }

  Future<void> _leave(
    BuildContext context,
    AppController controller, {
    required bool home,
  }) async {
    final activity = _resolveActivity(controller);
    if (activity != null) {
      await _settle(() => _persistQuizScore(controller, activity));
    }
    if (!context.mounted) {
      return;
    }
    if (home) {
      final homeCallback = widget.onGoHome;
      if (homeCallback != null) {
        homeCallback();
        return;
      }
      Navigator.of(context).pushNamedAndRemoveUntil(
        RouteNames.home,
        (_) => false,
      );
      return;
    }
    final backCallback = widget.onBack;
    if (backCallback != null) {
      backCallback();
      return;
    }
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
      return;
    }
    final homeCallback = widget.onGoHome;
    if (homeCallback != null) {
      homeCallback();
      return;
    }
    Navigator.of(context).pushNamedAndRemoveUntil(
      RouteNames.home,
      (_) => false,
    );
  }
}

List<ActivityStep> buildSteps(ActivityContent activity) {
  final steps = <ActivityStep>[];
  if (activity.story.trim().isNotEmpty) {
    steps.add(ActivityStep.story);
  }
  if (activity.flashcards.isNotEmpty) {
    steps.add(ActivityStep.flashcards);
  }
  if (activity.questions.isNotEmpty) {
    steps.add(ActivityStep.quiz);
  }
  if (activity.practicePrompt.trim().isNotEmpty ||
      activity.practiceHint.trim().isNotEmpty) {
    steps.add(ActivityStep.practice);
  }
  steps.add(ActivityStep.reward);
  return List<ActivityStep>.unmodifiable(steps);
}

class OptionButton extends StatelessWidget {
  const OptionButton({
    super.key,
    required this.label,
    required this.onTap,
    this.haptics,
  });

  final String label;
  final VoidCallback onTap;
  final HapticsService? haptics;

  @override
  Widget build(BuildContext context) {
    final service = haptics;
    void select() {
      if (service != null) {
        unawaited(service.selection());
      }
      onTap();
    }

    return Semantics(
      button: true,
      label: label,
      onTap: select,
      child: ExcludeSemantics(
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: kPrimaryActionHeight),
          child: FilledButton(
            onPressed: select,
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ),
      ),
    );
  }
}

class _QuizFeedback extends StatelessWidget {
  const _QuizFeedback({
    required this.correct,
    required this.retry,
    required this.hint,
    required this.answer,
  });

  final bool correct;
  final bool retry;
  final String hint;
  final String answer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (correct) {
      return TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0.6, end: 1),
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutBack,
        builder: (context, value, child) =>
            Transform.scale(scale: value, child: child),
        child: _FeedbackPanel(
          icon: Icons.star_rounded,
          title: 'Great job!',
          message: 'You found the right answer.',
          color: AppColors.success,
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w900,
            color: AppColors.success,
          ),
        ),
      );
    }
    return _FeedbackPanel(
      icon: retry ? Icons.eco_outlined : Icons.lightbulb_outline,
      title: retry ? 'Not yet, try again' : 'The answer is $answer',
      message: hint,
      color: AppColors.warning,
      style: theme.textTheme.headlineSmall?.copyWith(
        fontWeight: FontWeight.w800,
        color: AppColors.warning,
      ),
    );
  }
}

class _FeedbackPanel extends StatelessWidget {
  const _FeedbackPanel({
    required this.icon,
    required this.title,
    required this.message,
    required this.color,
    required this.style,
  });

  final IconData icon;
  final String title;
  final String message;
  final Color color;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: '$title $message',
      child: ExcludeSemantics(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: <Widget>[
                Icon(icon, size: 64, color: color),
                const SizedBox(height: 8),
                Text(title, textAlign: TextAlign.center, style: style),
                const SizedBox(height: 6),
                Text(message, textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SaveRetryNotice extends StatelessWidget {
  const _SaveRetryNotice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Semantics(
        liveRegion: true,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFFFE0DC),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.error),
          ),
          child: Row(
            children: <Widget>[
              const Icon(
                Icons.save_outlined,
                color: AppColors.error,
                size: 26,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.error,
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RewardBadge extends StatelessWidget {
  const _RewardBadge();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0.5, end: 1),
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutBack,
        builder: (context, value, child) =>
            Transform.scale(scale: value, child: child),
        child: Semantics(
          label: 'Reward star',
          child: const ExcludeSemantics(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text('⭐', style: TextStyle(fontSize: 96)),
            ),
          ),
        ),
      ),
    );
  }
}

class DrawingPad extends StatefulWidget {
  const DrawingPad({super.key});

  @override
  State<DrawingPad> createState() => _DrawingPadState();
}

class _DrawingPadState extends State<DrawingPad> {
  static const double _minimumPadHeight = 200;

  final List<List<Offset>> _strokes = <List<Offset>>[];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        LayoutBuilder(
          builder: (context, constraints) {
            final height =
                math.max(_minimumPadHeight, constraints.maxWidth * 0.6);
            return Semantics(
              container: true,
              label: 'Drawing area',
              hint: 'Draw with a finger or a pointer',
              child: Container(
                height: height,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFD7E0DE)),
                ),
                clipBehavior: Clip.antiAlias,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onPanStart: (details) => setState(
                    () => _strokes.add(<Offset>[details.localPosition]),
                  ),
                  onPanUpdate: (details) => setState(() {
                    if (_strokes.isNotEmpty) {
                      _strokes.last.add(details.localPosition);
                    }
                  }),
                  child: CustomPaint(
                    painter: _StrokePainter(_strokes),
                    size: Size.infinite,
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 10),
        Semantics(
          button: true,
          label: 'Clear drawing',
          hint: 'Erase everything you drew',
          onTap: () => setState(_strokes.clear),
          child: ExcludeSemantics(
            child: OutlinedButton(
              onPressed: () => setState(_strokes.clear),
              child: const Text('Clear drawing'),
            ),
          ),
        ),
      ],
    );
  }
}

class _StrokePainter extends CustomPainter {
  const _StrokePainter(this.strokes);

  final List<List<Offset>> strokes;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Paint()
      ..color = AppColors.ink
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    for (final stroke in strokes) {
      if (stroke.isEmpty) {
        continue;
      }
      if (stroke.length == 1) {
        canvas.drawCircle(stroke.first, 3, Paint()..color = AppColors.ink);
        continue;
      }
      final traced = Path()..moveTo(stroke.first.dx, stroke.first.dy);
      for (final point in stroke.skip(1)) {
        traced.lineTo(point.dx, point.dy);
      }
      canvas.drawPath(traced, path);
    }
  }

  @override
  bool shouldRepaint(_StrokePainter oldDelegate) => true;
}
