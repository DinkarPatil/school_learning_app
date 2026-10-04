import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'dart:ui' show Tristate;
import 'package:flutter_test/flutter_test.dart';
import 'package:school_learning_app/app/app.dart';
import 'package:school_learning_app/app/app_scope.dart';
import 'package:school_learning_app/core/audio/audio_service.dart';
import 'package:school_learning_app/core/haptics/haptics_service.dart';
import 'package:school_learning_app/core/speech/speech_service.dart';
import 'package:school_learning_app/data/content/content_models.dart';
import 'package:school_learning_app/data/content/content_repository.dart';
import 'package:school_learning_app/data/progress/progress_store.dart';
import 'package:school_learning_app/features/games/game_screen.dart';
import 'package:school_learning_app/features/learning/activity_screen.dart';
import 'package:school_learning_app/features/learning/learning_shell.dart';
import 'package:school_learning_app/features/learning/subject_screen.dart';

import '../support/activity_catalog.dart';
import '../support/fakes.dart';

const String _storyActivityId = 'class-1-subject-english-activity-story';
const String _findLetterActivityId =
    'class-0-subject-little-activity-find-letter';
const String _apple = 'Apple \u{1F34E}';
const String _appleHindi = '\u0938\u0947\u092C';
const String _appleMarathi = '\u0938\u092B\u0930\u091A\u0902\u0926';

