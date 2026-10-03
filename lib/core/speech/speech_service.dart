import 'dart:async';

import 'package:flutter_tts/flutter_tts.dart';
import 'package:school_learning_app/core/errors/app_failure.dart';

enum SpeechResultStatus { success, cancelled, failure }

class SpeechResult {
  const SpeechResult.success()
      : status = SpeechResultStatus.success,
        cause = null,
        explicitlyStopped = false;

  const SpeechResult.cancelled({this.explicitlyStopped = false})
      : status = SpeechResultStatus.cancelled,
        cause = null;

  const SpeechResult.failure(this.cause)
      : status = SpeechResultStatus.failure,
        explicitlyStopped = false;

  final SpeechResultStatus status;
  final Object? cause;
  final bool explicitlyStopped;

  bool get isSuccess => status == SpeechResultStatus.success;
}

class SpeechEngineException implements Exception {
  const SpeechEngineException(this.result);

  final SpeechResult result;

  @override
  String toString() => 'SpeechEngineException(${result.status})';
}

abstract interface class SpeechEngine {
  Future<SpeechResult> setLanguage(String language);

  Future<SpeechResult> setSpeechRate(double rate);

  Future<SpeechResult> setPitch(double pitch);

  Future<SpeechResult> setVolume(double volume);

  Future<SpeechResult> awaitSpeakCompletion(bool awaitCompletion);

  Future<SpeechResult> speak(String text);

  Future<SpeechResult> stop();
}

typedef SpeechEngineAdapter = SpeechEngine;

abstract interface class SpeechEngineFactory {
  SpeechEngine create();
}

class FlutterTtsSpeechEngineFactory implements SpeechEngineFactory {
  const FlutterTtsSpeechEngineFactory();

  @override
  SpeechEngine create() => FlutterTtsSpeechEngine();
}

class FlutterTtsSpeechEngine implements SpeechEngine {
  FlutterTtsSpeechEngine({
    FlutterTts? tts,
    this.completionTimeout = const Duration(seconds: 30),
  }) : _tts = tts ?? FlutterTts();

  final FlutterTts _tts;
  final Duration completionTimeout;
  Completer<SpeechResult>? _activeOperation;
  bool _awaitCompletion = true;
  bool _stopRequested = false;

  @override
  Future<SpeechResult> setLanguage(String language) {
    return _statusCall(() => _tts.setLanguage(language));
  }

  @override
  Future<SpeechResult> setSpeechRate(double rate) {
    return _statusCall(() => _tts.setSpeechRate(rate));
  }

  @override
  Future<SpeechResult> setPitch(double pitch) {
    return _statusCall(() => _tts.setPitch(pitch));
  }

  @override
  Future<SpeechResult> setVolume(double volume) {
    return _statusCall(() => _tts.setVolume(volume));
  }

  @override
  Future<SpeechResult> awaitSpeakCompletion(bool awaitCompletion) async {
    final result = await _statusCall(
      () => _tts.awaitSpeakCompletion(awaitCompletion),
    );
    if (result.isSuccess) {
      _awaitCompletion = awaitCompletion;
    }
    return result;
  }

  @override
  Future<SpeechResult> speak(String text) async {
    final previous = _activeOperation;
    if (previous != null && !previous.isCompleted) {
      return SpeechResult.failure(StateError('Speech is already active.'));
    }

    final operation = Completer<SpeechResult>();
    _activeOperation = operation;
    _stopRequested = false;
    _tts.setCompletionHandler(
      () => _complete(operation, const SpeechResult.success()),
    );
    _tts.setCancelHandler(
      () => _complete(
        operation,
        SpeechResult.cancelled(explicitlyStopped: _stopRequested),
      ),
    );
    _tts.setErrorHandler(
      (message) => _complete(
        operation,
        SpeechResult.failure(
          message ?? StateError('TTS reported an asynchronous speech error.'),
        ),
      ),
    );

    Future<dynamic>? pluginFuture;
    try {
      pluginFuture = _tts.speak(text);
    } on Object catch (error) {
      _complete(operation, SpeechResult.failure(error));
    }
    if (pluginFuture != null) {
      unawaited(
        pluginFuture.then<void>(
          (value) {
            final result = _statusResult(value);
            if (!_awaitCompletion || !result.isSuccess) {
              _complete(operation, result);
            }
          },
          onError: (Object error, StackTrace __) {
            _complete(operation, SpeechResult.failure(error));
          },
        ),
      );
    }

    try {
      return await operation.future.timeout(
        completionTimeout,
        onTimeout: () {
          final failure = SpeechResult.failure(
            StateError('Speech did not complete before the timeout.'),
          );
          _complete(operation, failure);
          return failure;
        },
      );
    } finally {
      if (identical(_activeOperation, operation)) {
        _activeOperation = null;
        _stopRequested = false;
        _tts.setCompletionHandler(_ignoreCompletion);
        _tts.setCancelHandler(_ignoreCancel);
        _tts.setErrorHandler(_ignoreError);
      }
    }
  }

