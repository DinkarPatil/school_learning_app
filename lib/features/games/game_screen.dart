import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:school_learning_app/app/app_controller.dart';
import 'package:school_learning_app/app/app_scope.dart';
import 'package:school_learning_app/app/route_names.dart';
import 'package:school_learning_app/app/theme.dart';
import 'package:school_learning_app/core/haptics/haptics_service.dart';
import 'package:school_learning_app/core/speech/speech_service.dart';
import 'package:school_learning_app/data/content/content_models.dart';
import 'package:school_learning_app/features/learning/learning_shell.dart';
import 'package:school_learning_app/features/learning/lesson_audio.dart';

const int kGameRounds = 5;
const String kMissingGameTitle = 'Let us choose something else';
const String kGameSaveFailureMessage =
    'We could not save that yet. Please try again.';
const String kGameSavedMessage = 'Saved. You finished this game.';
const String kGameWrongAnswerMessage = 'Not this one. Try again.';
const Duration kGameSaveTimeout = Duration(seconds: 4);

bool isGameActivity(ActivityContent? activity) {
  if (activity == null) {
    return false;
  }
  switch (activity.activityType) {
    case ActivityType.letter:
    case ActivityType.number:
    case ActivityType.word:
    case ActivityType.game:
      return true;
    case ActivityType.story:
      return false;
  }
}

class GameScreen extends StatefulWidget {
  const GameScreen({
    super.key,
    this.activityId,
    this.onGoHome,
    this.onBack,
  });

  final String? activityId;
  final VoidCallback? onGoHome;
  final VoidCallback? onBack;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late final AppController _controller;
  late final HapticsService _haptics;
  late final LessonAudioController _audio;
  final Random _random = Random();

