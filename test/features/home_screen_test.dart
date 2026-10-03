import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:school_learning_app/app/app.dart';
import 'package:school_learning_app/core/audio/audio_service.dart';
import 'package:school_learning_app/core/speech/speech_service.dart';
import 'package:school_learning_app/data/content/content_repository.dart';
import 'package:school_learning_app/data/progress/progress_models.dart';
import 'package:school_learning_app/data/progress/progress_store.dart';

import '../support/fakes.dart';

const _catalogJson = '''
{
  "version": 1,
  "sourceLanguage": "en",
  "translationLanguages": ["hi"],
  "classIds": ["class-0", "class-1", "class-2"],
  "subjects": [
    {"id": "english", "title": "English", "subtitle": "Stories and words"},
    {"id": "little", "title": "Little Stars", "subtitle": "Gentle games"}
  ],
  "activities": [
    {
      "id": "class-1-subject-english-activity-story",
      "classId": "class-1",
      "subjectId": "english",
      "title": "Hello, Friend",
      "activityType": "story",
      "story": "Ami says hello to the sun.",
      "flashcards": [{"front": "Hello", "back": "A greeting"}],
      "questions": [{"prompt": "Which word is a greeting?", "options": ["Hello", "Chair"], "answerIndex": 0, "hint": "Say hello."}],
      "practicePrompt": "Trace and write: Hello",
      "practiceHint": "Say it slowly.",
      "audioAsset": "audio/lessons/lesson_english_c1.wav",
      "translations": {"hi": {"title": "नमस्ते, मित्र", "story": "अमी सूरज को नमस्ते कहती है।"}}
    },
    {
      "id": "class-2-subject-english-activity-story",
      "classId": "class-2",
      "subjectId": "english",
      "title": "Class 2 Story",
      "activityType": "story",
      "story": "Class 2 reads and explores together.",
      "flashcards": [{"front": "Read", "back": "Look at words"}],
      "questions": [{"prompt": "Which word means read?", "options": ["Read", "Run"], "answerIndex": 0, "hint": "Reading uses words."}],
      "practicePrompt": "Write one word.",
      "practiceHint": "Read it aloud.",
      "audioAsset": "audio/lessons/lesson_english_c2.wav",
      "translations": {"hi": {"title": "कक्षा 2 कहानी", "story": "कक्षा 2 मिलकर पढ़ते हैं।"}}
    },
    {
      "id": "class-0-subject-little-activity-numbers",
      "classId": "class-0",
      "subjectId": "little",
      "title": "Numbers 1 to 10",
      "activityType": "number",
      "story": "Count with stars.",
      "flashcards": [{"front": "1", "back": "One"}],
      "questions": [{"prompt": "What comes after one?", "options": ["Two", "Ten"], "answerIndex": 0, "hint": "Count forward."}],
      "practicePrompt": "Write one number.",
      "practiceHint": "Start slowly.",
      "audioAsset": "",
      "translations": {"hi": {"title": "एक से दस", "story": "सितारों के साथ गिनें।"}}
    }
  ]
}
''';

