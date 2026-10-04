import 'dart:math' as math;
import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:school_learning_app/app/app.dart';
import 'package:school_learning_app/core/audio/audio_service.dart';
import 'package:school_learning_app/core/speech/speech_service.dart';
import 'package:school_learning_app/data/content/content_repository.dart';
import 'package:school_learning_app/data/progress/progress_store.dart';
import 'package:school_learning_app/features/games/game_screen.dart';
import 'package:school_learning_app/features/learning/activity_screen.dart';
import 'package:school_learning_app/features/learning/learning_shell.dart';

import '../support/activity_catalog.dart';
import '../support/fakes.dart';

const Size _narrowSurface = Size(320, 640);
const Size _fittedSurface = Size(360, 640);
const double _largeTextScale = 2.0;
const double _fittedTextScale = 1.3;
const double _choiceCardPadding = 16;
const String _listenLabel = 'Listen. Play lesson audio';
const String _againLabel = 'Play again. Play the lesson again';
const String _stopLabel = 'Stop audio. Stop the lesson audio';
const String _teacherLabel =
    'Ask your teacher. Get a helpful hint when you need one.';

void main() {
  group('large text on a narrow surface', () {
    testWidgets('home primary actions stay visible and hittable',
        (tester) async {
      await _pumpNarrowApp(tester);

      for (final label in <String>[
        'Continue learning',
        'Choose a subject',
        'Play and learn',
        'Ask your teacher',
      ]) {
        final card = find.ancestor(
          of: find.text(label),
          matching: find.byType(InkWell),
        );
        await _reveal(tester, find.text(label));
        expectOnScreen(tester, find.text(label), reason: label);
        expectMinimumTarget(tester, card, reason: '$label card');
      }

      await _tap(tester, 'Choose a subject');
      expect(find.text('Pick a subject'), findsOneWidget);
    });

    testWidgets('the parent lock and teacher control stay reachable',
        (tester) async {
      await _pumpNarrowApp(tester);

      final lock = find.byTooltip('Grown-ups only');
      await _reveal(tester, lock);
      expectOnScreen(tester, lock, reason: 'Grown-ups only');
      expectMinimumTarget(tester, lock, reason: 'Grown-ups only');

      await _tap(tester, 'Ask your teacher');
      expect(find.text('Your teacher is coming next.'), findsOneWidget);
    });

    testWidgets('class chips stay visible and hittable', (tester) async {
      await _pumpNarrowApp(tester);
      await _tap(tester, 'Choose a subject');

      await _reveal(tester, find.text('Choose a class'));
      expectOnScreen(tester, find.text('Choose a class'),
          reason: 'class header');
      for (var level = 1; level <= 5; level++) {
        final chip = find.widgetWithText(ChoiceChip, 'Class $level');
        await _reveal(tester, chip);
        expectOnScreen(tester, chip, reason: 'Class $level');
        expectMinimumTarget(tester, chip, reason: 'Class $level');
      }

      await _tap(tester, 'Class 3');
      expect(find.text('Class 3'), findsWidgets);
    });

    testWidgets('lesson audio controls stay visible and hittable',
        (tester) async {
      await _pumpNarrowApp(tester);
      await _openStoryActivity(tester);

      await _reveal(tester, find.text('Audio is stopped.'));
      expectOnScreen(tester, find.text('Audio is stopped.'),
          reason: 'audio status');
      for (final label in <String>['Listen', 'Play again', 'Stop audio']) {
        final button = _audioButton(label);
        await _reveal(tester, button);
        expectOnScreen(tester, button, reason: label);
        expectMinimumTarget(tester, button, reason: label);
      }

      await _tap(tester, 'Next step');
      expect(find.text('Show the answer'), findsOneWidget);
    });

    testWidgets('the drawing area and its reset action stay reachable',
        (tester) async {
      final semantics = tester.ensureSemantics();
      await _pumpNarrowApp(tester);
      await _openStoryActivity(tester);
      await _advanceToPractice(tester);

      await _reveal(tester, find.text('Clear drawing'));
      final clear = _buttonFor('Clear drawing');
      expectOnScreen(tester, clear, reason: 'Clear drawing');
      expectMinimumTarget(tester, clear, reason: 'Clear drawing');
      expectMinimumTarget(
        tester,
        find.byType(DrawingPad),
        reason: 'Drawing area',
      );
      expect(find.bySemanticsLabel('Drawing area'), findsOneWidget);

      await _tap(tester, 'Clear drawing');
      expect(find.bySemanticsLabel('Drawing area'), findsOneWidget);

      semantics.dispose();
    });

    testWidgets('the activity reward actions stay visible and hittable',
        (tester) async {
      await _pumpNarrowApp(tester);
      await _openStoryActivity(tester);
      await _advanceToReward(tester);

      for (final label in <String>['Finish', 'Go home', 'Previous step']) {
        final button = _buttonFor(label);
        await _reveal(tester, button);
        expectOnScreen(tester, button, reason: label);
        expectMinimumTarget(tester, button, reason: label);
      }

      await _reveal(tester, find.text('You did it!'));
      expectOnScreen(tester, find.text('You did it!'), reason: 'reward title');
      final score = find.text('You answered 2 of 2 quiz questions.');
      await _reveal(tester, score);
      expectOnScreen(tester, score, reason: 'reward score');

      await _tap(tester, 'Finish');
      final saved = find.text('Saved. You finished this activity.');
      await _reveal(tester, saved);
      expectOnScreen(tester, saved, reason: 'saved confirmation');
    });

    testWidgets('home choice text is never wider than its card',
        (tester) async {
      await _pumpNarrowApp(tester,
          surface: _fittedSurface, textScale: _fittedTextScale);

      for (final entry in <String, String>{
        'Continue learning': 'Start your first activity.',
        'Choose a subject': 'Pick something you want to explore.',
        'Play and learn': 'Letters, numbers, words, and gentle games.',
        'Ask your teacher': 'Get a helpful hint when you need one.',
      }.entries) {
        await _reveal(tester, find.text(entry.key));
        _expectFitsInCard(tester, entry.key, reason: entry.key);
        await _reveal(tester, find.text(entry.value));
        _expectFitsInCard(tester, entry.value, reason: entry.value);
      }
    });

    testWidgets('subject activity cards stay usable at large text',
        (tester) async {
      final semantics = tester.ensureSemantics();
      await _pumpNarrowApp(tester);
      await _tap(tester, 'Choose a subject');
      await _tap(tester, 'English');

      expect(find.text('Choose an activity for Class 1.'), findsOneWidget);
      for (final title in <String>['Class 1 Story', 'Class 1 Poem']) {
        final card = find.ancestor(
          of: find.text(title),
          matching: find.byType(InkWell),
        );
        await _reveal(tester, find.text(title));
        expectOnScreen(tester, find.text(title), reason: title);
        expectOnScreen(tester, card, reason: title);
        expectMinimumTarget(tester, card, reason: title);
        _expectNoChevron(tester, card, reason: title);
        _expectFullWidthText(tester, find.text(title), card, reason: title);
      }

      expect(find.text('Ready to start'), findsNWidgets(2));
      expect(
        find.bySemanticsLabel(
          RegExp(r'^Class 1 Story\. Class 1 reads and explores together\.'),
        ),
        findsOneWidget,
      );

      await _tap(tester, 'Class 1 Story');
      expect(find.text('Step 1 of 5'), findsOneWidget);

      semantics.dispose();
    });

    testWidgets('stacked subject and game cards keep their own icons',
        (tester) async {
      final semantics = tester.ensureSemantics();
      await _pumpNarrowApp(tester);
      await _tap(tester, 'Choose a subject');

      await _reveal(tester, find.text('English'));
      expect(
        find.descendant(
          of: _cardFor('English'),
          matching: find.byIcon(Icons.menu_book_outlined),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: _cardFor('English'),
          matching: find.byIcon(Icons.auto_stories_outlined),
        ),
        findsNothing,
        reason: 'no card may fall back to the hard-coded story icon',
      );
      expect(find.byIcon(Icons.menu_book_outlined), findsOneWidget);
      expect(find.byIcon(Icons.calculate_outlined), findsOneWidget);

      await _tap(tester, 'Home');
      await _tap(tester, 'Play and learn');

      for (final entry in <String, IconData>{
        'Find the Letter': Icons.sports_esports_outlined,
        'Match Letters': Icons.sports_esports_outlined,
        'Big ABC': Icons.text_fields,
        'Numbers 1 to 10': Icons.pin_outlined,
        'First Words': Icons.spellcheck_outlined,
      }.entries) {
        await _reveal(tester, find.text(entry.key));
        expect(
          find.descendant(
            of: _cardFor(entry.key),
            matching: find.byIcon(entry.value),
          ),
          findsOneWidget,
          reason: entry.key,
        );
      }
      expect(find.byIcon(Icons.sports_esports_outlined), findsNWidgets(2));

      semantics.dispose();
    });

    testWidgets('the reward step never strands a child on a finished step',
        (tester) async {
      final dependencies = _testDependencies();
      await _pumpApp(tester, dependencies);
      await _openStoryActivity(tester);
      await _advanceToReward(tester);

      await _tap(tester, 'Previous step');

      expect(find.text('Step 3 of 5'), findsOneWidget);
      expect(
        find.widgetWithText(FilledButton, 'I finished practicing'),
        findsNothing,
      );
      expect(find.text('Question 1 of 2'), findsOneWidget);
    });
  });

  group('semantic labels', () {
    testWidgets('the parent lock is labelled and never reachable from a game',
        (tester) async {
      final semantics = tester.ensureSemantics();
      final dependencies = _testDependencies();
      await _pumpApp(tester, dependencies);

      final lock = tester.getSemantics(find.bySemanticsLabel('Grown-ups only'));
      expect(lock.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
      expect(lock.flagsCollection.isButton, isTrue);

      await _openGame(tester, 'Find the Letter');

      expect(find.bySemanticsLabel('Grown-ups only'), findsNothing);
      expect(find.byTooltip('Grown-ups only'), findsNothing);
      expect(find.bySemanticsLabel('Back'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Home'), findsOneWidget);

      semantics.dispose();
    });

    testWidgets('the teacher control names its visible label', (tester) async {
      final semantics = tester.ensureSemantics();
      await _pumpApp(tester, _testDependencies());

      final node = tester.getSemantics(find.bySemanticsLabel(_teacherLabel));
      expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
      expect(node.flagsCollection.isButton, isTrue);
      expect(node.label, contains('Ask your teacher'));

      semantics.dispose();
    });

    testWidgets('audio controls name their visible label and busy state',
        (tester) async {
      final semantics = tester.ensureSemantics();
      final dependencies = _testDependencies();
      await _pumpApp(tester, dependencies);
      await _openStoryActivity(tester);

      expect(find.bySemanticsLabel('Lesson audio'), findsOneWidget);
      _expectTappable(tester, _listenLabel);
      _expectTappable(tester, _againLabel);
      _expectDisabled(tester, _stopLabel);

      await _runAudio(tester, 'Listen');

      final listen = tester.getSemantics(find.bySemanticsLabel(_listenLabel));
      expect(
        listen.getSemanticsData().hasAction(SemanticsAction.tap),
        isFalse,
        reason: 'listen must be disabled while audio is busy',
      );
      expect(listen.flagsCollection.isEnabled, Tristate.isFalse);
      _expectDisabled(tester, _againLabel);
      _expectTappable(tester, _stopLabel);

      final audio = tester.getSemantics(find.bySemanticsLabel('Lesson audio'));
      expect(audio.value, 'Audio is playing.');
      expect(audio.flagsCollection.isLiveRegion, isTrue);

      await _runAudio(tester, 'Stop audio');

      _expectTappable(tester, _listenLabel);
      _expectDisabled(tester, _stopLabel);
      expect(
        tester.getSemantics(find.bySemanticsLabel('Lesson audio')).value,
        'Audio is stopped.',
      );

      semantics.dispose();
    });

    testWidgets('the drawing pad exposes a labelled surface and reset action',
        (tester) async {
      final semantics = tester.ensureSemantics();
      final dependencies = _testDependencies();
      await _pumpApp(tester, dependencies);
      await _openStoryActivity(tester);
      await _advanceToPractice(tester);

      expect(find.bySemanticsLabel('Drawing area'), findsOneWidget);
      expect(find.text('Drawing area'), findsNothing);

      expect(_buttonFor('Clear drawing'), findsOneWidget);
      expect(_buttonFor('Undo last line'), findsOneWidget);
      final node = tester.getSemantics(find.bySemanticsLabel('Clear drawing'));
      expect(
        node.getSemanticsData().hasAction(SemanticsAction.tap),
        isFalse,
        reason: 'there is nothing to clear until a line is drawn',
      );

      semantics.dispose();
    });

    testWidgets('a round game announces round and score exactly once',
        (tester) async {
      final semantics = tester.ensureSemantics();
      final dependencies = _testDependencies();
      await _pumpApp(tester, dependencies);
      await _openGame(tester, 'Find the Letter');

      const merged = 'Round 1 of 5. Score 0.';
      expect(find.bySemanticsLabel(merged), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('Round')), findsOneWidget);
      expect(find.text('Round 1 of 5'), findsOneWidget);
      expect(
        find.descendant(
          of: find.bySemanticsLabel(merged),
          matching: find.text('Round 1 of 5'),
        ),
        findsOneWidget,
      );

      final target =
          tester.widget<Text>(find.byKey(const Key('game-target'))).data!;
      await _tap(tester, target, key: Key('game-option-$target'));
      await _tap(tester, 'Next round');

      expect(
        find.bySemanticsLabel('Round 2 of 5. Score 1.'),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel(RegExp('Round')), findsOneWidget);

      semantics.dispose();
    });

    testWidgets('class chips stay operable through semantics alone',
        (tester) async {
      final semantics = tester.ensureSemantics();
      final dependencies = _testDependencies();
      await _pumpApp(tester, dependencies);
      await _tap(tester, 'Choose a subject');
      await _tap(tester, 'English');

      expect(find.text('Choose an activity for Class 1.'), findsOneWidget);
      _expectTappable(tester, 'Class 4');
      expect(
        tester
            .getSemantics(find.bySemanticsLabel('Class 1'))
            .flagsCollection
            .isSelected,
        Tristate.isTrue,
      );

      tester.semantics.tap(find.semantics.byLabel('Class 4'));
      await tester.pumpAndSettle();

      expect(find.text('Choose an activity for Class 4.'), findsOneWidget);
      expect(
        tester
            .getSemantics(find.bySemanticsLabel('Class 4'))
            .flagsCollection
            .isSelected,
        Tristate.isTrue,
      );
      expect(
        tester
            .getSemantics(find.bySemanticsLabel('Class 1'))
            .flagsCollection
            .isSelected,
        Tristate.isFalse,
      );

      semantics.dispose();
    });
  });

  group('completion feedback', () {
    testWidgets('finishing a book confirms the save out loud and on screen',
        (tester) async {
      final semantics = tester.ensureSemantics();
      final dependencies = _testDependencies();
      await _pumpApp(tester, dependencies);
      await _openGame(tester, 'Big ABC');

      expect(find.text(kGameSavedMessage), findsNothing);

      await _tap(tester, 'Finish');

      expect(find.text(kGameSavedMessage), findsNWidgets(2));
      expect(find.widgetWithText(FilledButton, 'Finished'), findsOneWidget);
      final inline = find.byKey(const Key('game-saved-confirmation'));
      expect(inline, findsOneWidget);
      final node = tester.getSemantics(inline);
      expect(node.label, kGameSavedMessage);
      expect(node.flagsCollection.isLiveRegion, isTrue);
      expect(
        dependencies.controller.progress.completedActivityIds,
        contains('class-0-subject-little-activity-capitals'),
      );

      semantics.dispose();
    });

    testWidgets('finishing a round game keeps the confirmation on the way home',
        (tester) async {
      final dependencies = _testDependencies();
      await _pumpApp(tester, dependencies);
      await _openGame(tester, 'Find the Letter');

      for (var round = 1; round <= 5; round++) {
        final target =
            tester.widget<Text>(find.byKey(const Key('game-target'))).data!;
        await _tap(tester, target, key: Key('game-option-$target'));
        await _tap(tester, round >= 5 ? 'See my star' : 'Next round');
      }

      expect(find.text('You are a star!'), findsOneWidget);
      await _tap(tester, 'Go home');

      expect(find.text('Continue learning'), findsOneWidget);
      expect(find.text(kGameSavedMessage), findsOneWidget);
    });
  });

  group('wrong answers', () {
    testWidgets('a wrong option is marked by an icon and a semantic value',
        (tester) async {
      final semantics = tester.ensureSemantics();
      final dependencies = _testDependencies();
      await _pumpApp(tester, dependencies);
      await _openGame(tester, 'Match Letters');

      final target =
          tester.widget<Text>(find.byKey(const Key('game-target'))).data!;
      final wrong = _optionText(tester, target);

      expect(find.byIcon(Icons.close_rounded), findsNothing);

      await _tap(tester, wrong, key: Key('game-option-$wrong'));

      final badge = find.byIcon(Icons.close_rounded);
      expect(badge, findsOneWidget);
      expect(find.byType(Icon), findsWidgets);

      final node = tester.getSemantics(
        find.bySemanticsLabel('Letter $wrong. $kGameWrongAnswerMessage'),
      );
      expect(node.value, kGameWrongAnswerMessage);
      expect(node.label, contains('Not this one'));

      final other = _otherOptionText(tester, target, wrong);
      expect(find.bySemanticsLabel('Letter $other'), findsOneWidget);
      expect(
        tester.getSemantics(find.bySemanticsLabel('Letter $other')).value,
        isEmpty,
      );

      semantics.dispose();
    });

    testWidgets('the wrong answer marker survives a large text scale',
        (tester) async {
      await _pumpNarrowApp(tester);
      await _openGame(tester, 'Match Letters');

      await _reveal(tester, find.byKey(const Key('game-target')));
      final target =
          tester.widget<Text>(find.byKey(const Key('game-target'))).data!;
      final wrong = _optionText(tester, target);
      await _tap(tester, wrong, key: Key('game-option-$wrong'));

      final badge = find.byIcon(Icons.close_rounded);
      expect(badge, findsOneWidget);
      expect(tester.getSize(badge).width, greaterThanOrEqualTo(24));
      expect(
        find.bySemanticsLabel('Letter $wrong. $kGameWrongAnswerMessage'),
        findsOneWidget,
      );
    });
  });

  group('wide surfaces and large text', () {
    testWidgets('the app bar grows with the text scale so titles are not cut',
        (tester) async {
      for (final scale in <double>[1.0, 2.0, 3.0, 4.0]) {
        await tester.binding.setSurfaceSize(const Size(360, 900));
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(() async {
          tester.platformDispatcher.clearTextScaleFactorTestValue();
          await tester.binding.setSurfaceSize(null);
        });

        await _pumpApp(tester, _testDependencies());
        await _tap(tester, 'Choose a subject');

        final appBarHeight = tester.getSize(find.byType(AppBar)).height;
        final titles = find.descendant(
          of: find.byType(AppBar),
          matching: find.byType(Text),
        );

        expect(
          appBarHeight,
          greaterThanOrEqualTo(AppTheme.baseToolbarHeight * scale),
          reason: 'scale $scale',
        );
        expect(titles, findsWidgets, reason: 'scale $scale');
        for (var index = 0; index < titles.evaluate().length; index++) {
          expect(
            tester.getSize(titles.at(index)).height,
            lessThanOrEqualTo(appBarHeight),
            reason: 'the app bar title must not be clipped at scale $scale',
          );
        }

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      }
    });

    testWidgets('content is capped and centred on a desktop surface',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      addTearDown(() async {
        await tester.binding.setSurfaceSize(null);
      });

      await _pumpApp(tester, _testDependencies());

      final summary = find.byKey(const Key('home-progress-summary'));
      final summaryRect = tester.getRect(summary);

      expect(summaryRect.width, lessThanOrEqualTo(kMaxContentWidth));
      expect(
        summaryRect.center.dx,
        closeTo(1440 / 2, 1),
        reason: 'the reading column stays centred',
      );
      for (final label in <String>[
        'Continue learning',
        'Choose a subject',
        'Play and learn',
        'Ask your teacher',
      ]) {
        final card = find.ancestor(
          of: find.text(label),
          matching: find.byType(Card),
        );
        expect(
          tester.getSize(card).width,
          lessThanOrEqualTo(kMaxContentWidth),
          reason: label,
        );
      }
    });

    testWidgets('a phone width surface is not narrowed', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() async {
        await tester.binding.setSurfaceSize(null);
      });

      await _pumpApp(tester, _testDependencies());

      expect(
        tester.getSize(find.byKey(const Key('home-progress-summary'))).width,
        390 - 40,
      );
    });

    testWidgets('the action bar never takes over the screen', (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 640));
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(() async {
        tester.platformDispatcher.clearTextScaleFactorTestValue();
        await tester.binding.setSurfaceSize(null);
      });

      await _pumpApp(tester, _testDependencies());
      await _tap(tester, 'Choose a subject');
      await _tap(tester, 'Class 1');
      await _tap(tester, 'English');
      await _tap(tester, 'Class 1 Story');
      await _advanceToReward(tester);

      final barHeight = tester.getSize(find.byType(LearningActionBar)).height;

      expect(barHeight, lessThanOrEqualTo(640 * 0.4));
      expect(
        tester.getSize(find.byType(Scrollable).first).height,
        greaterThan(0),
      );
      for (final label in <String>['Finish', 'Go home', 'Previous step']) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      final undoPoint =
          tester.getRect(find.byType(LearningActionBar)).bottomRight;
      expect(undoPoint.dy, lessThanOrEqualTo(640));
    });

    testWidgets('the drawing pad reports how much has been drawn',
        (tester) async {
      final semantics = tester.ensureSemantics();
      await _pumpApp(tester, _testDependencies());
      await _openStoryActivity(tester);
      await _advanceToPractice(tester);

      SemanticsNode pad() => tester.getSemantics(
            find.bySemanticsLabel('Drawing area'),
          );

      expect(pad().value, 'Nothing drawn yet');
      expect(
        tester
            .getSemantics(find.bySemanticsLabel('Clear drawing'))
            .getSemanticsData()
            .hasAction(SemanticsAction.tap),
        isFalse,
        reason: 'nothing to clear yet',
      );

      await _reveal(tester, find.bySemanticsLabel('Drawing area'));
      expectOnScreen(
        tester,
        find.bySemanticsLabel('Drawing area'),
        reason: 'drawing area',
      );

      await _drawOneLine(tester);

      expect(pad().value, '1 line drawn');

      await _tap(tester, 'Undo last line');
      expect(pad().value, 'Nothing drawn yet');

      await _drawOneLine(tester);
      expect(pad().value, '1 line drawn');

      await _tap(tester, 'Clear drawing');
      expect(pad().value, 'Nothing drawn yet');

      semantics.dispose();
    });
  });

  group('contrast', () {
    test('accent surfaces keep light text readable', () {
      expect(
        _contrastRatio(Colors.white, AppColors.primary),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrastRatio(Colors.white, AppColors.error),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrastRatio(Colors.white, AppColors.success),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrastRatio(Colors.white, AppColors.warning),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('light surfaces keep dark ink readable', () {
      final theme = AppTheme.light();
      for (final surface in <Color>[
        AppColors.surface,
        Colors.white,
        const Color(0xFFFFE0DC),
        const Color(0xFFD8F3EF),
        const Color(0xFFFFE7C2),
        const Color(0xFFE5E0FF),
        const Color(0xFFFFDAD6),
        const Color(0xFFFFF6C3),
        const Color(0xFFFFD7E8),
      ]) {
        expect(
          _contrastRatio(AppColors.ink, surface),
          greaterThanOrEqualTo(4.5),
          reason: 'ink on ${surface.toARGB32().toRadixString(16)}',
        );
      }
      expect(
        _contrastRatio(theme.colorScheme.onSurface, theme.colorScheme.surface),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrastRatio(
          theme.colorScheme.onPrimary,
          theme.colorScheme.primary,
        ),
        greaterThanOrEqualTo(4.5),
      );
    });
  });
}

Finder _buttonFor(String label) => find.ancestor(
      of: find.text(label),
      matching: find.byWidgetPredicate(
        (widget) => widget is ButtonStyleButton,
      ),
    );

Finder _audioButton(String label) =>
    find.widgetWithText(FilledButton, label).first;

Finder _cardFor(String title) => find.ancestor(
      of: find.text(title),
      matching: find.byType(InkWell),
    );

Future<void> _pumpNarrowApp(
  WidgetTester tester, {
  Size surface = _narrowSurface,
  double textScale = _largeTextScale,
}) async {
  await tester.binding.setSurfaceSize(surface);
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(() async {
    tester.platformDispatcher.clearTextScaleFactorTestValue();
    await tester.binding.setSurfaceSize(null);
  });
  await _pumpApp(tester, _testDependencies());
}

Future<void> _pumpApp(WidgetTester tester, AppDependencies dependencies) async {
  await tester.pumpWidget(SchoolLearningApp(dependencies: dependencies));
  await tester.pumpAndSettle();
  await dependencies.controller.initialize();
  await tester.pumpAndSettle();
}

Future<void> _openStoryActivity(WidgetTester tester) async {
  await _tap(tester, 'Choose a subject');
  await _tap(tester, 'English');
  await _tap(tester, 'Class 1 Story');
}

Future<void> _openGame(WidgetTester tester, String title) async {
  await _tap(tester, 'Play and learn');
  await _tap(tester, title);
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

String _otherOptionText(WidgetTester tester, String target, String chosen) {
  final letters = tester
      .widgetList<Text>(find.byType(Text))
      .map((widget) => widget.data ?? '')
      .where((value) => RegExp(r'^[A-Za-z]$').hasMatch(value))
      .where((value) => value.toLowerCase() != target.toLowerCase())
      .where((value) => value != chosen)
      .toSet();
  expect(letters, isNotEmpty, reason: 'a second wrong option is expected');
  return letters.first;
}

Future<void> _advanceToPractice(WidgetTester tester) async {
  await _tap(tester, 'Next step');
  await _tap(tester, 'Show the answer');
  await _tap(tester, 'Next card');
  await _tap(tester, 'Show the answer');
  await _tap(tester, 'Next step');
  await _tap(tester, 'Read');
  await _tap(tester, 'Next question');
  await _tap(tester, 'Write');
  await _tap(tester, 'Next step');
}

Future<void> _drawOneLine(WidgetTester tester) async {
  await tester.ensureVisible(find.byType(DrawingPad));
  await tester.pumpAndSettle();
  final area = tester.getRect(find.byType(DrawingPad));
  final gesture =
      await tester.startGesture(area.topLeft + const Offset(80, 80));
  await tester.pump(const Duration(milliseconds: 60));
  await gesture.moveBy(const Offset(0, -40));
  await tester.pump(const Duration(milliseconds: 30));
  await gesture.moveBy(const Offset(0, -40));
  await tester.pump(const Duration(milliseconds: 30));
  await gesture.up();
  await tester.pumpAndSettle();
}

Future<void> _advanceToReward(WidgetTester tester) async {
  await _advanceToPractice(tester);
  await _tap(tester, 'I finished practicing');
}

Future<void> _tap(WidgetTester tester, String label, {Key? key}) async {
  final finder = key == null ? find.text(label) : find.byKey(key);
  await _reveal(tester, finder);
  await tester.tap(finder, warnIfMissed: false);
  await tester.pumpAndSettle();
}

Future<void> _reveal(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isEmpty) {
    await _tryScrollTo(tester, finder, -120);
  }
  if (finder.evaluate().isEmpty) {
    await _tryScrollTo(tester, finder, 120);
  }
  expect(finder, findsWidgets, reason: 'cannot reveal $finder');
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

Future<void> _tryScrollTo(
  WidgetTester tester,
  Finder finder,
  double delta,
) async {
  try {
    await tester.scrollUntilVisible(
      finder,
      delta,
      scrollable: find.byType(Scrollable).first,
    );
  } on StateError {
    return;
  }
  await tester.pumpAndSettle();
}

Future<void> _runAudio(WidgetTester tester, String label) async {
  await _tap(tester, label);
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 50)),
  );
  await tester.pumpAndSettle();
}

