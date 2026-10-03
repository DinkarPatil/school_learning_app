import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:school_learning_app/app/app_controller.dart';
import 'package:school_learning_app/core/audio/audio_service.dart';
import 'package:school_learning_app/core/errors/app_failure.dart';
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
  "classIds": ["class-0", "class-1"],
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
      "flashcards": [
        {"front": "Hello", "back": "A friendly greeting"}
      ],
      "questions": [
        {
          "prompt": "Which word is a greeting?",
          "options": ["Hello", "Chair"],
          "answerIndex": 0,
          "hint": "Greetings are words we say when we meet."
        }
      ],
      "practicePrompt": "Trace and write: Hello",
      "practiceHint": "Say the word before writing it.",
      "audioAsset": "audio/lessons/lesson_english_c1.wav",
      "translations": {
        "hi": {"title": "नमस्ते, मित्र", "story": "अमी सूरज को नमस्ते कहती है।"}
      }
    },
    {
      "id": "class-0-subject-little-activity-numbers",
      "classId": "class-0",
      "subjectId": "little",
      "title": "Numbers 1 to 10",
      "activityType": "number",
      "story": "Count with stars.",
      "flashcards": [
        {"front": "1", "back": "One"}
      ],
      "questions": [
        {
          "prompt": "What comes after one?",
          "options": ["Two", "Ten"],
          "answerIndex": 0,
          "hint": "Count forward."
        }
      ],
      "practicePrompt": "Write one number.",
      "practiceHint": "Start slowly.",
      "audioAsset": "",
      "translations": {
        "hi": {"title": "एक से दस", "story": "सितारों के साथ गिनें।"}
      }
    }
  ]
}
''';

void main() {
  group('AppController', () {
    test('initialize loads content and progress once', () async {
      final bundle = _CatalogBundle();
      final preferences = _MemoryPreferences();
      final content = ContentRepository(bundle: bundle);
      final progress = _CountingProgressStore(preferences: preferences);
      final controller = AppController(
        content: content,
        progress: progress,
        audio: AudioService(playerFactory: _FakePlayerFactory()),
        speech: SpeechService(engine: _FakeSpeechEngine()),
      );

      await controller.initialize();
      await controller.initialize();

      expect(bundle.loadCount, 1);
      expect(progress.loadCalls, 1);
      expect(controller.catalog?.activities, hasLength(2));
      expect(controller.progress.practiceCount, 0);
      expect(controller.failure, isNull);
    });

    test('openSubject and openActivity update the active selection', () async {
      final controller = _controller();

      await controller.initialize();
      var notifications = 0;
      controller.addListener(() => notifications++);

      expect(controller.openSubject('english'), isTrue);
      expect(controller.activeSubjectId, 'english');
      expect(controller.activeActivityId, isNull);

      expect(
        controller.openActivity(
          'class-1-subject-english-activity-story',
        ),
        isTrue,
      );
      expect(controller.activeClassId, 'class-1');
      expect(controller.activeSubjectId, 'english');
      expect(controller.activeActivityId,
          'class-1-subject-english-activity-story');
      expect(notifications, 2);
    });

    test('rapid completion taps are serialized and idempotent', () async {
      final preferences = _MemoryPreferences();
      final store = _RecordingProgressStore(
        preferences: preferences,
        firstWriteStarted: Completer<void>(),
        releaseFirstWrite: Completer<void>(),
      );
      final controller = AppController(
        content: ContentRepository(bundle: _CatalogBundle()),
        progress: store,
        audio: AudioService(playerFactory: _FakePlayerFactory()),
        speech: SpeechService(engine: _FakeSpeechEngine()),
      );
      await controller.initialize();

      final first = controller.completeActivity(
        'class-1-subject-english-activity-story',
      );
      await store.firstWriteStarted!.future;
      final second = controller.completeActivity(
        'class-1-subject-english-activity-story',
      );
      store.releaseFirstWrite!.complete();
      await Future.wait(<Future<void>>[first, second]);

      expect(store.saves, hasLength(1));
      expect(
        store.saves.single.completedActivityIds,
        {'class-1-subject-english-activity-story'},
      );
      expect(controller.progress.completedActivityIds,
          {'class-1-subject-english-activity-story'});
    });

    test('completion exposes a typed save failure without mutating progress',
        () async {
      final controller = AppController(
        content: ContentRepository(bundle: _CatalogBundle()),
        progress: TestFailingSaveProgressStore(),
        audio: AudioService(playerFactory: TestAudioPlayerFactory()),
        speech: SpeechService(engine: TestSpeechEngine()),
      );
      await controller.initialize();

      await expectLater(
        controller.completeActivity('class-1-subject-english-activity-story'),
        throwsA(
          isA<AppFailure>().having(
            (failure) => failure.code,
            'code',
            AppFailureCode.corruptProgress,
          ),
        ),
      );
      expect(controller.progress.completedActivityIds, isEmpty);
    });

    test('recording practice uses a copyWith local increment', () async {
      final preferences = _MemoryPreferences();
      final store = _RecordingProgressStore(preferences: preferences);
      final controller = AppController(
        content: ContentRepository(bundle: _CatalogBundle()),
        progress: store,
        audio: AudioService(playerFactory: _FakePlayerFactory()),
        speech: SpeechService(engine: _FakeSpeechEngine()),
      );
      await controller.initialize();

      await controller.recordPractice(
        'class-1-subject-english-activity-story',
      );
      await controller.recordPractice(
        'class-1-subject-english-activity-story',
      );

      expect(store.saves, hasLength(2));
      expect(store.saves.first.practiceCount, 1);
      expect(store.saves.last.practiceCount, 2);
      expect(controller.progress.practiceCount, 2);
    });

    test('exposes typed initialization failures', () async {
      final content = ContentRepository(bundle: _CatalogBundle('{bad'));
      final controller = AppController(
        content: content,
        progress: ProgressStore(
          profileId: 'test-child',
          preferences: _MemoryPreferences(),
        ),
        audio: AudioService(playerFactory: _FakePlayerFactory()),
        speech: SpeechService(engine: _FakeSpeechEngine()),
      );

      await expectLater(
        controller.initialize(),
        throwsA(
          isA<AppFailure>().having(
            (failure) => failure.code,
            'code',
            AppFailureCode.invalidContent,
          ),
        ),
      );
      expect(controller.failure?.code, AppFailureCode.invalidContent);
    });

    test('exposes corrupt progress as a typed failure', () async {
      final controller = AppController(
        content: ContentRepository(bundle: _CatalogBundle()),
        progress: _FailingProgressStore(),
        audio: AudioService(playerFactory: _FakePlayerFactory()),
        speech: SpeechService(engine: _FakeSpeechEngine()),
      );

      await expectLater(
        controller.initialize(),
        throwsA(
          isA<AppFailure>().having(
            (failure) => failure.code,
            'code',
            AppFailureCode.corruptProgress,
          ),
        ),
      );
      expect(controller.failure?.code, AppFailureCode.corruptProgress);
    });
  });
}

AppController _controller() {
  return AppController(
    content: ContentRepository(bundle: _CatalogBundle()),
    progress: ProgressStore(
      profileId: 'test-child',
      preferences: _MemoryPreferences(),
    ),
    audio: AudioService(playerFactory: _FakePlayerFactory()),
    speech: SpeechService(engine: _FakeSpeechEngine()),
  );
}

class _CatalogBundle extends CachingAssetBundle {
  _CatalogBundle([this.contents = _catalogJson]);

  final String contents;
  int loadCount = 0;

  @override
  Future<ByteData> load(String key) async {
    loadCount++;
    if (key != 'assets/content/catalog.json') {
      throw StateError('Unexpected asset key: $key');
    }
    return ByteData.sublistView(Uint8List.fromList(utf8.encode(contents)));
  }
}

class _MemoryPreferences implements ProgressPreferences {
  final Map<String, String> values = <String, String>{};
  final List<String> reads = <String>[];

  @override
  Future<String?> readString(String key) async {
    reads.add(key);
    return values[key];
  }

  @override
  Future<void> writeString(String key, String value) async {
    values[key] = value;
  }
}

class _CountingProgressStore extends ProgressStore {
  _CountingProgressStore({required ProgressPreferences preferences})
      : super(profileId: 'test-child', preferences: preferences);

  int loadCalls = 0;

  @override
  Future<ProgressSnapshot> load() {
    loadCalls++;
    return super.load();
  }
}

class _RecordingProgressStore extends ProgressStore {
  _RecordingProgressStore({
    required ProgressPreferences preferences,
    this.firstWriteStarted,
    this.releaseFirstWrite,
  }) : super(profileId: 'test-child', preferences: preferences);

  final Completer<void>? firstWriteStarted;
  final Completer<void>? releaseFirstWrite;
  final List<ProgressSnapshot> saves = <ProgressSnapshot>[];

  @override
  Future<void> save(ProgressSnapshot snapshot) async {
    saves.add(snapshot);
    if (saves.length == 1) {
      firstWriteStarted?.complete();
      await releaseFirstWrite?.future;
    }
    await super.save(snapshot);
  }
}

class _FailingProgressStore extends ProgressStore {
  _FailingProgressStore()
      : super(profileId: 'test-child', preferences: _MemoryPreferences());

  @override
  Future<ProgressSnapshot> load() {
    throw const AppFailure.corruptProgress();
  }
}

class _FakePlayerFactory implements AudioPlayerFactory {
  @override
  AudioPlayerAdapter create() => _FakePlayer();
}

class _FakePlayer implements AudioPlayerAdapter {
  final StreamController<Duration> _position =
      StreamController<Duration>.broadcast();
  final StreamController<Duration> _duration =
      StreamController<Duration>.broadcast();
  final StreamController<void> _completion = StreamController<void>.broadcast();

  @override
  Stream<Duration> get onPositionChanged => _position.stream;

  @override
  Stream<Duration> get onDurationChanged => _duration.stream;

  @override
  Stream<void> get onPlayerComplete => _completion.stream;

  @override
  Future<void> playAsset(String path) async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> release() async {}

  @override
  Future<void> dispose() async {
    await _position.close();
    await _duration.close();
    await _completion.close();
  }
}

class _FakeSpeechEngine implements SpeechEngine {
  @override
  Future<SpeechResult> setLanguage(String language) async =>
      const SpeechResult.success();

  @override
  Future<SpeechResult> setSpeechRate(double rate) async =>
      const SpeechResult.success();

  @override
  Future<SpeechResult> setPitch(double pitch) async =>
      const SpeechResult.success();

  @override
  Future<SpeechResult> setVolume(double volume) async =>
      const SpeechResult.success();

  @override
  Future<SpeechResult> awaitSpeakCompletion(bool awaitCompletion) async =>
      const SpeechResult.success();

  @override
  Future<SpeechResult> speak(String text) async => const SpeechResult.success();

  @override
  Future<SpeechResult> stop() async => const SpeechResult.success();
}
