import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:school_learning_app/core/audio/audio_service.dart';
import 'package:school_learning_app/core/errors/app_failure.dart';
import 'package:school_learning_app/core/speech/speech_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AudioService', () {
    test('starts idle and stop is safe without a player', () async {
      final service = AudioService(playerFactory: _FakePlayerFactory());

      expect(service.state, AudioPlaybackState.idle);
      await service.stop();
      await service.stop();

      expect(service.state, AudioPlaybackState.idle);
    });

    test('plays an asset and returns to idle on completion', () async {
      final factory = _FakePlayerFactory();
      final service = AudioService(playerFactory: factory);
      final states = <AudioPlaybackState>[];
      final completions = <void>[];
      final stateSubscription = service.stateChanges.listen(states.add);
      final completionSubscription =
          service.onPlayerComplete.listen(completions.add);

      await service.playAsset('audio/lessons/story.wav');
      await _flush();

      final player = factory.players.single;
      expect(player.playedPaths, ['audio/lessons/story.wav']);
      expect(service.state, AudioPlaybackState.playing);
      expect(states, contains(AudioPlaybackState.loading));
      expect(states, contains(AudioPlaybackState.playing));

      player.complete();
      await _flush();

      expect(service.state, AudioPlaybackState.idle);
      expect(completions, hasLength(1));

      await stateSubscription.cancel();
      await completionSubscription.cancel();
    });

    test('failed playback leaves the service stopped', () async {
      final factory = _FakePlayerFactory(failOnPlay: true);
      final service = AudioService(playerFactory: factory);

      await expectLater(
        service.playAsset('audio/missing.wav'),
        throwsA(_audioFailure),
      );
      expect(service.state, AudioPlaybackState.idle);
      expect(factory.players.single.isDisposed, isTrue);
    });

    test('releases the previous player before replacing it', () async {
      final factory = _FakePlayerFactory();
      final service = AudioService(playerFactory: factory);

      await service.playAsset('audio/first.wav');
      await service.playAsset('audio/second.wav');

      expect(factory.players, hasLength(2));
      expect(factory.players.first.isDisposed, isTrue);
      expect(factory.players.first.positionCanceled, isTrue);
      expect(factory.players.first.durationCanceled, isTrue);
      expect(factory.players.first.completionCanceled, isTrue);
      expect(factory.players.last.playedPaths, ['audio/second.wav']);
      expect(service.state, AudioPlaybackState.playing);
    });

    final streamFailureTests = <String, void Function(_FakePlayer)>{
      'position': (player) => player.emitPositionError(),
      'duration': (player) => player.emitDurationError(),
      'completion': (player) => player.emitCompletionError(),
    };
    for (final streamFailure in streamFailureTests.entries) {
      test('${streamFailure.key} stream failure rejects a pending play',
          () async {
        final factory = _FakePlayerFactory(holdPlay: true);
        final service = AudioService(playerFactory: factory);
        final playFuture = service.playAsset('audio/race.wav');

        await _flush();
        final player = factory.players.single;
        streamFailure.value(player);

        await expectLater(
          playFuture.timeout(const Duration(milliseconds: 500)),
          throwsA(_audioFailure),
        );
        expect(service.state, AudioPlaybackState.idle);

        player.finishPlay();
        await _flush();
      });
    }

    test('play after disposal returns a typed audio failure', () async {
      final service = AudioService(playerFactory: _FakePlayerFactory());

      await service.dispose();
      await expectLater(
        service.playAsset('audio/after-dispose.wav'),
        throwsA(_audioFailure),
      );
      expect(service.state, AudioPlaybackState.idle);
    });

    test('stop is idempotent and releases the active player', () async {
      final factory = _FakePlayerFactory();
      final service = AudioService(playerFactory: factory);

      await service.playAsset('audio/story.wav');
      final player = factory.players.single;
      await service.stop();
      await service.stop();

      expect(service.state, AudioPlaybackState.idle);
      expect(player.stopCalls, 1);
      expect(player.releaseCalls, 1);
      expect(player.disposeCalls, 1);
    });
  });

  group('SpeechService', () {
    test('configures speech and maps supported language codes', () async {
      final engine = _FakeSpeechEngine();
      final service = SpeechService(engine: engine);

      await service.speak('Hello', language: 'hi');
      await service.speak('नमस्ते', language: 'mr-IN');
      await service.speak('Welcome', language: 'en-US');

      expect(engine.languages, ['hi-IN', 'mr-IN', 'en-US']);
      expect(engine.speechRates, [0.32]);
      expect(engine.pitches, [1.15]);
      expect(engine.volumes, [1.0]);
      expect(engine.awaitCompletionValues, [true]);
      expect(engine.spokenTexts, ['Hello', 'नमस्ते', 'Welcome']);
    });

    test('uses fallback after an unsuccessful status result', () async {
      final engine = _FakeSpeechEngine(
        results: <SpeechResult>[
          SpeechResult.failure(StateError('speech was rejected')),
          const SpeechResult.success(),
        ],
      );
      final service = SpeechService(engine: engine);

      await service.speakOrFallback('primary lesson', 'fallback lesson');

      expect(engine.spokenTexts, ['primary lesson', 'fallback lesson']);
    });

    test('asynchronous speech error settles with a typed failure', () async {
      final engine = _FakeSpeechEngine(pendingSpeech: true);
      final service = SpeechService(engine: engine);
      final speakFuture = service.speak('primary lesson');

      await engine.started.future;
      engine.emitError();

      await expectLater(
        speakFuture.timeout(const Duration(milliseconds: 500)),
        throwsA(_speechFailure),
      );
    });

    test('asynchronous cancellation uses fallback when not explicitly stopped',
        () async {
      final engine = _FakeSpeechEngine(pendingSpeech: true);
      final service = SpeechService(engine: engine);
      final speakFuture =
          service.speakOrFallback('primary lesson', 'fallback lesson');

      await engine.started.future;
      engine.emitCancellation();

      await speakFuture.timeout(const Duration(milliseconds: 500));
      expect(engine.spokenTexts, ['primary lesson', 'fallback lesson']);
    });

    test('in-flight stop settles speech without starting fallback', () async {
      final engine = _FakeSpeechEngine(pendingSpeech: true);
      final service = SpeechService(engine: engine);
      final speakFuture =
          service.speakOrFallback('primary lesson', 'fallback lesson');

      await engine.started.future;
      await service.stop().timeout(const Duration(milliseconds: 500));
      await speakFuture.timeout(const Duration(milliseconds: 500));

      expect(engine.spokenTexts, ['primary lesson']);
    });

    test('explicit stop wins a simultaneous speech failure result', () async {
      final engine = _FakeSpeechEngine(
        pendingSpeech: true,
        stopWithFailureResult: true,
        stopDelay: const Duration(milliseconds: 20),
      );
      final service = SpeechService(engine: engine);
      final speakFuture = service.speak('primary lesson');

      await engine.started.future;
      await service.stop();
      await speakFuture;

      expect(engine.spokenTexts, ['primary lesson']);
    });

    test('a failed stop returns a typed failure and leaves speech retryable',
        () async {
      final engine = _FakeSpeechEngine(
        pendingSpeech: true,
        failOnStop: true,
      );
      final service = SpeechService(engine: engine);
      final speakFuture = service.speak('primary lesson');

      await engine.started.future;
      await expectLater(
        service.stop().timeout(const Duration(milliseconds: 500)),
        throwsA(_speechFailure),
      );

      var speechSettled = false;
      unawaited(
        speakFuture.then<void>(
          (_) => speechSettled = true,
          onError: (Object _, StackTrace __) => speechSettled = true,
        ),
      );
      await _flush();
      expect(speechSettled, isFalse);

      engine.failOnStop = false;
      await service.stop();
      await speakFuture;
      expect(speechSettled, isTrue);
    });

    test('a failed stop does not settle a racing speech operation cleanly',
        () async {
      final engine = _FakeSpeechEngine(
        pendingSpeech: true,
        failOnStop: true,
        completePendingOnFailedStop: true,
      );
      final service = SpeechService(engine: engine);
      final speakFuture = service.speak('primary lesson');

      await engine.started.future;
      await expectLater(
        service.stop().timeout(const Duration(milliseconds: 500)),
        throwsA(_speechFailure),
      );

      var speechSucceeded = false;
      Object? speechError;
      unawaited(
        speakFuture.then<void>(
          (_) => speechSucceeded = true,
          onError: (Object error, StackTrace __) => speechError = error,
        ),
      );
      await _flush();
      expect(speechSucceeded, isFalse);
      if (speechError != null) {
        expect(speechError, isA<AppFailure>());
        return;
      }

      engine.failOnStop = false;
      await service.stop();
      await speakFuture;
    });

    test('a failed interrupt surfaces typed failure to the next speech',
        () async {
      final engine = _FakeSpeechEngine(
        pendingSpeech: true,
        failOnStop: true,
      );
      final service = SpeechService(engine: engine);
      final firstSpeech = service.speak('first lesson');

      await engine.started.future;
      final secondSpeech = service.speak('second lesson');

      await expectLater(
        secondSpeech.timeout(const Duration(milliseconds: 500)),
        throwsA(_speechFailure),
      );
      expect(engine.spokenTexts, ['first lesson']);

      engine.failOnStop = false;
      await service.stop();
      await firstSpeech;
    });

    test('does not use fallback when primary speech succeeds', () async {
      final engine = _FakeSpeechEngine();
      final service = SpeechService(engine: engine);

      await service.speakOrFallback('primary lesson', 'fallback lesson');

      expect(engine.spokenTexts, ['primary lesson']);
    });

    test('stop is idempotent when speech was never started', () async {
      final engine = _FakeSpeechEngine();
      final service = SpeechService(engine: engine);

      await service.stop();
      await service.stop();

      expect(engine.stopCalls, 0);
    });

    test('stop does not repeat a completed speech stop', () async {
      final engine = _FakeSpeechEngine();
      final service = SpeechService(engine: engine);

      await service.speak('Hello');
      final stopCallsAfterSpeech = engine.stopCalls;
      await service.stop();
      await service.stop();

      expect(engine.stopCalls, stopCallsAfterSpeech);
    });
  });

  group('FlutterTtsSpeechEngine', () {
    test('converts an unsuccessful speak status into a failure result',
        () async {
      final flutterTts = _FakeFlutterTts(immediateStatus: 0);
      final engine = FlutterTtsSpeechEngine(tts: flutterTts);

      final result = await engine.speak('lesson');

      expect(result.status, SpeechResultStatus.failure);
    });

    test('settles an asynchronous error event', () async {
      final flutterTts = _FakeFlutterTts();
      final engine = FlutterTtsSpeechEngine(tts: flutterTts);
      final speakFuture = engine.speak('lesson');

      await flutterTts.started.future;
      flutterTts.emitError();

      final result =
          await speakFuture.timeout(const Duration(milliseconds: 500));
      expect(result.status, SpeechResultStatus.failure);
    });

    test('settles an asynchronous cancellation event', () async {
      final flutterTts = _FakeFlutterTts();
      final engine = FlutterTtsSpeechEngine(tts: flutterTts);
      final speakFuture = engine.speak('lesson');

      await flutterTts.started.future;
      flutterTts.emitCancellation();

      final result =
          await speakFuture.timeout(const Duration(milliseconds: 500));
      expect(result.status, SpeechResultStatus.cancelled);
      expect(result.explicitlyStopped, isFalse);
    });

    test('marks an explicit stop cancellation cleanly', () async {
      final flutterTts = _FakeFlutterTts();
      final engine = FlutterTtsSpeechEngine(tts: flutterTts);
      final speakFuture = engine.speak('lesson');

      await flutterTts.started.future;
      await engine.stop();
      final result =
          await speakFuture.timeout(const Duration(milliseconds: 500));

      expect(result.status, SpeechResultStatus.cancelled);
      expect(result.explicitlyStopped, isTrue);
    });
  });
}