void expectOnScreen(
  WidgetTester tester,
  Finder finder, {
  required String reason,
}) {
  final matches = finder.evaluate();
  expect(matches, isNotEmpty, reason: '$reason is missing');
  final bounds = Rect.fromLTWH(
    0,
    0,
    tester.view.physicalSize.width / tester.view.devicePixelRatio,
    tester.view.physicalSize.height / tester.view.devicePixelRatio,
  );
  for (final match in matches) {
    final rect = tester.getRect(find.byWidget(match.widget));
    expect(
      bounds.contains(rect.center),
      isTrue,
      reason: '$reason is off screen at ${rect.center}',
    );
  }
}

void expectMinimumTarget(
  WidgetTester tester,
  Finder finder, {
  required String reason,
}) {
  expect(finder, findsOneWidget, reason: reason);
  final size = tester.getSize(finder);
  expect(
    size.height,
    greaterThanOrEqualTo(kPrimaryActionHeight),
    reason: '$reason is only ${size.height}dp tall',
  );
  expect(
    size.width,
    greaterThanOrEqualTo(kPrimaryActionHeight),
    reason: '$reason is only ${size.width}dp wide',
  );
}

void _expectTappable(WidgetTester tester, String label) {
  final node = tester.getSemantics(find.bySemanticsLabel(label));
  expect(
    node.getSemanticsData().hasAction(SemanticsAction.tap),
    isTrue,
    reason: '$label must expose a tap action',
  );
}

