import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:school_learning_app/main.dart';
import 'package:school_learning_app/core/audio/audio_service.dart';
import 'package:school_learning_app/core/errors/app_failure.dart';
import 'package:school_learning_app/core/speech/speech_service.dart';
import 'package:school_learning_app/data/content/content_repository.dart';
import 'package:school_learning_app/data/progress/progress_store.dart';

import 'support/fakes.dart';

void main() {
  testWidgets('loads the all-kids home screen', (tester) async {
    final preferences = TestProgressPreferences();
    final dependencies = AppDependencies.fromParts(
      content: ContentRepository(bundle: _CatalogBundle()),
      progress: ProgressStore(
        profileId: 'smoke-child',
        preferences: preferences,
      ),
      audio: AudioService(playerFactory: TestAudioPlayerFactory()),
      speech: SpeechService(engine: TestSpeechEngine()),
    );

    await tester.runAsync(() => dependencies.controller.initialize());
    await tester.pumpWidget(SchoolLearningApp(dependencies: dependencies));
    await tester.pumpAndSettle();

    expect(dependencies.controller.catalog, isNotNull);
    expect(find.text('Continue learning'), findsOneWidget);
    expect(find.text('Choose a subject'), findsOneWidget);
    expect(find.text('Play and learn'), findsOneWidget);
    expect(find.text('Ask your teacher'), findsOneWidget);
  });

  testWidgets('the shipped catalog drives the subject picker', (tester) async {
    final dependencies = AppDependencies.fromParts(
      content: ContentRepository(bundle: _CatalogBundle()),
      progress: ProgressStore(
        profileId: 'smoke-child',
        preferences: TestProgressPreferences(),
      ),
      audio: AudioService(playerFactory: TestAudioPlayerFactory()),
      speech: SpeechService(engine: TestSpeechEngine()),
    );

    await tester.runAsync(() => dependencies.controller.initialize());
    await tester.pumpWidget(SchoolLearningApp(dependencies: dependencies));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose a subject'));
    await tester.pumpAndSettle();

    final catalog = dependencies.controller.catalog;
    expect(catalog, isNotNull);
    for (final classId in catalog!.classIds) {
      final match = RegExp(r'^class-(\d+)$').firstMatch(classId);
      if (match == null || int.parse(match.group(1)!) < 1) {
        continue;
      }
      expect(
        find.text('Class ${match.group(1)}'),
        findsOneWidget,
        reason: classId,
      );
    }
    expect(find.text('Choose a class'), findsOneWidget);
  });

  testWidgets('a content failure shows a retry state and recovers',
      (tester) async {
    final bundle = _RepairableBundle();
    final dependencies = AppDependencies.fromParts(
      content: ContentRepository(bundle: bundle),
      progress: ProgressStore(
        profileId: 'smoke-child',
        preferences: TestProgressPreferences(),
      ),
      audio: AudioService(playerFactory: TestAudioPlayerFactory()),
      speech: SpeechService(engine: TestSpeechEngine()),
    );

    await tester.runAsync(() async {
      try {
        await dependencies.controller.initialize();
      } on AppFailure {
        return;
      }
    });
    await tester.pumpWidget(SchoolLearningApp(dependencies: dependencies));
    await tester.pumpAndSettle();

    expect(dependencies.controller.catalog, isNull);
    expect(dependencies.controller.failure, isNotNull);
    expect(dependencies.controller.startupState, AppStartupState.failed);
    expect(find.text('We cannot open the learning shelf yet'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    expect(find.text('Learning content is getting ready.'), findsNothing);
    expect(find.text('Continue learning'), findsNothing);

    bundle.repaired = true;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(dependencies.controller.catalog, isNotNull);
    expect(dependencies.controller.failure, isNull);
    expect(dependencies.controller.startupState, AppStartupState.ready);
    expect(find.text('Learning content is getting ready.'), findsNothing);
    expect(find.text('Continue learning'), findsOneWidget);
    expect(find.text('Choose a subject'), findsOneWidget);
    expect(find.text('Play and learn'), findsOneWidget);
    expect(find.text('Ask your teacher'), findsOneWidget);
  });
}

File _shippedCatalogFile() {
  final candidates = <File>[
    File('assets/content/catalog.json'),
    File(
      '${Directory.current.parent.path}/assets/content/catalog.json',
    ),
  ];
  for (final candidate in candidates) {
    if (candidate.existsSync()) {
      return candidate;
    }
  }
  throw StateError(
    'assets/content/catalog.json was not found from ${Directory.current.path}.',
  );
}

class _CatalogBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async {
    if (key != 'assets/content/catalog.json') {
      throw StateError('Unexpected asset key: $key');
    }
    final source = _shippedCatalogFile().readAsStringSync();
    return ByteData.sublistView(Uint8List.fromList(utf8.encode(source)));
  }
}

class _RepairableBundle extends CachingAssetBundle {
  bool repaired = false;

  @override
  Future<ByteData> load(String key) async {
    if (key != 'assets/content/catalog.json') {
      throw StateError('Unexpected asset key: $key');
    }
    if (!repaired) {
      throw StateError('The learning shelf is still being unpacked.');
    }
    return ByteData.sublistView(
      Uint8List.fromList(utf8.encode(_repairedCatalogJson)),
    );
  }
}

const String _repairedCatalogJson = '''
{
  "version": 1,
  "sourceLanguage": "en",
  "translationLanguages": ["hi"],
  "classIds": ["class-1"],
  "subjects": [
    {"id": "english", "title": "English", "subtitle": "Stories and words"}
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
      "questions": [
        {
          "prompt": "Which word is a greeting?",
          "options": ["Hello", "Chair"],
          "answerIndex": 0,
          "hint": "Say hello."
        }
      ],
      "practicePrompt": "Trace and write: Hello",
      "practiceHint": "Say it slowly.",
      "audioAsset": "",
      "translations": {
        "hi": {"title": "नमस्ते, मित्र", "story": "अमी सूरज को नमस्ते कहती है।"}
      }
    }
  ]
}
''';