Future<void> _flush() => Future<void>.delayed(Duration.zero);

final Matcher _audioFailure = isA<AppFailure>().having(
  (failure) => failure.code,
  'code',
  AppFailureCode.audioUnavailable,
);

final Matcher _speechFailure = isA<AppFailure>().having(
  (failure) => failure.code,
  'code',
  AppFailureCode.audioUnavailable,
);

class _FakeFlutterTts extends FlutterTts {
  _FakeFlutterTts({this.immediateStatus});

  final int? immediateStatus;
  final Completer<void> started = Completer<void>();
  final Completer<dynamic> _speakCompletion = Completer<dynamic>();
  int stopCalls = 0;

  @override
  Future<dynamic> speak(String text, {bool focus = false}) {
    if (!started.isCompleted) {
      started.complete();
    }
    if (immediateStatus != null) {
      return Future<dynamic>.value(immediateStatus);
    }
    return _speakCompletion.future;
  }

  @override
  Future<dynamic> stop() {
    stopCalls += 1;
    cancelHandler?.call();
    return Future<dynamic>.value(1);
  }

  void emitError() {
    errorHandler?.call('asynchronous plugin error');
  }

  void emitCancellation() {
    cancelHandler?.call();
  }
}

class _FakePlayerFactory implements AudioPlayerFactory {
  _FakePlayerFactory({this.failOnPlay = false, this.holdPlay = false});