  @override
  Future<SpeechResult> stop() async {
    final operation = _activeOperation;
    _stopRequested = true;
    final result = await _statusCall(() => _tts.stop());
    if (!result.isSuccess) {
      if (operation != null && !operation.isCompleted) {
        _stopRequested = false;
      }
      return result;
    }
    if (operation != null) {
      _complete(
        operation,
        const SpeechResult.cancelled(explicitlyStopped: true),
      );
    }
    _stopRequested = false;
    return result;
  }

  Future<SpeechResult> _statusCall(
    Future<dynamic> Function() operation,
  ) async {
    try {
      return _statusResult(await operation());
    } on Object catch (error) {
      return SpeechResult.failure(error);
    }
  }

  static SpeechResult _statusResult(Object? value) {
    if (_statusSucceeded(value)) {
      return const SpeechResult.success();
    }
    return SpeechResult.failure(
      StateError('TTS operation returned an unsuccessful status.'),
    );
  }

  static bool _statusSucceeded(Object? value) {
    if (value == null) {
      return true;
    }
    if (value is bool) {
      return value;
    }
    if (value is num) {
      return value == 1;
    }
    final normalized = value.toString().toLowerCase();
    return normalized == '1' || normalized == 'true';
  }

  static void _complete(
    Completer<SpeechResult> operation,
    SpeechResult result,
  ) {
    if (!operation.isCompleted) {
      operation.complete(result);
    }
  }

  static void _ignoreCompletion() {}

  static void _ignoreCancel() {}

  static void _ignoreError(Object? _) {}
}

class SpeechService {
  SpeechService({
    SpeechEngineFactory? engineFactory,
    SpeechEngine? engine,
  })  : _engineFactory = engineFactory ?? const FlutterTtsSpeechEngineFactory(),
        _providedEngine = engine;

  static const double speechRate = 0.32;
  static const double pitch = 1.15;
  static const double volume = 1.0;
  static const Map<String, String> languageMap = <String, String>{
    'en': 'en-US',
    'en-us': 'en-US',
    'en-US': 'en-US',
    'hi': 'hi-IN',
    'hi-in': 'hi-IN',
    'hi-IN': 'hi-IN',
    'mr': 'mr-IN',
    'mr-in': 'mr-IN',
    'mr-IN': 'mr-IN',
  };

  final SpeechEngineFactory _engineFactory;
  final SpeechEngine? _providedEngine;
  SpeechEngine? _engine;
  bool _configured = false;
  _SpeechOperation? _activeOperation;
  Future<void>? _stopInFlight;
  Future<void> _operationTail = Future<void>.value();

  static String mapLanguage(String language) {
    final normalized = language.trim().replaceAll('_', '-');
    return languageMap[normalized] ??
        languageMap[normalized.toLowerCase()] ??
        'en-US';
  }

  static String languageFor(String language) => mapLanguage(language);

  Future<void> speak(
    String text, {
    String language = 'en-US',
  }) {
    final operation = _SpeechOperation(
      primaryText: text,
      language: mapLanguage(language),
    );
    final interrupt = _interruptActiveOperation();
    unawaited(
      interrupt.catchError((Object error, StackTrace stackTrace) {
        _failOperation(operation, error, stackTrace);
      }),
    );
    final queued = _enqueue(() async {
      if (operation.completion.isCompleted) {
        return;
      }
      try {
        await interrupt;
      } on Object catch (error, stackTrace) {
        _failOperation(operation, error, stackTrace);
        return;
      }
      if (operation.completion.isCompleted) {
        return;
      }
      await _runOperation(
        operation,
        () => _runSingleAttempt(operation),
      );
    });
    unawaited(queued.catchError((Object _, StackTrace __) {}));
    return operation.completion.future;
  }

