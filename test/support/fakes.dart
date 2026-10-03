import 'dart:async';

import 'package:flutter/services.dart';
import 'package:school_learning_app/core/audio/audio_service.dart';
import 'package:school_learning_app/core/errors/app_failure.dart';
import 'package:school_learning_app/core/haptics/haptics_service.dart';
import 'package:school_learning_app/core/speech/speech_service.dart';
import 'package:school_learning_app/data/progress/progress_models.dart';
import 'package:school_learning_app/data/progress/progress_store.dart';

class TestHapticFeedbackAdapter implements HapticFeedbackAdapter {
  final List<HapticCue> cues = <HapticCue>[];

  int countOf(HapticCue cue) =>
      cues.where((recorded) => recorded == cue).length;

  void clear() => cues.clear();

  @override
  Future<void> perform(HapticCue cue) async {
    cues.add(cue);
  }
}

class TestFailingHapticFeedbackAdapter implements HapticFeedbackAdapter {
  @override
  Future<void> perform(HapticCue cue) async {
    throw MissingPluginException('No haptics in tests.');
  }
}

class TestProgressPreferences implements ProgressPreferences {
  TestProgressPreferences({Map<String, String>? initialValues})
      : values = <String, String>{
          'learning_progress_v2_migration_complete': 'true',
          ...?initialValues,
        };

  final Map<String, String> values;

  @override
  Future<String?> readString(String key) async => values[key];

  @override
  Future<void> writeString(String key, String value) async {
    values[key] = value;
  }
}

class TestFailingSaveProgressStore extends ProgressStore {
  TestFailingSaveProgressStore()
      : super(
          profileId: 'test-child',
          preferences: TestProgressPreferences(),
        );

  @override
  Future<void> save(ProgressSnapshot snapshot) async {
    throw const AppFailure.corruptProgress();
  }
}

class TestRecordingProgressStore extends ProgressStore {
  TestRecordingProgressStore()
      : super(
          profileId: 'test-child',
          preferences: TestProgressPreferences(),
        );

  final List<ProgressSnapshot> saved = <ProgressSnapshot>[];
  int failuresRemaining = 0;
  Completer<void>? gate;

  @override
  Future<void> save(ProgressSnapshot snapshot) async {
    if (failuresRemaining > 0) {
      failuresRemaining--;
      throw const AppFailure.corruptProgress();
    }
    final pending = gate;
    if (pending != null) {
      await pending.future;
    }
    saved.add(snapshot);
  }
}

class TestAudioPlayerFactory implements AudioPlayerFactory {
  final List<String> playedPaths = <String>[];

  @override
  AudioPlayerAdapter create() => TestAudioPlayer(playedPaths: playedPaths);
}

class TestFailingAudioPlayerFactory implements AudioPlayerFactory {
  final List<String> attemptedPaths = <String>[];

  @override
  AudioPlayerAdapter create() => TestFailingAudioPlayer(
        attemptedPaths: attemptedPaths,
      );
}

class TestAudioPlayer implements AudioPlayerAdapter {
  TestAudioPlayer({List<String>? playedPaths})
      : playedPaths = playedPaths ?? <String>[];

  final List<String> playedPaths;
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
  Future<void> playAsset(String path) async {
    playedPaths.add(path);
  }

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

class TestFailingAudioPlayer implements AudioPlayerAdapter {
  TestFailingAudioPlayer({required this.attemptedPaths});

  final List<String> attemptedPaths;
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
  Future<void> playAsset(String path) async {
    attemptedPaths.add(path);
    throw StateError('asset $path is missing');
  }

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

class RecordingSpeechEngine implements SpeechEngine {
  final List<String> spokenTexts = <String>[];
  final List<String> languages = <String>[];

  @override
  Future<SpeechResult> setLanguage(String language) async {
    languages.add(language);
    return const SpeechResult.success();
  }

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
  Future<SpeechResult> speak(String text) async {
    spokenTexts.add(text);
    return const SpeechResult.success();
  }

  @override
  Future<SpeechResult> stop() async => const SpeechResult.success();
}

class TestSpeechEngine implements SpeechEngine {
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