  final bool failOnPlay;
  final bool holdPlay;
  final List<_FakePlayer> players = <_FakePlayer>[];

  @override
  AudioPlayerAdapter create() {
    final player = _FakePlayer(
      failOnPlay: failOnPlay,
      holdPlay: holdPlay,
    );
    players.add(player);
    return player;
  }
}

class _FakePlayer implements AudioPlayerAdapter {
  _FakePlayer({required this.failOnPlay, required this.holdPlay}) {
    _position = StreamController<Duration>.broadcast(
      onCancel: () {
        positionCanceled = true;
      },
    );
    _duration = StreamController<Duration>.broadcast(
      onCancel: () {
        durationCanceled = true;
      },
    );
    _complete = StreamController<void>.broadcast(
      onCancel: () {
        completionCanceled = true;
      },
    );
  }

  final bool failOnPlay;
  final bool holdPlay;
  late final StreamController<Duration> _position;
  late final StreamController<Duration> _duration;
  late final StreamController<void> _complete;
  final Completer<void> _playGate = Completer<void>();
  final List<String> playedPaths = <String>[];
  int stopCalls = 0;
  int releaseCalls = 0;
  int disposeCalls = 0;
  bool positionCanceled = false;
  bool durationCanceled = false;
  bool completionCanceled = false;
  bool isDisposed = false;