  Future<void> speakOrFallback(
    String primaryText,
    String fallbackText, {
    String language = 'en-US',
  }) {
    final operation = _SpeechOperation(
      primaryText: primaryText,
      fallbackText: fallbackText,
      language: mapLanguage(language),
    );
    final interrupt = _interruptActiveOperation();
    unawaited(
      interrupt.catchError((Object error, StackTrace stackTrace) {
        _failOperation(operation, error, stackTrace);
      }),
    );
    final queued = _enqueue(() async {
      if (operation.completion.isCompleted) {
        return;
      }
      try {
        await interrupt;
      } on Object catch (error, stackTrace) {
        _failOperation(operation, error, stackTrace);
        return;
      }
      if (operation.completion.isCompleted) {
        return;
      }
      await _runOperation(
        operation,
        () => _runFallbackAttempts(operation),
      );
    });
    unawaited(queued.catchError((Object _, StackTrace __) {}));
    return operation.completion.future;
  }

  void _failOperation(
    _SpeechOperation operation,
    Object error,
    StackTrace stackTrace,
  ) {
    if (error is AppFailure && error.code == AppFailureCode.audioUnavailable) {
      operation.fail(error);
    } else {
      operation.fail(_speechFailure(error, stackTrace: stackTrace));
    }
  }

  Future<void> stop() {
    final active = _activeOperation;
    if (active == null || active.completion.isCompleted) {
      return Future<void>.value();
    }
    final inFlight = _stopInFlight;
    if (inFlight != null) {
      return inFlight;
    }

    late final Future<void> publicFuture;
    final stopFuture = _stopActive(active);
    publicFuture = stopFuture.whenComplete(() {
      if (identical(_stopInFlight, publicFuture)) {
        _stopInFlight = null;
      }
    });
    _stopInFlight = publicFuture;
    return publicFuture;
  }

  Future<void> _interruptActiveOperation() {
    final active = _activeOperation;
    if (active == null || active.completion.isCompleted) {
      return Future<void>.value();
    }
    if (active.stopInProgress) {
      return _stopInFlight ?? Future<void>.value();
    }
    return stop();
  }

  Future<void> _stopActive(_SpeechOperation operation) async {
    final engine = _engine;
    if (engine == null) {
      operation.cancel();
      return;
    }

    operation.beginStop();
    SpeechResult result;
    try {
      result = await engine.stop();
    } on Object catch (error, stackTrace) {
      operation.failStop(error);
      _throwSpeechFailure(error, stackTrace);
    }
    if (!result.isSuccess) {
      operation.failStop(
        result.cause ?? StateError('Speech stop was unsuccessful.'),
      );
      _throwSpeechFailure(
        result.cause ?? StateError('Speech stop was unsuccessful.'),
        StackTrace.current,
      );
    }
    operation.cancel();
  }

  Future<void> _runOperation(
    _SpeechOperation operation,
    Future<SpeechResult> Function() action,
  ) async {
    _activeOperation = operation;
    try {
      final execution = _safeResult(action());
      final cancellation = operation.cancellation.future.then<SpeechResult>(
        (_) => const SpeechResult.cancelled(explicitlyStopped: true),
      );
      final result = await Future.any<SpeechResult>([
        execution,
        cancellation,
      ]);
      if (operation.stopInProgress) {
        final stopResult = await operation.stopCompletion.future;
        if (stopResult.isSuccess) {
          operation.complete();
          return;
        }
      }
      if (operation.cancellation.isCompleted) {
        operation.complete();
      } else if (result.status == SpeechResultStatus.cancelled &&
          result.explicitlyStopped) {
        operation.complete();
      } else if (result.isSuccess) {
        operation.complete();
      } else {
        operation.fail(_speechFailure(result.cause));
      }
    } on Object catch (error, stackTrace) {
      if (operation.stopInProgress) {
        final stopResult = await operation.stopCompletion.future;
        if (stopResult.isSuccess) {
          operation.complete();
          return;
        }
      }
      if (operation.cancellation.isCompleted) {
        operation.complete();
      } else {
        operation.fail(_speechFailure(error, stackTrace: stackTrace));
      }
    } finally {
      if (identical(_activeOperation, operation)) {
        _activeOperation = null;
      }
    }
  }

  Future<bool> _stopSucceededIfNeeded(_SpeechOperation operation) async {
    if (operation.cancellation.isCompleted) {
      return true;
    }
    if (!operation.stopInProgress) {
      return false;
    }
    final result = await operation.stopCompletion.future;
    return result.isSuccess;
  }