void _expectDisabled(WidgetTester tester, String label) {
  final node = tester.getSemantics(find.bySemanticsLabel(label));
  expect(
    node.getSemanticsData().hasAction(SemanticsAction.tap),
    isFalse,
    reason: '$label must be disabled',
  );
  expect(node.flagsCollection.isEnabled, Tristate.isFalse);
}

void _expectFitsInCard(
  WidgetTester tester,
  String label, {
  required String reason,
}) {
  final matches = find.text(label);
  expect(matches, findsWidgets, reason: reason);
  for (final match in matches.evaluate()) {
    final paragraph = match.renderObject! as RenderParagraph;
    final plain = paragraph.text.toPlainText();
    final available = paragraph.size.width;
    var offset = 0;
    for (final word in plain.split(' ')) {
      if (word.isEmpty) {
        continue;
      }
      final start = plain.indexOf(word, offset);
      final box = paragraph
          .getBoxesForSelection(
            TextSelection(baseOffset: start, extentOffset: start + word.length),
          )
          .first;
      expect(
        box.right,
        lessThanOrEqualTo(available + 0.5),
        reason: '"$word" in $reason paints ${box.right.toStringAsFixed(1)}dp '
            'inside only ${available.toStringAsFixed(1)}dp',
      );
      offset = start + word.length;
    }
  }
}