  @override
  Stream<Duration> get onPositionChanged => _position.stream;

  @override
  Stream<Duration> get onDurationChanged => _duration.stream;

  @override
  Stream<void> get onPlayerComplete => _complete.stream;

  @override
  Future<void> playAsset(String path) async {
    if (failOnPlay) {
      throw StateError('asset $path is missing');
    }
    if (holdPlay) {
      await _playGate.future;
    }
    playedPaths.add(path);
  }

  @override
  Future<void> stop() async {
    stopCalls += 1;
  }

  @override
  Future<void> release() async {
    releaseCalls += 1;
  }

  @override
  Future<void> dispose() async {
    disposeCalls += 1;
    isDisposed = true;
  }

  void complete() {
    _complete.add(null);
  }

  void emitPositionError() {
    _position.addError(StateError('position stream failed'));
  }

  void emitDurationError() {
    _duration.addError(StateError('duration stream failed'));
  }

  void emitCompletionError() {
    _complete.addError(StateError('completion stream failed'));
  }

  void finishPlay() {
    if (!_playGate.isCompleted) {
      _playGate.complete();
    }
  }
}

class _FakeSpeechEngine implements SpeechEngine {
  _FakeSpeechEngine({
    this.results = const <SpeechResult>[],
    this.pendingSpeech = false,
    this.failOnStop = false,
    this.stopWithFailureResult = false,
    this.stopDelay = Duration.zero,
    this.completePendingOnFailedStop = false,
  });