  Future<SpeechResult> _runFallbackAttempts(_SpeechOperation operation) async {
    try {
      final primary = await _runSingleAttempt(operation);
      if (await _stopSucceededIfNeeded(operation)) {
        return const SpeechResult.cancelled(explicitlyStopped: true);
      }
      if (primary.status == SpeechResultStatus.cancelled &&
          primary.explicitlyStopped) {
        return primary;
      }
      _ensureSuccess(primary);
      return const SpeechResult.success();
    } on Object {
      if (await _stopSucceededIfNeeded(operation)) {
        return const SpeechResult.cancelled(explicitlyStopped: true);
      }
      try {
        final fallback = await _runSingleAttempt(
          operation,
          text: operation.fallbackText!,
        );
        if (await _stopSucceededIfNeeded(operation)) {
          return const SpeechResult.cancelled(explicitlyStopped: true);
        }
        if (fallback.status == SpeechResultStatus.cancelled &&
            fallback.explicitlyStopped) {
          return fallback;
        }
        _ensureSuccess(fallback);
        return const SpeechResult.success();
      } on Object catch (error) {
        if (await _stopSucceededIfNeeded(operation)) {
          return const SpeechResult.cancelled(explicitlyStopped: true);
        }
        return SpeechResult.failure(error);
      }
    }
  }

  Future<SpeechResult> _runSingleAttempt(
    _SpeechOperation operation, {
    String? text,
  }) async {
    if (await _stopSucceededIfNeeded(operation)) {
      return const SpeechResult.cancelled(explicitlyStopped: true);
    }
    final engine = await _resolveEngine();
    if (await _stopSucceededIfNeeded(operation)) {
      return const SpeechResult.cancelled(explicitlyStopped: true);
    }

    if (!_configured) {
      _ensureSuccess(await engine.setSpeechRate(speechRate));
      _ensureSuccess(await engine.setPitch(pitch));
      _ensureSuccess(await engine.setVolume(volume));
      _ensureSuccess(await engine.awaitSpeakCompletion(true));
      _configured = true;
    }
    if (await _stopSucceededIfNeeded(operation)) {
      return const SpeechResult.cancelled(explicitlyStopped: true);
    }
    _ensureSuccess(await engine.setLanguage(operation.language));
    if (await _stopSucceededIfNeeded(operation)) {
      return const SpeechResult.cancelled(explicitlyStopped: true);
    }
    return engine.speak(text ?? operation.primaryText);
  }

  Future<SpeechEngine> _resolveEngine() {
    final current = _engine;
    if (current != null) {
      return Future<SpeechEngine>.value(current);
    }
    try {
      final engine = _providedEngine ?? _engineFactory.create();
      _engine = engine;
      return Future<SpeechEngine>.value(engine);
    } on Object catch (error, stackTrace) {
      return Future<SpeechEngine>.error(error, stackTrace);
    }
  }

  void _ensureSuccess(SpeechResult result) {
    if (!result.isSuccess) {
      throw SpeechEngineException(result);
    }
  }

  Future<SpeechResult> _safeResult(Future<SpeechResult> future) async {
    try {
      return await future;
    } on Object catch (error) {
      return SpeechResult.failure(error);
    }
  }

  AppFailure _speechFailure(
    Object? error, {
    StackTrace? stackTrace,
  }) {
    if (error is AppFailure && error.code == AppFailureCode.audioUnavailable) {
      return error;
    }
    return AppFailure.audioUnavailable(cause: error);
  }

  Never _throwSpeechFailure(Object error, StackTrace stackTrace) {
    Error.throwWithStackTrace(
        _speechFailure(error, stackTrace: stackTrace), stackTrace);
  }

  Future<void> _enqueue(Future<void> Function() action) {
    final result = _operationTail.then<void>((_) => action());
    _operationTail = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {},
    );
    return result;
  }
}

class _SpeechOperation {
  _SpeechOperation({
    required this.primaryText,
    required this.language,
    this.fallbackText,
  });

  final String primaryText;
  final String? fallbackText;
  final String language;
  final Completer<void> completion = Completer<void>();
  final Completer<void> cancellation = Completer<void>();
  final Completer<SpeechResult> stopCompletion = Completer<SpeechResult>();
  bool stopInProgress = false;

  void beginStop() {
    stopInProgress = true;
  }

  void cancel() {
    stopInProgress = false;
    if (!cancellation.isCompleted) {
      cancellation.complete();
    }
    if (!stopCompletion.isCompleted) {
      stopCompletion.complete(const SpeechResult.success());
    }
  }

  void failStop(Object? cause) {
    stopInProgress = false;
    if (!stopCompletion.isCompleted) {
      stopCompletion.complete(SpeechResult.failure(cause));
    }
  }

  void complete() {
    if (!completion.isCompleted) {
      completion.complete();
    }
  }

  void fail(AppFailure failure) {
    if (!completion.isCompleted) {
      completion.completeError(failure);
    }
  }
}