void _expectNoChevron(
  WidgetTester tester,
  Finder card, {
  required String reason,
}) {
  expect(
    find.descendant(of: card, matching: find.byIcon(Icons.chevron_right)),
    findsNothing,
    reason: '$reason must drop the chevron when it stacks',
  );
}

void _expectFullWidthText(
  WidgetTester tester,
  Finder text,
  Finder card, {
  required String reason,
}) {
  final paragraph = text.evaluate().single.renderObject! as RenderParagraph;
  final inner = tester.getSize(card).width - _choiceCardPadding * 2;
  expect(
    paragraph.size.width,
    greaterThanOrEqualTo(inner - 1),
    reason: '$reason only receives ${paragraph.size.width}dp of the '
        '${inner.toStringAsFixed(1)}dp card, so the badge is still beside it',
  );
}

double _contrastRatio(Color first, Color second) {
  final a = first.computeLuminance();
  final b = second.computeLuminance();
  final lighter = math.max(a, b);
  final darker = math.min(a, b);
  return (lighter + 0.05) / (darker + 0.05);
}

AppDependencies _testDependencies({
  ProgressPreferences? preferences,
  ProgressStore? progressStore,
  AudioPlayerFactory? audioFactory,
  SpeechEngine? speechEngine,
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
    engine: speechEngine ?? TestSpeechEngine(),
  );
  return AppDependencies.fromParts(
    content: content,
    progress: progress,
    audio: audio,
    speech: speech,
  );
}