  final List<SpeechResult> results;
  final bool pendingSpeech;
  final bool stopWithFailureResult;
  final Duration stopDelay;
  final bool completePendingOnFailedStop;
  final Completer<void> started = Completer<void>();
  final List<String> languages = <String>[];
  final List<double> speechRates = <double>[];
  final List<double> pitches = <double>[];
  final List<double> volumes = <double>[];
  final List<bool> awaitCompletionValues = <bool>[];
  final List<String> spokenTexts = <String>[];
  Completer<SpeechResult>? _pending;
  int _resultIndex = 0;
  bool failOnStop;
  int stopCalls = 0;

  @override
  Future<SpeechResult> setLanguage(String language) async {
    languages.add(language);
    return const SpeechResult.success();
  }

  @override
  Future<SpeechResult> setSpeechRate(double rate) async {
    speechRates.add(rate);
    return const SpeechResult.success();
  }

  @override
  Future<SpeechResult> setPitch(double pitch) async {
    pitches.add(pitch);
    return const SpeechResult.success();
  }

  @override
  Future<SpeechResult> setVolume(double volume) async {
    volumes.add(volume);
    return const SpeechResult.success();
  }

  @override
  Future<SpeechResult> awaitSpeakCompletion(bool awaitCompletion) async {
    awaitCompletionValues.add(awaitCompletion);
    return const SpeechResult.success();
  }

  @override
  Future<SpeechResult> speak(String text) {
    spokenTexts.add(text);
    if (!started.isCompleted) {
      started.complete();
    }
    if (_resultIndex < results.length) {
      return Future<SpeechResult>.value(results[_resultIndex++]);
    }
    if (pendingSpeech && spokenTexts.length == 1) {
      _pending = Completer<SpeechResult>();
      return _pending!.future;
    }
    return Future<SpeechResult>.value(const SpeechResult.success());
  }

  @override
  Future<SpeechResult> stop() async {
    stopCalls += 1;
    final pending = _pending;
    if (pending != null &&
        !pending.isCompleted &&
        completePendingOnFailedStop) {
      pending
          .complete(SpeechResult.failure(StateError('plugin stopped speech')));
    }
    if (failOnStop) {
      return SpeechResult.failure(StateError('stop was rejected'));
    }
    if (pending != null && !pending.isCompleted) {
      pending.complete(
        stopWithFailureResult
            ? SpeechResult.failure(StateError('plugin stopped speech'))
            : const SpeechResult.cancelled(explicitlyStopped: true),
      );
    }
    if (stopDelay > Duration.zero) {
      await Future<void>.delayed(stopDelay);
    }
    return const SpeechResult.success();
  }

  void emitError() {
    _completePending(
      SpeechResult.failure(StateError('asynchronous speech failure')),
    );
  }

  void emitCancellation() {
    _completePending(const SpeechResult.cancelled());
  }

  void _completePending(SpeechResult result) {
    final pending = _pending;
    if (pending != null && !pending.isCompleted) {
      pending.complete(result);
    }
  }
}