void main() {
  group('subject selection', () {
    testWidgets('every class is reachable without an age gate', (tester) async {
      final dependencies = _testDependencies();
      await _pumpApp(tester, dependencies);

      await _tapText(tester, 'Choose a subject');
      await tester.pumpAndSettle();

      for (var level = 1; level <= 5; level++) {
        expect(find.text('Class $level'), findsOneWidget);
      }
      expect(find.text('class-0'), findsNothing);
      expect(find.text('Choose a class'), findsOneWidget);
      expect(find.text('Little Stars'), findsNothing);
      expect(find.textContaining('age'), findsNothing);
    });

    testWidgets('the class filter narrows the activity list', (tester) async {
      final dependencies = _testDependencies();
      await _pumpApp(tester, dependencies);

      await _tapText(tester, 'Choose a subject');
      await tester.pumpAndSettle();
      await _tapText(tester, 'English');
      await tester.pumpAndSettle();

      expect(find.text('Class 1 Story'), findsOneWidget);
      expect(find.text('Class 1 Poem'), findsOneWidget);
      expect(find.text('Class 2 Story'), findsNothing);

      await _tapText(tester, 'Class 2');
      await tester.pumpAndSettle();

      expect(find.text('Class 1 Story'), findsNothing);
      expect(find.text('Class 2 Story'), findsOneWidget);
    });

    testWidgets('an empty class stays reachable and recoverable',
        (tester) async {
      final dependencies = _testDependencies();
      await _pumpApp(tester, dependencies);

      await _tapText(tester, 'Choose a subject');
      await tester.pumpAndSettle();
      await _tapText(tester, 'Class 3');
      await tester.pumpAndSettle();
      await _tapText(tester, 'English');
      await tester.pumpAndSettle();
      await _tapText(tester, 'Class 3 Story');
      await tester.pumpAndSettle();

      expect(find.text('Class 3 reads and explores together.'), findsOneWidget);
      expect(find.text('Home'), findsOneWidget);
    });

    testWidgets('play and learn reuses migrated game content only',
        (tester) async {
      final dependencies = _testDependencies();
      await _pumpApp(tester, dependencies);

      await _tapText(tester, 'Play and learn');
      await tester.pumpAndSettle();

      expect(find.text('Big ABC'), findsOneWidget);
      expect(find.text('Small abc'), findsOneWidget);
      expect(find.text('Numbers 1 to 10'), findsOneWidget);
      expect(find.text('First Words'), findsOneWidget);
      expect(find.text('Find the Letter'), findsOneWidget);
      expect(find.text('Match Letters'), findsOneWidget);
      expect(find.textContaining('age'), findsNothing);
      expect(find.text('Choose a class'), findsNothing);
    });
  });

  group('activity flow', () {
    testWidgets('unknown activity shows a recoverable message', (tester) async {
      final dependencies = _testDependencies();
      await _pumpApp(tester, dependencies);

      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      unawaited(
        navigator.pushNamed(RouteNames.activity, arguments: 'missing'),
      );
      await tester.pumpAndSettle();

      expect(find.text('Let us choose something else'), findsOneWidget);
      expect(find.text('Go home'), findsOneWidget);

      await _tapText(tester, 'Go home');
      await tester.pumpAndSettle();

      expect(find.text('Continue learning'), findsOneWidget);
    });

    testWidgets('the story step listens and advances one step at a time',
        (tester) async {
      final dependencies = _testDependencies();
      await _pumpApp(tester, dependencies);
      await _openStoryActivity(tester);

      expect(find.text('Class 1 reads and explores together.'), findsOneWidget);
      expect(find.text('Listen'), findsOneWidget);
      expect(find.text('Stop audio'), findsOneWidget);
      expect(find.text('Card 1 of 2'), findsNothing);

      await _tapText(tester, 'Next step');
      await tester.pumpAndSettle();

      expect(find.text('Card 1 of 2'), findsOneWidget);
      expect(find.text('Read'), findsOneWidget);
      expect(find.text('Look at words'), findsNothing);

      await _tapText(tester, 'Show the answer');
      await tester.pumpAndSettle();

      expect(find.text('Look at words'), findsOneWidget);
    });

    testWidgets('every activity step keeps a visible home action',
        (tester) async {
      final dependencies = _testDependencies();
      await _pumpApp(tester, dependencies);
      await _openStoryActivity(tester);

      expect(find.widgetWithText(TextButton, 'Home'), findsOneWidget);
      expect(find.byTooltip('Back'), findsOneWidget);

      await _advanceToQuiz(tester);

      expect(find.widgetWithText(TextButton, 'Home'), findsOneWidget);
      expect(find.byTooltip('Back'), findsOneWidget);

      await _advanceToPractice(tester);

      expect(find.widgetWithText(TextButton, 'Home'), findsOneWidget);
      expect(find.byTooltip('Back'), findsOneWidget);

      await _tapText(tester, 'I finished practicing');
      await tester.pumpAndSettle();

      expect(find.widgetWithText(TextButton, 'Home'), findsOneWidget);
      expect(find.byTooltip('Back'), findsOneWidget);
    });

    testWidgets('lesson audio falls back to speech when the asset fails',
        (tester) async {
      final speech = RecordingSpeechEngine();
      final dependencies = _testDependencies(
        audioFactory: TestFailingAudioPlayerFactory(),
        speechEngine: speech,
      );
      await _pumpApp(tester, dependencies);
      await _openStoryActivity(tester);

      await _runAudio(tester, 'Listen');

      expect(
        speech.spokenTexts,
        contains('Class 1 reads and explores together.'),
      );
      expect(find.textContaining('not available'), findsOneWidget);

      await _runAudio(tester, 'Play again');
      expect(
        speech.spokenTexts.where(
          (text) => text == 'Class 1 reads and explores together.',
        ),
        hasLength(2),
      );
      expect(find.textContaining('not available'), findsOneWidget);

      final stop = find.widgetWithText(FilledButton, 'Stop audio');
      expect(
        tester.widget<FilledButton>(stop).enabled,
        isFalse,
        reason: 'stop must be disabled once the audio is idle',
      );
    });

    testWidgets('lesson audio plays the migrated asset when it is available',
        (tester) async {
      final playerFactory = TestAudioPlayerFactory();
      final speech = RecordingSpeechEngine();
      final dependencies = _testDependencies(
        audioFactory: playerFactory,
        speechEngine: speech,
      );
      await _pumpApp(tester, dependencies);
      await _openStoryActivity(tester);

      await _runAudio(tester, 'Listen');

      expect(playerFactory.playedPaths, [
        'audio/lessons/lesson_english_c1.wav',
      ]);
      expect(speech.spokenTexts, isEmpty);
      expect(find.textContaining('Audio is playing'), findsOneWidget);

      await _runAudio(tester, 'Stop audio');
      expect(find.textContaining('Audio is stopped'), findsOneWidget);
    });

    testWidgets('audio controls expose one merged semantic group',
        (tester) async {
      final semantics = tester.ensureSemantics();
      final dependencies = _testDependencies();
      await _pumpApp(tester, dependencies);
      await _openStoryActivity(tester);

      expect(find.bySemanticsLabel('Lesson audio'), findsOneWidget);
      expect(
        find.bySemanticsLabel('Listen. Play lesson audio'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('Play again. Play the lesson again'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('Stop audio. Stop the lesson audio'),
        findsOneWidget,
      );

      semantics.dispose();
    });

    testWidgets('every primary action keeps a 64dp touch target',
        (tester) async {
      final dependencies = _testDependencies();
      await _pumpApp(tester, dependencies);
      await _openStoryActivity(tester);

      void expectLarge(String label) {
        final text = find.text(label);
        expect(text, findsOneWidget, reason: 'missing $label');
        final button = find.ancestor(
          of: text,
          matching: find.byWidgetPredicate(
            (widget) => widget is ButtonStyleButton,
          ),
        );
        expect(button, findsOneWidget, reason: 'missing button for $label');
        final size = tester.getSize(button);
        expect(size.height, greaterThanOrEqualTo(64), reason: label);
        expect(size.width, greaterThanOrEqualTo(64), reason: label);
      }

      expectLarge('Next step');
      expectLarge('Listen');
      expectLarge('Stop audio');

      await _advanceToQuiz(tester);
      expectLarge('Read');
      expectLarge('Previous step');

      await _advanceToPractice(tester);
      expectLarge('I finished practicing');
      expectLarge('Clear drawing');

      await _tapText(tester, 'I finished practicing');
      expectLarge('Finish');
      expectLarge('Go home');
    });
  });

  group('quiz', () {
    testWidgets('a correct answer shows a large success state once',
        (tester) async {
      final dependencies = _testDependencies();
      final controller = dependencies.controller as _CountingController;
      await _pumpApp(tester, dependencies);
      await _openStoryActivity(tester);
      await _advanceToQuiz(tester);

      await _tapText(tester, 'Read');

      expect(find.text('Great job!'), findsOneWidget);
      expect(tester.getSize(find.text('Great job!')).height, greaterThan(24));
      expect(find.text('Read'), findsNothing);
      expect(find.text('Run'), findsNothing);

      await _tapText(tester, 'Next question');
      await _tapText(tester, 'Write');
      await _tapText(tester, 'Next step');

      expect(controller.quizScores, hasLength(1));
      expect(controller.quizScores.single.$2, 2);
      expect(
        dependencies.controller.progress.quizBestScores[_storyActivityId],
        2,
      );
    });

    testWidgets(
        'a wrong answer invites one gentle retry and never double counts',
        (tester) async {
      final dependencies = _testDependencies();
      final controller = dependencies.controller as _CountingController;
      await _pumpApp(tester, dependencies);
      await _openStoryActivity(tester);
      await _advanceToQuiz(tester);

      await _tapText(tester, 'Run');

      expect(find.text('Not yet, try again'), findsOneWidget);
      expect(find.text('Reading uses words.'), findsOneWidget);
      expect(find.text('Great job!'), findsNothing);
      expect(find.text('Read'), findsOneWidget);

      await _tapText(tester, 'Read');
      expect(find.text('Great job!'), findsOneWidget);
      expect(find.text('Read'), findsNothing);

      await _tapText(tester, 'Next question');
      await _tapText(tester, 'Write');
      await _tapText(tester, 'Next step');

      expect(controller.quizScores.single.$2, 2);
    });

    testWidgets('a repeated wrong answer reveals the answer once',
        (tester) async {
      final dependencies = _testDependencies();
      final controller = dependencies.controller as _CountingController;
      await _pumpApp(tester, dependencies);
      await _openStoryActivity(tester);
      await _advanceToQuiz(tester);

      await _tapText(tester, 'Run');
      expect(find.text('Not yet, try again'), findsOneWidget);

      await _tapText(tester, 'Run');
      expect(find.text('The answer is Read'), findsOneWidget);
      expect(find.text('Not yet, try again'), findsNothing);
      expect(find.text('Run'), findsNothing);

      await _tapText(tester, 'Next question');
      await _tapText(tester, 'Sing');
      await _tapText(tester, 'Sing');
      await _tapText(tester, 'Next step');

      expect(controller.quizScores.single.$2, 0);
    });
  });

  group('practice and completion', () {
    testWidgets('practice and completion are each saved exactly once',
        (tester) async {
      final dependencies = _testDependencies();
      final controller = dependencies.controller as _CountingController;
      await _pumpApp(tester, dependencies);
      await _openStoryActivity(tester);
      await _advanceToQuiz(tester);

      await _tapText(tester, 'Read');
      await tester.pumpAndSettle();
      await _tapText(tester, 'Next question');
      await tester.pumpAndSettle();
      await _tapText(tester, 'Write');
      await tester.pumpAndSettle();
      await _tapText(tester, 'Next step');
      await tester.pumpAndSettle();

      expect(find.text('Drawing area'), findsNothing);
      expect(find.bySemanticsLabel('Drawing area'), findsOneWidget);
      expect(find.text('Class 1 writes one word.'), findsOneWidget);

      await _tapText(tester, 'Clear drawing');
      await tester.pumpAndSettle();
      await _tapText(tester, 'I finished practicing');
      await tester.pumpAndSettle();

      expect(controller.practiceRecords, hasLength(1));
      expect(dependencies.controller.progress.practiceCount, 1);
      expect(find.text('You did it!'), findsOneWidget);
      expect(find.text('I finished practicing'), findsNothing);

      await _tapText(tester, 'Finish');
      await tester.pumpAndSettle();

      expect(controller.completions, hasLength(1));
      expect(
        dependencies.controller.progress.completedActivityIds,
        contains(_storyActivityId),
      );
      expect(find.text('Saved. You finished this activity.'), findsOneWidget);
      expect(find.text('Go home'), findsOneWidget);
      expect(find.text('Finish'), findsNothing);
    });

    testWidgets('a completion save failure shows a child-safe message',
        (tester) async {
      final progress = TestRecordingProgressStore();
      final dependencies = _testDependencies(progressStore: progress);
      await _pumpApp(tester, dependencies);
      await _openStoryActivity(tester);
      await _advanceToQuiz(tester);
      await _advanceToReward(tester);

      progress.failuresRemaining = 1;
      await _tapText(tester, 'Finish');

      expect(
        find.text('We could not save that yet. Please try again.'),
        findsOneWidget,
      );
      expect(find.text('Go home'), findsOneWidget);
      expect(
        find.widgetWithText(FilledButton, 'Finish').evaluate().length,
        1,
      );

      await _tapText(tester, 'Finish');
      expect(
        find.text('Saved. You finished this activity.'),
        findsOneWidget,
      );
      expect(
        dependencies.controller.progress.completedActivityIds,
        contains(_storyActivityId),
      );

      await _tapText(tester, 'Go home');
      expect(find.text('Continue learning'), findsOneWidget);
    });

    testWidgets('a practice save failure keeps the child on the step',
        (tester) async {
      final progress = TestRecordingProgressStore();
      final dependencies = _testDependencies(progressStore: progress);
      final controller = dependencies.controller as _CountingController;
      await _pumpApp(tester, dependencies);
      await _openStoryActivity(tester);
      await _advanceToQuiz(tester);
      await _advanceToPractice(tester);

      progress.failuresRemaining = 1;
      await _tapText(tester, 'I finished practicing');

      expect(
        find.text('We could not save that yet. Please try again.'),
        findsOneWidget,
      );
      expect(find.text('Step 4 of 5'), findsOneWidget);
      expect(find.text('You did it!'), findsNothing);
      expect(controller.practiceRecords, hasLength(1));
      expect(dependencies.controller.progress.practiceCount, 0);
      final action = find.widgetWithText(FilledButton, 'I finished practicing');
      expect(tester.widget<FilledButton>(action).enabled, isTrue);

      await _tapText(tester, 'I finished practicing');

      expect(controller.practiceRecords, hasLength(2));
      expect(dependencies.controller.progress.practiceCount, 1);
      expect(find.text('Step 5 of 5'), findsOneWidget);
      expect(
        find.text('We could not save that yet. Please try again.'),
        findsNothing,
      );
    });

    testWidgets('a quiz save failure keeps the child on the quiz',
        (tester) async {
      final progress = TestRecordingProgressStore();
      final dependencies = _testDependencies(progressStore: progress);
      final controller = dependencies.controller as _CountingController;
      await _pumpApp(tester, dependencies);
      await _openStoryActivity(tester);
      await _advanceToQuiz(tester);
      await _answerBothQuestions(tester);

      progress.failuresRemaining = 1;
      await _tapText(tester, 'Next step');

      expect(
        find.text('We could not save that yet. Please try again.'),
        findsOneWidget,
      );
      expect(find.text('Step 3 of 5'), findsOneWidget);
      expect(find.text('Step 4 of 5'), findsNothing);
      expect(controller.quizScores, hasLength(1));
      expect(progress.saved, isEmpty);

      await _tapText(tester, 'Next step');

      expect(controller.quizScores, hasLength(2));
      expect(progress.saved, hasLength(1));
      expect(
        progress.saved.single.quizBestScores[_storyActivityId],
        2,
      );
      expect(find.text('Step 4 of 5'), findsOneWidget);
    });

    testWidgets('leaving the last question still stores the quiz score',
        (tester) async {
      final progress = TestRecordingProgressStore();
      final dependencies = _testDependencies(progressStore: progress);
      final controller = dependencies.controller as _CountingController;
      await _pumpApp(tester, dependencies);
      await _openStoryActivity(tester);
      await _advanceToQuiz(tester);
      await _answerBothQuestions(tester);

      await _tapText(tester, 'Previous step');

      expect(controller.quizScores, hasLength(1));
      expect(progress.saved, hasLength(1));
      expect(progress.saved.single.quizBestScores[_storyActivityId], 2);
      expect(find.text('Step 2 of 5'), findsOneWidget);

      await _tapText(tester, 'Previous step');
      await _tapText(tester, 'Home');

      expect(controller.quizScores, hasLength(1));
      expect(progress.saved, hasLength(1));
      expect(find.text('Continue learning'), findsOneWidget);
    });

    testWidgets('a stalled quiz save never blocks leaving the quiz',
        (tester) async {
      final progress = TestRecordingProgressStore();
      final dependencies = _testDependencies(progressStore: progress);
      final controller = dependencies.controller as _CountingController;
      await _pumpApp(tester, dependencies);
      await _openStoryActivity(tester);
      await _advanceToQuiz(tester);
      await _answerBothQuestions(tester);

      final gate = Completer<void>();
      progress.gate = gate;
      await tester.tap(find.text('Previous step'));
      await tester.pump();
      expect(find.text('Step 3 of 5'), findsOneWidget);

      await tester.pump(kSaveTimeout + const Duration(seconds: 1));
      await tester.pumpAndSettle();

      expect(find.text('Step 2 of 5'), findsOneWidget);
      expect(find.text('Card 1 of 2'), findsOneWidget);

      gate.complete();
      await tester.pumpAndSettle();

      expect(controller.quizScores, hasLength(1));
      expect(progress.saved, hasLength(1));
      expect(
        progress.saved.single.quizBestScores[_storyActivityId],
        2,
      );
    });

    testWidgets('leaving during an in-flight quiz save never writes twice',
        (tester) async {
      final progress = TestRecordingProgressStore();
      final dependencies = _testDependencies(progressStore: progress);
      final controller = dependencies.controller as _CountingController;
      await _pumpApp(tester, dependencies);
      await _openStoryActivity(tester);
      await _advanceToQuiz(tester);
      await _answerBothQuestions(tester);

      final gate = Completer<void>();
      progress.gate = gate;
      await tester.tap(find.text('Next step'));
      await tester.pump();
      expect(controller.quizScores, hasLength(1));

      await tester.tap(find.widgetWithText(TextButton, 'Home'));
      await tester.pumpAndSettle();

      expect(controller.quizScores, hasLength(1));
      gate.complete();
      await tester.pumpAndSettle();

      expect(controller.quizScores, hasLength(1));
      expect(progress.saved, hasLength(1));
      expect(
        progress.saved.single.quizBestScores[_storyActivityId],
        2,
      );
      expect(find.text('Continue learning'), findsOneWidget);
    });

    testWidgets('a stalled quiz save tells the child it did not finish',
        (tester) async {
      final progress = TestRecordingProgressStore();
      final dependencies = _testDependencies(progressStore: progress);
      await _pumpApp(tester, dependencies);
      await _openStoryActivity(tester);
      await _advanceToQuiz(tester);
      await _answerBothQuestions(tester);

      final gate = Completer<void>();
      progress.gate = gate;
      await tester.tap(find.text('Previous step'));
      await tester.pump();
      await tester.pump(kSaveTimeout + const Duration(seconds: 1));
      await tester.pumpAndSettle();

      expect(find.text(kSaveTimeoutMessage), findsWidgets);

      gate.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('a stalled quiz save warns before leaving the activity',
        (tester) async {
      final progress = TestRecordingProgressStore();
      final dependencies = _testDependencies(progressStore: progress);
      await _pumpApp(tester, dependencies);
      await _openStoryActivity(tester);
      await _advanceToQuiz(tester);
      await _answerBothQuestions(tester);

      final gate = Completer<void>();
      progress.gate = gate;
      await tester.tap(find.widgetWithText(TextButton, 'Home'));
      await tester.pump();
      await tester.pump(kSaveTimeout + const Duration(seconds: 1));
      await tester.pumpAndSettle();

      expect(find.text('Continue learning'), findsOneWidget);
      expect(find.text(kSaveTimeoutMessage), findsOneWidget);

      gate.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('a stalled game score save warns before leaving',
        (tester) async {
      final progress = TestRecordingProgressStore();
      final dependencies = _testDependencies(progressStore: progress);
      await _pumpApp(tester, dependencies);
      await _openGame(tester, 'Find the Letter');

      final target = _targetText(tester);
      await _tapKey(tester, Key('game-option-$target'));
      await _tapText(tester, 'Next round');

      final gate = Completer<void>();
      progress.gate = gate;
      await _tapText(tester, 'Go home');
      await tester.pump();
      await tester.pump(kGameSaveTimeout + const Duration(seconds: 1));
      await tester.pumpAndSettle();

      expect(find.text('Continue learning'), findsOneWidget);
      expect(find.text(kSaveTimeoutMessage), findsWidgets);

      gate.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('an already completed activity never saves again',
        (tester) async {
      final preferences = TestProgressPreferences();
      preferences.values['learning_progress_v2:test-child'] = jsonEncode(
        <String, dynamic>{
          'schemaVersion': 2,
          'completedActivityIds': <String>[_storyActivityId],
          'quizBestScores': <String, int>{},
          'practiceCount': 0,
          'lastActivityId': _storyActivityId,
          'lastPracticeDay': null,
        },
      );
      final dependencies = _testDependencies(preferences: preferences);
      final controller = dependencies.controller as _CountingController;
      await _pumpApp(tester, dependencies);
      await _openStoryActivity(tester);
      await _advanceToQuiz(tester);
      await _advanceToReward(tester);

      await _reveal(tester, find.text('You finished this activity before.'));
      expect(find.text('You finished this activity before.'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Finish'), findsNothing);
      expect(controller.completions, isEmpty);
    });
  });

  group('migrated games', () {
    testWidgets('the letter book adapts migrated content and returns',
        (tester) async {
      final dependencies = _testDependencies();
      await _pumpApp(tester, dependencies);
      await _openGame(tester, 'Big ABC');

      expect(find.byKey(const Key('letter-card-A')), findsOneWidget);
      expect(find.byKey(const Key('letter-card-B')), findsOneWidget);
      expect(find.text('Listen'), findsNothing);

      await _tapKey(tester, const Key('letter-card-A'));

      expect(find.text('Apple'), findsOneWidget);
      expect(find.text('Back to letters'), findsOneWidget);

      await _tapText(tester, 'Back to letters');
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('letter-card-A')), findsOneWidget);
      expect(find.text('Finish'), findsOneWidget);
    });

    testWidgets('the number book keeps large targets on a narrow surface',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final dependencies = _testDependencies();
      await _pumpApp(tester, dependencies);
      await _openGame(tester, 'Numbers 1 to 10');

      final card = find.byKey(const Key('number-card-7'));
      expect(card, findsOneWidget);
      final size = tester.getSize(card);
      expect(size.width, greaterThanOrEqualTo(64));
      expect(size.height, greaterThanOrEqualTo(64));

      await _tapKey(tester, const Key('number-card-7'));
      expect(find.text('Back to numbers'), findsOneWidget);
    });

    testWidgets('the word book spells out the selected word', (tester) async {
      final dependencies = _testDependencies();
      await _pumpApp(tester, dependencies);
      await _openGame(tester, 'First Words');

      await _tapKey(tester, const Key('word-card-CAT'));

      expect(find.text('C'), findsOneWidget);
      expect(find.text('A'), findsOneWidget);
      expect(find.text('T'), findsOneWidget);
      expect(find.text('Back to words'), findsOneWidget);
    });

    testWidgets('find the letter scores every round and leaves explicitly',
        (tester) async {
      final dependencies = _testDependencies();
      final controller = dependencies.controller as _CountingController;
      await _pumpApp(tester, dependencies);
      await _openGame(tester, 'Find the Letter');

      for (var round = 1; round <= 5; round++) {
        expect(find.text('Round $round of 5'), findsOneWidget);
        final target = _targetText(tester);
        await _tapKey(tester, Key('game-option-$target'));
        expect(find.text('Great job!'), findsOneWidget);
        await _tapText(tester, round >= 5 ? 'See my star' : 'Next round');
        await tester.pumpAndSettle();
      }

      expect(find.text('You are a star!'), findsOneWidget);
      expect(find.text('You got 5 out of 5.'), findsOneWidget);
      expect(find.text('Play again'), findsOneWidget);
      expect(find.text('Go home'), findsOneWidget);
      expect(
        controller.quizScores.single,
        (_findLetterActivityId, 5),
      );

      await _tapText(tester, 'Go home');
      await tester.pumpAndSettle();

      expect(find.text('Continue learning'), findsOneWidget);
      expect(controller.completions, [_findLetterActivityId]);
    });

    testWidgets('match letters offers a gentle retry', (tester) async {
      final dependencies = _testDependencies();
      await _pumpApp(tester, dependencies);
      await _openGame(tester, 'Match Letters');

      final target = _targetText(tester);
      final wrong = _optionText(tester, target);

      await _tapKey(tester, Key('game-option-$wrong'));

      expect(find.text('Try again, little star'), findsOneWidget);
      expect(find.text('Great job!'), findsNothing);

      await _tapKey(tester, Key('game-option-${target.toLowerCase()}'));

      expect(find.text('Great job!'), findsOneWidget);
    });

    testWidgets('leaving after round three stores the partial score once',
        (tester) async {
      final dependencies = _testDependencies();
      final controller = dependencies.controller as _CountingController;
      await _pumpApp(tester, dependencies);
      await _openGame(tester, 'Find the Letter');

      for (var round = 1; round <= 3; round++) {
        final target = _targetText(tester);
        await _tapKey(tester, Key('game-option-$target'));
        await _tapText(tester, 'Next round');
        await tester.pumpAndSettle();
      }

      expect(find.text('Round 4 of 5'), findsOneWidget);

      await _tapText(tester, 'Go home');
      await tester.pumpAndSettle();

      expect(find.text('Continue learning'), findsOneWidget);
      expect(controller.quizScores, <(String, int)>[
        (_findLetterActivityId, 3),
      ]);

      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 1));

      expect(controller.quizScores, <(String, int)>[
        (_findLetterActivityId, 3),
      ]);
      expect(controller.completions, isEmpty);
    });

    testWidgets('a mid-game back exit stores the partial score once',
        (tester) async {
      final dependencies = _testDependencies();
      final controller = dependencies.controller as _CountingController;
      await _pumpApp(tester, dependencies);
      await _openGame(tester, 'Find the Letter');

      for (var round = 1; round <= 3; round++) {
        final target = _targetText(tester);
        await _tapKey(tester, Key('game-option-$target'));
        await _tapText(tester, 'Next round');
        await tester.pumpAndSettle();
      }

      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();

      expect(controller.quizScores, <(String, int)>[
        (_findLetterActivityId, 3),
      ]);
    });

    testWidgets('gameplay gives haptic selection and completion feedback',
        (tester) async {
      final adapter = TestHapticFeedbackAdapter();
      final dependencies = _testDependencies(
        haptics: HapticsService(adapter: adapter),
      );
      await _pumpApp(tester, dependencies);
      await _openGame(tester, 'Find the Letter');

      final target = _targetText(tester);
      await _tapKey(tester, Key('game-option-$target'));

      expect(adapter.countOf(HapticCue.success), 1);
    });

    testWidgets('a wrong option gives light haptic selection feedback',
        (tester) async {
      final adapter = TestHapticFeedbackAdapter();
      final dependencies = _testDependencies(
        haptics: HapticsService(adapter: adapter),
      );
      await _pumpApp(tester, dependencies);
      await _openGame(tester, 'Match Letters');

      final wrong = _optionText(tester, _targetText(tester));
      await _tapKey(tester, Key('game-option-$wrong'));

      expect(adapter.countOf(HapticCue.selection), 1);
      expect(adapter.countOf(HapticCue.success), 0);
    });

    testWidgets('play again restarts the round counter', (tester) async {
      final dependencies = _testDependencies();
      await _pumpApp(tester, dependencies);
      await _openGame(tester, 'Find the Letter');

      for (var round = 1; round <= 5; round++) {
        final target = _targetText(tester);
        await _tapKey(tester, Key('game-option-$target'));
        await _tapText(tester, round >= 5 ? 'See my star' : 'Next round');
        await tester.pumpAndSettle();
      }

      await _tapText(tester, 'Play again');
      await tester.pumpAndSettle();

      expect(find.text('Round 1 of 5'), findsOneWidget);
      expect(find.text('You are a star!'), findsNothing);
    });

    testWidgets('the small letter book reads the shipped small-first fronts',
        (tester) async {
      final dependencies = _testDependencies();
      await _pumpApp(tester, dependencies);
      await _openGame(tester, 'Small abc');

      await _tapKey(tester, const Key('letter-card-A'));

      expect(find.text('A'), findsOneWidget);
      expect(find.text('A a'), findsOneWidget);
      expect(find.text('Apple'), findsOneWidget);
      expect(find.text(_appleHindi), findsOneWidget);
    });

    testWidgets('the match game offers small letters for a capital target',
        (tester) async {
      final dependencies = _testDependencies();
      await _pumpApp(tester, dependencies);
      await _openGame(tester, 'Match Letters');

      expect(find.text('Match me!'), findsOneWidget);
      final target = _targetText(tester);
      expect(_isCapital(target), isTrue, reason: target);
      expect(find.text('Find this letter'), findsNothing);
      expect(find.byKey(Key('game-option-${target.toLowerCase()}')), findsOne);
      expect(find.byKey(Key('game-option-$target')), findsNothing);
    });

    testWidgets('the find game offers capital letters for a capital target',
        (tester) async {
      final dependencies = _testDependencies();
      await _pumpApp(tester, dependencies);
      await _openGame(tester, 'Find the Letter');

      expect(find.text('Find this letter'), findsOneWidget);
      final target = _targetText(tester);
      expect(_isCapital(target), isTrue, reason: target);
      expect(find.byKey(Key('game-option-$target')), findsOne);
      expect(find.text('Match me!'), findsNothing);
    });
  });

  group('migrated content parsing', () {
    test('reads the shipped capital-first letter book', () {
      final letter = parseLetter(
        const FlashcardContent(
          front: 'A a',
          back: '$_apple | $_appleHindi | $_appleMarathi',
        ),
      );

      expect(letter.capital, 'A');
      expect(letter.small, 'a');
      expect(letter.word, 'Apple');
      expect(letter.emoji, '\u{1F34E}');
      expect(letter.translations, <String>[_appleHindi, _appleMarathi]);
      expect(letter.smallFromBack, isFalse);
    });

    test('reads the shipped small-first letter book', () {
      final letter = parseLetter(
        const FlashcardContent(
          front: 'a A',
          back: '$_apple | $_appleHindi | $_appleMarathi',
        ),
      );

      expect(letter.capital, 'A');
      expect(letter.small, 'a');
      expect(letter.word, 'Apple');
      expect(letter.emoji, '\u{1F34E}');
      expect(letter.translations, <String>[_appleHindi, _appleMarathi]);
      expect(letter.smallFromBack, isFalse);
    });

    test('reads the shipped match-case back format', () {
      final letter = parseLetter(
        const FlashcardContent(
          front: 'A',
          back: 'a | $_apple | $_appleHindi | $_appleMarathi',
        ),
      );

      expect(letter.capital, 'A');
      expect(letter.small, 'a');
      expect(letter.word, 'Apple');
      expect(letter.emoji, '\u{1F34E}');
      expect(letter.translations, <String>[_appleHindi, _appleMarathi]);
      expect(letter.smallFromBack, isTrue);
    });

    test('falls back to the capital when no small letter is present', () {
      final letter = parseLetter(
        const FlashcardContent(front: 'A', back: _apple),
      );

      expect(letter.capital, 'A');
      expect(letter.small, 'a');
      expect(letter.word, 'Apple');
      expect(letter.smallFromBack, isFalse);
    });

    test('reads the shipped number and word back formats', () {
      final number = parseNumber(
        const FlashcardContent(
          front: '1',
          back: 'One | \u090F\u0915 | \u090F\u0915',
        ),
      );
      final word = parseWord(
        const FlashcardContent(
          front: 'CAT',
          back: 'CAT \u{1F431} | \u092C\u093F\u0932\u094D\u0932\u0940 | '
              '\u092E\u093E\u0902\u091C\u0930',
        ),
      );
      final splitWord = parseWord(
        const FlashcardContent(
          front: 'CAT',
          back: 'CAT | \u{1F431} | \u092C\u093F\u0932\u094D\u0932\u0940 | '
              '\u092E\u093E\u0902\u091C\u0930',
        ),
      );

      expect(number.value, 1);
      expect(number.digits, '1');
      expect(number.word, 'One');
      expect(number.translations, <String>['\u090F\u0915', '\u090F\u0915']);
      expect(word.word, 'CAT');
      expect(word.emoji, '\u{1F431}');
      expect(word.letters, <String>['C', 'A', 'T']);
      expect(
        word.translations,
        <String>[
          '\u092C\u093F\u0932\u094D\u0932\u0940',
          '\u092E\u093E\u0902\u091C\u0930'
        ],
      );
      expect(splitWord.word, 'CAT');
      expect(splitWord.emoji, '\u{1F431}');
      expect(
        splitWord.translations,
        <String>[
          '\u092C\u093F\u0932\u094D\u0932\u0940',
          '\u092E\u093E\u0902\u091C\u0930',
        ],
      );
    });

    test('parses every shipped little Stars card', () {
      final catalog = _shippedCatalog();
      final activities = <String, ActivityContent>{
        for (final activity in catalog.activities)
          if (activity.subjectId == 'little') activity.id: activity,
      };

      expect(
        activities.keys,
        containsAll(<String>[
          'class-0-subject-little-activity-capitals',
          'class-0-subject-little-activity-smalls',
          'class-0-subject-little-activity-numbers',
          'class-0-subject-little-activity-find-letter',
          'class-0-subject-little-activity-match-case',
          'class-0-subject-little-activity-first-words',
        ]),
      );

      for (final entry in <String, String>{
        'class-0-subject-little-activity-capitals': 'Big ABC',
        'class-0-subject-little-activity-smalls': 'Small abc',
        'class-0-subject-little-activity-find-letter': 'Find the Letter',
      }.entries) {
        for (final card in activities[entry.key]!.flashcards) {
          final letter = parseLetter(card);
          expect(letter.capital, letter.small.toUpperCase(),
              reason: entry.value);
          expect(letter.small, letter.small.toLowerCase(), reason: entry.value);
          expect(letter.capital.length, 1, reason: entry.value);
          expect(letter.word, isNotEmpty, reason: entry.value);
          expect(letter.emoji, isNotEmpty, reason: entry.value);
          expect(letter.translations, hasLength(2), reason: entry.value);
          expect(letter.smallFromBack, isFalse, reason: entry.value);
        }
      }

      for (final card
          in activities['class-0-subject-little-activity-match-case']!
              .flashcards) {
        final letter = parseLetter(card);
        expect(letter.capital, letter.small.toUpperCase());
        expect(letter.small, letter.small.toLowerCase());
        expect(letter.capital.length, 1);
        expect(letter.word, isNotEmpty);
        expect(letter.word, isNot(letter.small));
        expect(letter.emoji, isNotEmpty);
        expect(letter.translations, hasLength(2));
        expect(letter.smallFromBack, isTrue);
      }

      for (final card in activities['class-0-subject-little-activity-numbers']!
          .flashcards) {
        final number = parseNumber(card);
        expect(number.value, greaterThan(0));
        expect(number.word, isNotEmpty);
        expect(number.translations, hasLength(2));
      }

      for (final card
          in activities['class-0-subject-little-activity-first-words']!
              .flashcards) {
        final word = parseWord(card);
        expect(word.word, isNotEmpty);
        expect(word.emoji, isNotEmpty);
        expect(word.letters, isNotEmpty);
        expect(word.translations, hasLength(2));
      }
    });
  });

  group('app scope', () {
    testWidgets('propagates controller notifications to descendants',
        (tester) async {
      final dependencies = _testDependencies();
      final controller = dependencies.controller as _CountingController;
      await _pumpApp(tester, dependencies);
      await _tapText(tester, 'Choose a subject');
      await _tapText(tester, 'Class 1');
      await _tapText(tester, 'English');

      expect(find.text('Ready to start'), findsNWidgets(2));
      expect(find.text('Finished'), findsNothing);

      await controller.completeActivityIfNeeded(_storyActivityId);
      await tester.pumpAndSettle();

      expect(find.text('Finished'), findsOneWidget);
      expect(find.text('Ready to start'), findsOneWidget);
    });

    testWidgets('rebuilds after a recorded quiz score', (tester) async {
      final dependencies = _testDependencies();
      final controller = dependencies.controller as _CountingController;
      await _pumpApp(tester, dependencies);
      await _tapText(tester, 'Choose a subject');
      await _tapText(tester, 'Class 1');
      await _tapText(tester, 'English');

      expect(find.text('Ready to start'), findsNWidgets(2));
      expect(find.text('Best quiz 2 of 2'), findsNothing);

      await controller.recordQuizScore(_storyActivityId, 2);
      await tester.pumpAndSettle();

      expect(
        find.text('Best quiz 2 of 2'),
        findsOneWidget,
      );
      expect(find.text('Ready to start'), findsOneWidget);
    });

    testWidgets('replaces the controller without leaking the old listener',
        (tester) async {
      final first = _testDependencies();
      final second = _testDependencies();
      final firstController = first.controller as _CountingController;
      final secondController = second.controller as _CountingController;
      await firstController.initialize();
      await secondController.initialize();
      var builds = 0;

      await tester.pumpWidget(
        AppScope(
          controller: firstController,
          child: Builder(
            builder: (context) {
              builds++;
              expect(AppScope.of(context), same(firstController));
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(builds, 1);

      firstController.openSubject('english');
      await tester.pumpAndSettle();
      expect(builds, 2);

      await tester.pumpWidget(
        AppScope(
          controller: secondController,
          child: Builder(
            builder: (context) {
              builds++;
              expect(AppScope.of(context), same(secondController));
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(builds, 3);

      firstController.openSubject('mathematics');
      await tester.pumpAndSettle();
      expect(builds, 3, reason: 'the replaced controller must not notify');

      secondController.openSubject('english');
      await tester.pumpAndSettle();
      expect(builds, 4, reason: 'the new controller must notify');
    });
  });

  group('class selector accessibility', () {
    testWidgets('every class chip meets the 64dp minimum size', (tester) async {
      final dependencies = _testDependencies();
      await _pumpApp(tester, dependencies);
      await _tapText(tester, 'Choose a subject');

      for (var level = 1; level <= 5; level++) {
        final chip = find.widgetWithText(ChoiceChip, 'Class $level');
        expect(chip, findsOneWidget, reason: 'Class $level');
        final size = tester.getSize(chip);
        expect(size.height, greaterThanOrEqualTo(kClassTargetSize));
        expect(size.width, greaterThanOrEqualTo(kClassTargetSize));
      }
    });

    testWidgets('a class chip exposes a working semantic tap action',
        (tester) async {
      final semantics = tester.ensureSemantics();
      final dependencies = _testDependencies();
      await _pumpApp(tester, dependencies);
      await _tapText(tester, 'Choose a subject');
      await _tapText(tester, 'Class 1');
      await _tapText(tester, 'English');

      expect(find.text('Choose an activity for Class 1.'), findsOneWidget);

      final node = tester.getSemantics(find.bySemanticsLabel('Class 2'));
      expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
      expect(node.label, 'Class 2');
      expect(node.flagsCollection.isSelected, Tristate.isFalse);

      tester.semantics.tap(find.semantics.byLabel('Class 2'));
      await tester.pumpAndSettle();

      expect(find.text('Choose an activity for Class 2.'), findsOneWidget);
      final selected = tester.getSemantics(find.bySemanticsLabel('Class 2'));
      expect(selected.flagsCollection.isSelected, Tristate.isTrue);

      semantics.dispose();
    });
  });
}

Future<void> _pumpApp(WidgetTester tester, AppDependencies dependencies) async {
  await tester.pumpWidget(SchoolLearningApp(dependencies: dependencies));
  await tester.pumpAndSettle();
  await dependencies.controller.initialize();
}

Future<void> _openStoryActivity(WidgetTester tester) async {
  await _tapText(tester, 'Choose a subject');
  await tester.pumpAndSettle();
  await _tapText(tester, 'Class 1');
  await tester.pumpAndSettle();
  await _tapText(tester, 'English');
  await tester.pumpAndSettle();
  await _tapText(tester, 'Class 1 Story');
  await tester.pumpAndSettle();
}

Future<void> _openGame(WidgetTester tester, String title) async {
  await _tapText(tester, 'Play and learn');
  await tester.pumpAndSettle();
  await _tapText(tester, title);
  await tester.pumpAndSettle();
}

Future<void> _advanceToQuiz(WidgetTester tester) async {
  await _tapText(tester, 'Next step');
  await tester.pumpAndSettle();
  await _tapText(tester, 'Show the answer');
  await tester.pumpAndSettle();
  await _tapText(tester, 'Next card');
  await tester.pumpAndSettle();
  await _tapText(tester, 'Show the answer');
  await tester.pumpAndSettle();
  await _tapText(tester, 'Next step');
  await tester.pumpAndSettle();
}

Future<void> _advanceToPractice(WidgetTester tester) async {
  await _answerBothQuestions(tester);
  await _tapText(tester, 'Next step');
  await tester.pumpAndSettle();
}

Future<void> _answerBothQuestions(WidgetTester tester) async {
  await _tapText(tester, 'Read');
  await _tapText(tester, 'Next question');
  await _tapText(tester, 'Write');
}

Future<void> _advanceToReward(WidgetTester tester) async {
  await _advanceToPractice(tester);
  await _tapText(tester, 'I finished practicing');
  await tester.pumpAndSettle();
}

Future<void> _tapText(WidgetTester tester, String label) async {
  final finder = find.text(label);
  await _reveal(tester, finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _tapKey(WidgetTester tester, Key key) async {
  final finder = find.byKey(key);
  await _reveal(tester, finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _reveal(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      finder,
      160,
      scrollable: find.byType(Scrollable).first,
    );
  }
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

Future<void> _runAudio(WidgetTester tester, String label) async {
  await tester.tap(find.text(label));
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 50)),
  );
  await tester.pumpAndSettle();
}

String _targetText(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const Key('game-target'))).data!;

ContentCatalog _shippedCatalog() {
  final source = File('assets/content/catalog.json').readAsStringSync();
  return ContentCatalog.fromJson(
      (jsonDecode(source) as Map).cast<String, dynamic>());
}

bool _isCapital(String value) {
  final pattern = RegExp('^' '[A-Z]' r'$');
  return pattern.hasMatch(value);
}

String _optionText(WidgetTester tester, String target) {
  final letters = tester
      .widgetList<Text>(find.byType(Text))
      .map((widget) => widget.data ?? '')
      .where((value) => RegExp(r'^[A-Za-z]$').hasMatch(value))
      .where((value) => value.toLowerCase() != target.toLowerCase())
      .toSet();
  expect(letters, hasLength(2), reason: 'two wrong options are expected');
  return letters.first;
}

class _CountingController extends AppController {
  _CountingController({
    required super.content,
    required super.progress,
    required super.audio,
    required super.speech,
    super.haptics,
  });

  final List<String> completions = <String>[];
  final List<String> practiceRecords = <String>[];
  final List<(String, int)> quizScores = <(String, int)>[];

  @override
  Future<void> completeActivity(String activityId) {
    completions.add(activityId);
    return super.completeActivity(activityId);
  }

  @override
  Future<void> recordPractice(String activityId) {
    practiceRecords.add(activityId);
    return super.recordPractice(activityId);
  }

  @override
  Future<void> recordQuizScore(String activityId, int score) {
    quizScores.add((activityId, score));
    return super.recordQuizScore(activityId, score);
  }
}

AppDependencies _testDependencies({
  ProgressPreferences? preferences,
  ProgressStore? progressStore,
  AudioPlayerFactory? audioFactory,
  SpeechEngine? speechEngine,
  HapticsService? haptics,
}) {
  final content = ContentRepository(bundle: activityCatalogBundle());
  final progress = progressStore ??
      ProgressStore(
        profileId: 'test-child',
        preferences: preferences ?? TestProgressPreferences(),
      );
  final audio = AudioService(
    playerFactory: audioFactory ?? TestAudioPlayerFactory(),
  );
  final speech = SpeechService(
    engine: speechEngine ?? RecordingSpeechEngine(),
  );
  final hapticsService =
      haptics ?? HapticsService(adapter: TestHapticFeedbackAdapter());
  final controller = _CountingController(
    content: content,
    progress: progress,
    audio: audio,
    speech: speech,
    haptics: hapticsService,
  );
  return AppDependencies(
    controller: controller,
    content: content,
    progress: progress,
    audio: audio,
    speech: speech,
    haptics: hapticsService,
  );
}