void main() {
  testWidgets('home offers learning choices for every child', (tester) async {
    final dependencies = _dependencies();
    await tester.pumpWidget(SchoolLearningApp(dependencies: dependencies));
    await tester.pumpAndSettle();
    await dependencies.controller.initialize();

    expect(find.text('Continue learning'), findsOneWidget);
    expect(find.text('Choose a subject'), findsOneWidget);
    expect(find.text('Play and learn'), findsOneWidget);
    expect(find.text('Ask your teacher'), findsOneWidget);
    expect(find.text('Choose a class'), findsNothing);
    expect(find.text('Little Stars'), findsNothing);
  });

  testWidgets('subject and activity screens navigate predictably',
      (tester) async {
    final dependencies = _dependencies();
    await tester.pumpWidget(SchoolLearningApp(dependencies: dependencies));
    await tester.pumpAndSettle();
    await dependencies.controller.initialize();
    expect(dependencies.controller.catalog, isNotNull,
        reason: dependencies.controller.failure?.toString());

    await tester.tap(find.text('Choose a subject'));
    await tester.pumpAndSettle();
    expect(find.text('Pick a subject'), findsOneWidget);
    expect(find.text('Choose a class'), findsOneWidget);
    expect(find.text('Class 1'), findsOneWidget);
    expect(find.text('Class 2'), findsOneWidget);

    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    expect(find.text('Choose an activity for Class 1.'), findsOneWidget);
    expect(find.text('Hello, Friend'), findsOneWidget);
    expect(find.text('Class 2 Story'), findsNothing);

    await tester.tap(find.text('Class 2'));
    await tester.pumpAndSettle();
    expect(find.text('Choose an activity for Class 2.'), findsOneWidget);
    expect(find.text('Class 2 Story'), findsOneWidget);
    expect(find.text('Hello, Friend'), findsNothing);

    await tester.tap(find.text('Class 1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hello, Friend'));
    await tester.pumpAndSettle();
    expect(find.text('Hello, Friend'), findsOneWidget);
    expect(find.text('Step 1 of 5'), findsOneWidget);
    expect(find.text('Next step'), findsOneWidget);

    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    expect(find.text('Continue learning'), findsOneWidget);
  });

  testWidgets('generic subject route clears a previous games selection',
      (tester) async {
    final dependencies = _dependencies();
    await tester.pumpWidget(SchoolLearningApp(dependencies: dependencies));
    await tester.pumpAndSettle();
    await dependencies.controller.initialize();

    await tester.tap(find.text('Play and learn'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Numbers 1 to 10'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose a subject'));
    await tester.pumpAndSettle();

    expect(find.text('Little Stars'), findsNothing);
    expect(find.text('English'), findsOneWidget);
  });

  testWidgets('continue learning resumes a stored activity', (tester) async {
    final preferences = _MemoryPreferences();
    preferences.values['learning_progress_v2:test-child'] =
        ProgressSnapshot.empty()
            .copyWith(lastActivityId: 'class-1-subject-english-activity-story')
            .encode();

    await tester.pumpWidget(
      SchoolLearningApp(
        dependencies: _dependencies(preferences: preferences),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Continue learning'));
    await tester.pumpAndSettle();

    expect(find.text('Hello, Friend'), findsOneWidget);
  });

  testWidgets('home shows a visual star summary of saved progress',
      (tester) async {
    final semantics = tester.ensureSemantics();
    final dependencies = _dependencies();
    await tester.pumpWidget(SchoolLearningApp(dependencies: dependencies));
    await tester.pumpAndSettle();

    final total = dependencies.controller.catalog!.activities.length;

    expect(find.byKey(const Key('home-progress-summary')), findsOneWidget);
    expect(find.text('Your stars'), findsOneWidget);
    expect(find.text('0 of $total finished'), findsOneWidget);
    expect(find.byIcon(Icons.star_rounded), findsNothing);
    expect(
      find.byIcon(Icons.star_border_rounded),
      findsNWidgets(kProgressSummaryStarCount),
    );
    expect(
      find.bySemanticsLabel(
        'Your stars. 0 of $total activities finished. 0 stars earned.',
      ),
      findsOneWidget,
    );

    await dependencies.controller.completeActivity(
      'class-1-subject-english-activity-story',
    );
    await tester.pumpAndSettle();

    expect(find.text('1 of $total finished'), findsOneWidget);
    expect(find.byIcon(Icons.star_rounded), findsOneWidget);
    expect(
      find.bySemanticsLabel(
        'Your stars. 1 of $total activities finished. 1 star earned.',
      ),
      findsOneWidget,
    );

    semantics.dispose();
  });

  testWidgets('home choices expose one merged semantic label', (tester) async {
    await tester.pumpWidget(SchoolLearningApp(dependencies: _dependencies()));
    await tester.pumpAndSettle();

    expect(
      find.bySemanticsLabel('Continue learning. Start your first activity.'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(
          'Ask your teacher. Get a helpful hint when you need one.'),
      findsOneWidget,
    );
  });

  testWidgets('primary escape control meets the minimum touch target',
      (tester) async {
    await tester.pumpWidget(SchoolLearningApp(dependencies: _dependencies()));
    await tester.pumpAndSettle();

    final lockButton = find.byTooltip('Grown-ups only');
    expect(tester.getSize(lockButton).width, greaterThanOrEqualTo(64));
    expect(tester.getSize(lockButton).height, greaterThanOrEqualTo(64));

    await tester.tap(find.text('Choose a subject'));
    await tester.pumpAndSettle();

    final homeButton = find.widgetWithText(TextButton, 'Home');
    expect(tester.getSize(homeButton).width, greaterThanOrEqualTo(64));
    expect(tester.getSize(homeButton).height, greaterThanOrEqualTo(64));
    final backButton = find.byTooltip('Back');
    expect(tester.getSize(backButton).width, greaterThanOrEqualTo(64));
    expect(tester.getSize(backButton).height, greaterThanOrEqualTo(64));
  });

  testWidgets('teacher and parent controls show safe notices', (tester) async {
    await tester.pumpWidget(SchoolLearningApp(dependencies: _dependencies()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ask your teacher'));
    await tester.pump();
    expect(find.text('Your teacher is coming next.'), findsOneWidget);

    await tester.tap(find.byTooltip('Grown-ups only'));
    await tester.pumpAndSettle();
    expect(find.text('Grown-ups only'), findsOneWidget);
  });
}

AppDependencies _dependencies({
  ProgressPreferences? preferences,
  ProgressStore? progressStore,
}) {
  final content = ContentRepository(bundle: _CatalogBundle());
  final progress = progressStore ??
      ProgressStore(
        profileId: 'test-child',
        preferences: preferences ?? _MemoryPreferences(),
      );
  final audio = AudioService(playerFactory: TestAudioPlayerFactory());
  final speech = SpeechService(engine: TestSpeechEngine());
  final controller = AppController(
    content: content,
    progress: progress,
    audio: audio,
    speech: speech,
  );
  return AppDependencies(
    controller: controller,
    content: content,
    progress: progress,
    audio: audio,
    speech: speech,
  );
}

class _CatalogBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async {
    if (key != 'assets/content/catalog.json') {
      throw StateError('Unexpected asset key: $key');
    }
    return ByteData.sublistView(Uint8List.fromList(utf8.encode(_catalogJson)));
  }
}

class _MemoryPreferences implements ProgressPreferences {
  final Map<String, String> values = <String, String>{
    'learning_progress_v2_migration_complete': 'true',
  };

  @override
  Future<String?> readString(String key) async => values[key];

  @override
  Future<void> writeString(String key, String value) async {
    values[key] = value;
  }
}