  int? _selectedCard;
  int _round = 1;
  int _score = 0;
  int? _wrongOption;
  String _target = '';
  List<String> _options = <String>[];
  bool _finished = false;
  bool _roundCelebrating = false;
  bool _scoreSaved = false;
  bool _scoreSaveInFlight = false;
  bool _completionRequested = false;
  bool _completed = false;
  bool _disposing = false;
  String? _saveError;
  String? _gameActivityId;

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
    final activity = _resolveActivity(controller);
    if (activity == null || activity.activityType != ActivityType.game) {
      return;
    }
    final letters = activity.flashcards.map(parseLetter).toList();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _startRound(activity, letters);
    });
  }

  @override
  void dispose() {
    _disposing = true;
    unawaited(_audio.stop());
    unawaited(_persistGameScore());
    _audio.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final activity = _resolveActivity(controller);
    if (activity == null) {
      return LearningScaffold(
        title: 'Play and learn',
        onGoHome: () => _goHome(context, controller),
        onBack: () => _goBack(context, controller),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const Expanded(
              child: LearningMessage(
                icon: Icons.explore_outlined,
                title: kMissingGameTitle,
                body: 'This game is not here right now.',
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
    if (activity.activityType == ActivityType.game) {
      return _roundGame(context, controller, activity);
    }
    switch (activity.activityType) {
      case ActivityType.letter:
        return _letterBook(context, controller, activity);
      case ActivityType.number:
        return _numberBook(context, controller, activity);
      case ActivityType.word:
        return _wordBook(context, controller, activity);
      case ActivityType.story:
      case ActivityType.game:
        return _letterBook(context, controller, activity);
    }
  }

  ActivityContent? _resolveActivity(AppController controller) {
    final id = widget.activityId ?? controller.activeActivityId;
    if (id == null || id.trim().isEmpty) {
      return null;
    }
    final activity = controller.activityById(id);
    if (activity != null && activity.activityType == ActivityType.game) {
      _gameActivityId = activity.id;
    }
    return activity;
  }

  Widget _letterBook(
    BuildContext context,
    AppController controller,
    ActivityContent activity,
  ) {
    final letters = activity.flashcards.map(parseLetter).toList();
    final selected = _selectedCard;
    if (selected != null && selected < letters.length) {
      return _letterDetail(context, controller, activity, letters[selected]);
    }
    return _book(
      context,
      controller,
      activity,
      heading: 'Tap a letter to hear it.',
      itemCount: letters.length,
      itemBuilder: (context, index) {
        final letter = letters[index];
        return _LetterCard(
          key: Key('letter-card-${letter.capital}'),
          letter: letter,
          onTap: () => _selectCard(index),
        );
      },
    );
  }

  Widget _letterDetail(
    BuildContext context,
    AppController controller,
    ActivityContent activity,
    GameLetter letter,
  ) {
    final text = '${letter.capital}. ${letter.capital} for ${letter.word}.';
    return _detail(
      context,
      controller,
      activity,
      icon: letter.emoji,
      headline: letter.capital,
      caption: '${letter.capital} ${letter.small}',
      body: <String>[letter.word, ...letter.translations],
      audioAsset: '',
      speechText: text,
      backLabel: 'Back to letters',
      onBack: () => setState(() => _selectedCard = null),
    );
  }

  Widget _numberBook(
    BuildContext context,
    AppController controller,
    ActivityContent activity,
  ) {
    final numbers = activity.flashcards.map(parseNumber).toList();
    final selected = _selectedCard;
    if (selected != null && selected < numbers.length) {
      final number = numbers[selected];
      return _detail(
        context,
        controller,
        activity,
        icon: '\u2B50',
        headline: number.digits,
        caption: number.word,
        body: <String>[...number.translations],
        stars: number.value,
        audioAsset: '',
        speechText: _countText(number),
        backLabel: 'Back to numbers',
        onBack: () => setState(() => _selectedCard = null),
        extraActions: <Widget>[
          FilledButton.icon(
            onPressed: () => unawaited(_audio.speak(_countText(number))),
            icon: const Icon(Icons.volume_up_rounded, size: 26),
            label: const Text('Count'),
          ),
        ],
      );
    }
    return _book(
      context,
      controller,
      activity,
      heading: 'Tap a number to count.',
      itemCount: numbers.length,
      minItemWidth: 120,
      itemBuilder: (context, index) {
        final number = numbers[index];
        return _NumberCard(
          key: Key('number-card-${number.value}'),
          number: number,
          onTap: () => _selectCard(index),
        );
      },
    );
  }

  Widget _wordBook(
    BuildContext context,
    AppController controller,
    ActivityContent activity,
  ) {
    final words = activity.flashcards.map(parseWord).toList();
    final selected = _selectedCard;
    if (selected != null && selected < words.length) {
      return _wordDetail(context, controller, activity, words[selected]);
    }
    return _book(
      context,
      controller,
      activity,
      heading: 'Tap a word to hear it.',
      itemCount: words.length,
      itemBuilder: (context, index) {
        final word = words[index];
        return _WordCard(
          key: Key('word-card-${word.word}'),
          word: word,
          onTap: () => _selectCard(index),
        );
      },
    );
  }

  Widget _wordDetail(
    BuildContext context,
    AppController controller,
    ActivityContent activity,
    GameWord word,
  ) {
    final text = '${word.letters.join(' ')}. ${word.word}!';
    return _detail(
      context,
      controller,
      activity,
      icon: word.emoji,
      headline: word.word,
      caption: null,
      body: <String>[...word.translations],
      audioAsset: '',
      speechText: text,
      backLabel: 'Back to words',
      onBack: () => setState(() => _selectedCard = null),
      extraBody: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: <Widget>[
          for (final letter in word.letters)
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 64, minHeight: 64),
              child: Container(
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    letter,
                    style: const TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.w900,
                      color: AppColors.ink,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _selectCard(int index) {
    unawaited(_haptics.selection());
    setState(() => _selectedCard = index);
  }

  Widget _book(
    BuildContext context,
    AppController controller,
    ActivityContent activity, {
    required String heading,
    required int itemCount,
    required Widget Function(BuildContext context, int index) itemBuilder,
    double minItemWidth = 140,
  }) {
    final text = controller.textFor(activity);
    return LearningScaffold(
      title: text.title,
      onGoHome: () => _goHome(context, controller),
      onBack: () => _goBack(context, controller),
      body: LearningStepBody(
        key: ValueKey('book-${activity.id}'),
        actions: <Widget>[
          FilledButton(
            onPressed: _completed ? null : () => _finishBook(activity),
            child: Text(_completed ? 'Finished' : 'Finish'),
          ),
          OutlinedButton(
            onPressed: () => _goHome(context, controller),
            child: const Text('Go home'),
          ),
        ],
        children: <Widget>[
          _GameBanner(text: text.story),
          const SizedBox(height: 12),
          Text(
            heading,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          if (_completed) ...<Widget>[
            const SizedBox(height: 12),
            Semantics(
              key: const Key('game-saved-confirmation'),
              liveRegion: true,
              child: Text(
                kGameSavedMessage,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.success,
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          ResponsiveTileGrid(
            minItemWidth: minItemWidth,
            spacing: 12,
            maxColumns: 4,
            itemCount: itemCount,
            itemBuilder: itemBuilder,
          ),
        ],
      ),
    );
  }

  Widget _detail(
    BuildContext context,
    AppController controller,
    ActivityContent activity, {
    required String icon,
    required String headline,
    required String? caption,
    required List<String> body,
    required String audioAsset,
    required String speechText,
    required String backLabel,
    required VoidCallback onBack,
    int? stars,
    List<Widget> extraActions = const <Widget>[],
    Widget? extraBody,
  }) {
    return LearningScaffold(
      title: controller.textFor(activity).title,
      onGoHome: () => _goHome(context, controller),
      onBack: () => _goBack(context, controller),
      body: LearningStepBody(
        key: ValueKey('detail-$headline-$backLabel'),
        actions: <Widget>[
          OutlinedButton.icon(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_rounded, size: 24),
            label: Text(backLabel),
          ),
          ...extraActions,
          OutlinedButton(
            onPressed: () => _goHome(context, controller),
            child: const Text('Go home'),
          ),
        ],
        children: <Widget>[
          Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                icon,
                style: const TextStyle(fontSize: 64),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                headline,
                style: const TextStyle(
                  fontSize: 84,
                  fontWeight: FontWeight.w900,
                  color: AppColors.ink,
                ),
              ),
            ),
          ),
          if (caption != null) ...<Widget>[
            const SizedBox(height: 6),
            Text(
              caption,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ],
          for (final line in body) ...<Widget>[
            const SizedBox(height: 6),
            Text(
              line,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ],
          if (stars != null && stars > 0) ...<Widget>[
            const SizedBox(height: 12),
            Center(
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                alignment: WrapAlignment.center,
                children: <Widget>[
                  for (var index = 0; index < stars; index++)
                    const Text('\u2B50', style: TextStyle(fontSize: 28)),
                ],
              ),
            ),
          ],
          if (extraBody != null) ...<Widget>[
            const SizedBox(height: 12),
            extraBody,
          ],
          const SizedBox(height: 16),
          LessonAudioBar(
            controller: _audio,
            audioAsset: audioAsset,
            speechText: speechText,
            language: SpeechService.mapLanguage(
              controller.textFor(activity).language,
            ),
          ),
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
      ),
    );
  }

  Widget _roundGame(
    BuildContext context,
    AppController controller,
    ActivityContent activity,
  ) {
    final letters = activity.flashcards.map(parseLetter).toList();
    final text = controller.textFor(activity);
    if (_finished) {
      return _reward(context, controller, activity, text);
    }
    if (_options.length < 2 || _target.isEmpty) {
      return LearningScaffold(
        title: text.title,
        onGoHome: () => _goHome(context, controller),
        onBack: () => _goBack(context, controller),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const Expanded(
              child: LearningMessage(
                icon: Icons.explore_outlined,
                title: 'This game needs a few more cards',
                body: 'Go home and choose another game.',
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
    final isMatchCase = _matchesSmallLetters(letters);
    return LearningScaffold(
      title: text.title,
      onGoHome: () => _goHome(context, controller),
      onBack: () => _goBack(context, controller),
      body: LearningStepBody(
        key: const ValueKey('round-game'),
        actions: <Widget>[
          if (_roundCelebrating)
            FilledButton(
              onPressed: () => _nextRound(controller, activity, letters),
              child: Text(
                _round >= kGameRounds ? 'See my star' : 'Next round',
              ),
            ),
          OutlinedButton(
            onPressed: () => _goHome(context, controller),
            child: const Text('Go home'),
          ),
        ],
        children: <Widget>[
          _GameBanner(text: text.story),
          const SizedBox(height: 12),
          Semantics(
            container: true,
            label: 'Round $_round of $kGameRounds. Score $_score.',
            child: ExcludeSemantics(
              child: Column(
                children: <Widget>[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      for (var index = 1; index <= kGameRounds; index++)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Icon(
                            index < _round
                                ? Icons.star_rounded
                                : Icons.star_border_rounded,
                            color: index < _round
                                ? AppColors.warning
                                : AppColors.ink,
                            size: 26,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      'Round $_round of $kGameRounds',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(26),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      isMatchCase ? 'Match me!' : 'Find this letter',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _target,
                      key: const Key('game-target'),
                      style: const TextStyle(
                        fontSize: 64,
                        fontWeight: FontWeight.w900,
                        color: AppColors.ink,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (_roundCelebrating)
            const _GameBanner(
              text: 'Great job!',
              color: AppColors.success,
              icon: Icons.star_rounded,
            )
          else if (_wrongOption != null)
            const _GameBanner(
              text: 'Try again, little star',
              color: AppColors.warning,
              icon: Icons.eco_outlined,
            ),
          if (_roundCelebrating || _wrongOption != null)
            const SizedBox(height: 12),
          ResponsiveTileGrid(
            minItemWidth: 110,
            spacing: 12,
            maxColumns: 3,
            itemCount: _options.length,
            itemBuilder: (context, index) => _OptionCard(
              key: Key('game-option-${_options[index]}'),
              label: _options[index],
              wrong: _wrongOption == index,
              enabled: !_roundCelebrating,
              onTap: () => _answer(activity, letters, index),
            ),
          ),
        ],
      ),
    );
  }

  Widget _reward(
    BuildContext context,
    AppController controller,
    ActivityContent activity,
    ActivityText text,
  ) {
    return LearningScaffold(
      title: text.title,
      onGoHome: () => _goHome(context, controller),
      onBack: () => _goBack(context, controller),
      body: LearningStepBody(
        key: const ValueKey('round-reward'),
        actions: <Widget>[
          FilledButton(
            onPressed:
                _completionRequested ? null : () => _finishRoundGame(activity),
            child: const Text('Go home'),
          ),
          OutlinedButton(
            onPressed: () => _restart(controller, activity),
            child: const Text('Play again'),
          ),
        ],
        children: <Widget>[
          LearningMessage(
            icon: Icons.emoji_events_rounded,
            title: 'You are a star!',
            body: _saveError == null
                ? 'You got $_score out of $kGameRounds.'
                : 'You got $_score out of $kGameRounds. $_saveError',
          ),
        ],
      ),
    );
  }

  void _answer(
    ActivityContent activity,
    List<GameLetter> letters,
    int index,
  ) {
    if (_roundCelebrating) {
      return;
    }
    final chosen = _options[index];
    if (chosen.toLowerCase() == _target.toLowerCase()) {
      setState(() {
        _score++;
        _roundCelebrating = true;
        _wrongOption = null;
      });
      unawaited(_haptics.success());
      unawaited(_audio.speak('Great job!'));
      return;
    }
    setState(() {
      _wrongOption = index;
      _roundCelebrating = false;
    });
    unawaited(_haptics.selection());
    unawaited(_audio.speak('Try again, little star'));
  }

  Future<void> _nextRound(
    AppController controller,
    ActivityContent activity,
    List<GameLetter> letters,
  ) async {
    if (_round >= kGameRounds) {
      await _settle(
        () => _persistGameScore(),
        onTimeout: _reportSaveTimeout,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _finished = true;
        _roundCelebrating = false;
      });
      unawaited(_audio.speak('You did it! You are a star!'));
      return;
    }
    _startRound(activity, letters, nextRound: true);
  }

  Future<bool> _persistGameScore([AppController? controller]) async {
    if (_scoreSaved || _scoreSaveInFlight) {
      return _scoreSaved;
    }
    final activityId = _gameActivityId;
    if (activityId == null || activityId.isEmpty) {
      return false;
    }
    final target = controller ?? _controller;
    _scoreSaveInFlight = true;
    final saved = await _guard(
      () => target.recordQuizScore(activityId, _score),
    );
    _scoreSaveInFlight = false;
    if (saved && _canUpdate) {
      setState(() => _saveError = null);
    } else if (!saved && _canUpdate) {
      setState(() => _saveError = kGameSaveFailureMessage);
    }
    if (saved) {
      _scoreSaved = true;
    }
    return saved;
  }

  bool get _canUpdate => mounted && !_disposing;

  void _startRound(
    ActivityContent activity,
    List<GameLetter> letters, {
    bool nextRound = false,
  }) {
    if (letters.length < 3) {
      return;
    }
    final isMatchCase = _matchesSmallLetters(letters);
    final pool = <GameLetter>[...letters]..shuffle(_random);
    final target = pool.first;
    final others = pool.skip(1).take(2).toList();
    final options = <String>[
      if (isMatchCase) target.small else target.capital,
      for (final other in others) isMatchCase ? other.small : other.capital,
    ]..shuffle(_random);
    setState(() {
      _target = target.capital;
      _options = options;
      _wrongOption = null;
      _roundCelebrating = false;
      if (nextRound) {
        _round++;
      }
    });
    unawaited(
      _audio.speak(
        isMatchCase
            ? 'Find the little ${target.capital}.'
            : 'Find the letter ${target.capital}.',
      ),
    );
  }

  void _restart(AppController controller, ActivityContent activity) {
    final letters = activity.flashcards.map(parseLetter).toList();
    unawaited(_haptics.selection());
    setState(() {
      _round = 1;
      _score = 0;
      _finished = false;
      _roundCelebrating = false;
      _wrongOption = null;
      _scoreSaved = false;
      _saveError = null;
    });
    _startRound(activity, letters);
  }

  Future<void> _finishRoundGame(ActivityContent activity) async {
    final controller = AppScope.read(context);
    final messenger = ScaffoldMessenger.of(context);
    if (_completionRequested) {
      _goHome(context, controller);
      return;
    }
    _completionRequested = true;
    try {
      await controller.completeActivity(activity.id);
    } on Object {
      if (!mounted) {
        return;
      }
      setState(() {
        _saveError = kGameSaveFailureMessage;
        _completionRequested = false;
      });
      return;
    }
    if (!mounted) {
      return;
    }
    setState(() => _saveError = null);
    unawaited(_haptics.success());
    unawaited(_audio.speak(kGameSavedMessage));
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(const SnackBar(content: Text(kGameSavedMessage)));
    _goHome(context, controller);
  }

  Future<void> _finishBook(ActivityContent activity) async {
    final controller = AppScope.read(context);
    final messenger = ScaffoldMessenger.of(context);
    if (_completionRequested) {
      return;
    }
    _completionRequested = true;
    try {
      await controller.completeActivity(activity.id);
    } on Object {
      if (!mounted) {
        return;
      }
      setState(() {
        _saveError = kGameSaveFailureMessage;
        _completionRequested = false;
      });
      messenger.showSnackBar(
        const SnackBar(content: Text(kGameSaveFailureMessage)),
      );
      return;
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _saveError = null;
      _completed = true;
    });
    unawaited(_haptics.success());
    unawaited(_audio.speak(kGameSavedMessage));
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(const SnackBar(content: Text(kGameSavedMessage)));
  }

  Future<bool> _guard(Future<void> Function() work) async {
    try {
      await work();
      return true;
    } on Object {
      return false;
    }
  }

  Future<void> _settle(
    Future<bool> Function() work, {
    VoidCallback? onTimeout,
  }) async {
    try {
      await work().timeout(kGameSaveTimeout);
    } on TimeoutException {
      onTimeout?.call();
    } on Object {
      return;
    }
  }

  void _reportSaveTimeout() {
    if (_canUpdate) {
      setState(() => _saveError = kSaveTimeoutMessage);
    }
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      const SnackBar(content: Text(kSaveTimeoutMessage)),
    );
  }

  void _goBack(BuildContext context, AppController controller) {
    if (_selectedCard != null || _finished) {
      setState(() {
        _selectedCard = null;
        _finished = false;
      });
      return;
    }
    unawaited(_leave(context, controller, home: false));
  }

  void _goHome(BuildContext context, [AppController? controller]) {
    unawaited(_leave(context, controller ?? _controller, home: true));
  }

  Future<void> _leave(
    BuildContext context,
    AppController controller, {
    required bool home,
  }) async {
    await _settle(
      () => _persistGameScore(controller),
      onTimeout: _reportSaveTimeout,
    );
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
    _goHome(context, controller);
  }
}

class GameLetter {
  const GameLetter({
    required this.capital,
    required this.small,
    required this.word,
    required this.emoji,
    required this.translations,
    this.smallFromBack = false,
  });

  final String capital;
  final String small;
  final String word;
  final String emoji;
  final List<String> translations;
  final bool smallFromBack;
}

class GameNumber {
  const GameNumber({
    required this.value,
    required this.digits,
    required this.word,
    required this.translations,
  });

  final int value;
  final String digits;
  final String word;
  final List<String> translations;
}

class GameWord {
  const GameWord({
    required this.word,
    required this.emoji,
    required this.translations,
  });

  final String word;
  final String emoji;
  final List<String> translations;

  List<String> get letters => word.split('');
}

bool _matchesSmallLetters(List<GameLetter> letters) {
  if (letters.isEmpty) {
    return false;
  }
  return letters.every((letter) => letter.smallFromBack);
}

final RegExp _tokenPattern = RegExp(r'\s+');

GameLetter parseLetter(FlashcardContent card) {
  final frontParts = _tokens(card.front);
  final details = _details(card.back);
  String? capital;
  String? small;
  for (final token in frontParts) {
    if (!_isBareLetter(token)) {
      continue;
    }
    if (_isUpperCaseLetter(token)) {
      capital ??= token;
    } else {
      small ??= token;
    }
  }
  String? backSmall;
  final labelled = <String>[];
  for (final detail in details) {
    if (_isBareLetter(detail)) {
      backSmall ??= detail;
      continue;
    }
    labelled.add(detail);
  }
  final capitalLetter = capital ??
      backSmall?.toUpperCase() ??
      (frontParts.isEmpty ? '' : frontParts.first.toUpperCase());
  final smallLetter = small ?? backSmall ?? capitalLetter.toLowerCase();
  final label = labelled.isEmpty ? '' : labelled.first;
  return GameLetter(
    capital: capitalLetter,
    small: smallLetter,
    word: _withoutEmoji(label),
    emoji: _emoji(label),
    translations: labelled.skip(label.isEmpty ? 0 : 1).toList(),
    smallFromBack: small == null && backSmall != null,
  );
}

GameNumber parseNumber(FlashcardContent card) {
  final digits = card.front.trim();
  final details = _details(card.back);
  return GameNumber(
    value: int.tryParse(digits) ?? 0,
    digits: digits,
    word: details.isEmpty ? digits : details.first,
    translations: details.skip(details.isEmpty ? 0 : 1).toList(),
  );
}

GameWord parseWord(FlashcardContent card) {
  final word = card.front.trim();
  final details = _details(card.back)
      .where(
        (detail) => detail.toUpperCase() != word.toUpperCase(),
      )
      .toList();
  return GameWord(
    word: word,
    emoji: _emoji(details.isEmpty ? '' : details.first),
    translations: details.skip(details.isEmpty ? 0 : 1).toList(),
  );
}

String _countText(GameNumber number) => '${number.word}. Count with me.';

List<String> _tokens(String value) => value
    .trim()
    .split(_tokenPattern)
    .where((token) => token.isNotEmpty)
    .toList();

List<String> _details(String value) => value
    .split('|')
    .map((part) => part.trim())
    .where((part) => part.isNotEmpty)
    .toList();

bool _isBareLetter(String value) =>
    value.length == 1 && RegExp(r'^[A-Za-z]$').hasMatch(value);

bool _isUpperCaseLetter(String value) =>
    value.toUpperCase() == value && value.toLowerCase() != value;

String _emoji(String value) {
  final buffer = StringBuffer();
  for (final rune in value.runes) {
    if (_isEmojiRune(rune)) {
      buffer.writeCharCode(rune);
    }
  }
  return buffer.toString();
}

String _withoutEmoji(String value) => value
    .split(' ')
    .where((part) => part.isNotEmpty && !_isEmojiRun(part))
    .join(' ');

bool _isEmojiRun(String value) =>
    value.runes.isNotEmpty && value.runes.every(_isEmojiRune);

bool _isEmojiRune(int rune) =>
    rune >= 0x1F000 ||
    (rune >= 0x2600 && rune <= 0x27BF) ||
    rune == 0x2B50 ||
    rune == 0xFE0F;

class _GameBanner extends StatelessWidget {
  const _GameBanner({
    required this.text,
    this.color = AppColors.primary,
    this.icon = Icons.auto_stories_outlined,
  });

  final String text;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 24, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LetterCard extends StatelessWidget {
  const _LetterCard({
    super.key,
    required this.letter,
    required this.onTap,
  });

  final GameLetter letter;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = '${letter.capital} ${letter.small}';
    return Semantics(
      button: true,
      label: '$label. ${letter.word}',
      onTap: onTap,
      child: ExcludeSemantics(
        child: Card(
          color: const Color(0xFFFFE7C2),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 96),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        letter.capital,
                        style: const TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.w900,
                          color: AppColors.ink,
                        ),
                      ),
                    ),
                    if (letter.emoji.isNotEmpty)
                      Text(letter.emoji, style: const TextStyle(fontSize: 24)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NumberCard extends StatelessWidget {
  const _NumberCard({
    super.key,
    required this.number,
    required this.onTap,
  });

  final GameNumber number;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '${number.digits}. ${number.word}',
      onTap: onTap,
      child: ExcludeSemantics(
        child: Card(
          color: const Color(0xFFFFF6C3),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 96),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        number.digits,
                        style: const TextStyle(
                          fontSize: 44,
                          fontWeight: FontWeight.w900,
                          color: AppColors.ink,
                        ),
                      ),
                    ),
                    const Text('\u2B50', style: TextStyle(fontSize: 20)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WordCard extends StatelessWidget {
  const _WordCard({
    super.key,
    required this.word,
    required this.onTap,
  });

  final GameWord word;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Word ${word.word}',
      onTap: onTap,
      child: ExcludeSemantics(
        child: Card(
          color: const Color(0xFFFFD7E8),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 96),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    if (word.emoji.isNotEmpty)
                      Text(word.emoji, style: const TextStyle(fontSize: 36)),
                    const SizedBox(height: 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        word.word,
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 3,
                          color: AppColors.ink,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OptionCard extends StatelessWidget {
  const _OptionCard({
    super.key,
    required this.label,
    required this.wrong,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final bool wrong;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: enabled,
      label:
          wrong ? 'Letter $label. $kGameWrongAnswerMessage' : 'Letter $label',
      value: wrong ? kGameWrongAnswerMessage : null,
      onTap: enabled ? onTap : null,
      child: ExcludeSemantics(
        child: Stack(
          children: <Widget>[
            SizedBox(
              width: double.infinity,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                constraints: const BoxConstraints(minHeight: 96),
                decoration: BoxDecoration(
                  color: wrong ? AppColors.error : AppColors.primary,
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(28),
                    onTap: enabled ? onTap : null,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 16,
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          label,
                          style: const TextStyle(
                            fontSize: 44,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (wrong)
              const Positioned(
                top: 4,
                right: 4,
                child: _WrongAnswerBadge(),
              ),
          ],
        ),
      ),
    );
  }
}

class _WrongAnswerBadge extends StatelessWidget {
  const _WrongAnswerBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
      child: const Icon(
        Icons.close_rounded,
        size: 30,
        color: AppColors.error,
      ),
    );
  }
}
