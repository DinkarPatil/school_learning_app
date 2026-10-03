import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:school_learning_app/core/errors/app_failure.dart';

enum AudioPlaybackState { idle, loading, playing }

abstract interface class AudioPlayerAdapter {
  Stream<Duration> get onPositionChanged;

  Stream<Duration> get onDurationChanged;

  Stream<void> get onPlayerComplete;

  Future<void> playAsset(String path);

  Future<void> stop();

  Future<void> release();

  Future<void> dispose();
}

typedef AudioPlayerClient = AudioPlayerAdapter;

abstract interface class AudioPlayerFactory {
  AudioPlayerAdapter create();
}

class AudioplayersAudioPlayerFactory implements AudioPlayerFactory {
  const AudioplayersAudioPlayerFactory();

  @override
  AudioPlayerAdapter create() => AudioplayersAudioPlayerAdapter(AudioPlayer());
}

class AudioplayersAudioPlayerAdapter implements AudioPlayerAdapter {
  AudioplayersAudioPlayerAdapter(this._player);

  final AudioPlayer _player;

  @override
  Stream<Duration> get onPositionChanged => _player.onPositionChanged;

  @override
  Stream<Duration> get onDurationChanged => _player.onDurationChanged;

  @override
  Stream<void> get onPlayerComplete => _player.onPlayerComplete;

  @override
  Future<void> playAsset(String path) async {
    await _player.setReleaseMode(ReleaseMode.stop);
    await _player.play(AssetSource(path));
  }

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> release() => _player.release();

  @override
  Future<void> dispose() => _player.dispose();
}

class AudioService {
  AudioService({
    AudioPlayerFactory? playerFactory,
    AudioPlayerAdapter? player,
  }) : _playerFactory = playerFactory ??
            (player == null
                ? const AudioplayersAudioPlayerFactory()
                : _SinglePlayerFactory(player));

  final AudioPlayerFactory _playerFactory;
  final StreamController<AudioPlaybackState> _stateController =
      StreamController<AudioPlaybackState>.broadcast();
  final StreamController<Duration> _positionController =
      StreamController<Duration>.broadcast();
  final StreamController<Duration> _durationController =
      StreamController<Duration>.broadcast();
  final StreamController<void> _completionController =
      StreamController<void>.broadcast();

  AudioPlaybackState _state = AudioPlaybackState.idle;
  AudioPlayerAdapter? _player;
  _AudioPlaybackAttempt? _activeAttempt;
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<Duration>? _durationSubscription;
  StreamSubscription<void>? _completionSubscription;
  Future<void> _operationTail = Future<void>.value();
  bool _disposed = false;

  AudioPlaybackState get state => _state;

  Stream<AudioPlaybackState> get stateChanges => _stateController.stream;

  Stream<AudioPlaybackState> get onStateChanged => stateChanges;

  Stream<Duration> get onPositionChanged => _positionController.stream;

  Stream<Duration> get onDurationChanged => _durationController.stream;

  Stream<Duration> get positionChanges => onPositionChanged;

  Stream<Duration> get durationChanges => onDurationChanged;

  Stream<void> get onPlayerComplete => _completionController.stream;

  Stream<void> get completion => onPlayerComplete;

  Future<void> playAsset(String path) {
    return _enqueue(() => _playAsset(path));
  }

  Future<void> stop() {
    _setState(AudioPlaybackState.idle);
    return _enqueue(_stopInternal);
  }

  Future<void> dispose() {
    if (_disposed) {
      return Future<void>.value();
    }
    _disposed = true;
    return _enqueue(() async {
      await _stopInternal();
      await _stateController.close();
      await _positionController.close();
      await _durationController.close();
      await _completionController.close();
    });
  }

  Future<void> _playAsset(String path) async {
    if (_disposed) {
      _setState(AudioPlaybackState.idle);
      throw const AppFailure.audioUnavailable();
    }
    _setState(AudioPlaybackState.idle);
    try {
      await _disposeCurrentPlayer(rethrowErrors: true);
      if (path.trim().isEmpty) {
        throw const FormatException('Audio asset path must not be blank.');
      }
      _setState(AudioPlaybackState.loading);
      final player = _playerFactory.create();
      final attempt = _AudioPlaybackAttempt(player);
      _player = player;
      _activeAttempt = attempt;
      _subscribe(player, attempt);
      if (attempt.failureCompletion.isCompleted) {
        await attempt.failureCompletion.future;
      }
      await Future.any<void>([
        player.playAsset(path),
        attempt.failureCompletion.future,
      ]);
      if (attempt.failureValue != null) {
        Error.throwWithStackTrace(
          attempt.failureValue!,
          StackTrace.current,
        );
      }
      if (identical(_player, player) &&
          identical(_activeAttempt, attempt) &&
          _state == AudioPlaybackState.loading) {
        _setState(AudioPlaybackState.playing);
      }
    } on Object catch (error, stackTrace) {
      _setState(AudioPlaybackState.idle);
      await _disposeCurrentPlayer();
      _throwAudioFailure(error, stackTrace);
    }
  }

  void _subscribe(
    AudioPlayerAdapter player,
    _AudioPlaybackAttempt attempt,
  ) {
    _positionSubscription = player.onPositionChanged.listen(
      (position) {
        if (!_positionController.isClosed) {
          _positionController.add(position);
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        _handleStreamFailure(attempt, error, stackTrace);
      },
    );
    _durationSubscription = player.onDurationChanged.listen(
      (duration) {
        if (!_durationController.isClosed) {
          _durationController.add(duration);
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        _handleStreamFailure(attempt, error, stackTrace);
      },
    );
    _completionSubscription = player.onPlayerComplete.listen(
      (_) {
        if (!identical(_player, player) ||
            !identical(_activeAttempt, attempt) ||
            attempt.completed) {
          return;
        }
        attempt.completed = true;
        _setState(AudioPlaybackState.idle);
        if (!_completionController.isClosed) {
          _completionController.add(null);
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        _handleStreamFailure(attempt, error, stackTrace);
      },
    );
  }

  void _handleStreamFailure(
    _AudioPlaybackAttempt attempt,
    Object error,
    StackTrace stackTrace,
  ) {
    if (!identical(_player, attempt.player) ||
        !identical(_activeAttempt, attempt) ||
        attempt.completed) {
      return;
    }
    _setState(AudioPlaybackState.idle);
    attempt.fail(error, stackTrace);
    scheduleMicrotask(() {
      if (identical(_player, attempt.player) &&
          identical(_activeAttempt, attempt)) {
        unawaited(_disposeCurrentPlayer());
      }
    });
  }

  Future<void> _stopInternal() async {
    _setState(AudioPlaybackState.idle);
    await _disposeCurrentPlayer();
  }

  Future<void> _disposeCurrentPlayer({bool rethrowErrors = false}) async {
    final player = _player;
    _player = null;
    _activeAttempt = null;

    final positionSubscription = _positionSubscription;
    final durationSubscription = _durationSubscription;
    final completionSubscription = _completionSubscription;
    _positionSubscription = null;
    _durationSubscription = null;
    _completionSubscription = null;

    Object? firstError;
    Future<void> cancel(StreamSubscription<dynamic>? subscription) async {
      if (subscription == null) {
        return;
      }
      try {
        await subscription.cancel();
      } on Object catch (error) {
        firstError ??= error;
      }
    }

    await cancel(positionSubscription);
    await cancel(durationSubscription);
    await cancel(completionSubscription);

    if (player != null) {
      try {
        await player.stop();
      } on Object catch (error) {
        firstError ??= error;
      }
      try {
        await player.release();
      } on Object catch (error) {
        firstError ??= error;
      }
      try {
        await player.dispose();
      } on Object catch (error) {
        firstError ??= error;
      }
    }

    if (rethrowErrors && firstError != null) {
      Error.throwWithStackTrace(firstError!, StackTrace.current);
    }
  }

  Future<void> _enqueue(Future<void> Function() action) {
    final result = _operationTail.then<void>((_) => action());
    _operationTail = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {},
    );
    return result;
  }

  void _setState(AudioPlaybackState next) {
    if (_state == next) {
      return;
    }
    _state = next;
    if (!_stateController.isClosed) {
      _stateController.add(next);
    }
  }

  Never _throwAudioFailure(Object error, StackTrace stackTrace) {
    if (error is AppFailure && error.code == AppFailureCode.audioUnavailable) {
      Error.throwWithStackTrace(error, stackTrace);
    }
    Error.throwWithStackTrace(
      AppFailure.audioUnavailable(cause: error),
      stackTrace,
    );
  }
}

class _AudioPlaybackAttempt {
  _AudioPlaybackAttempt(this.player);

  final AudioPlayerAdapter player;
  final Completer<void> failureCompletion = Completer<void>();
  AppFailure? failureValue;
  bool completed = false;

  void fail(Object error, StackTrace stackTrace) {
    if (failureCompletion.isCompleted) {
      return;
    }
    final failure = AppFailure.audioUnavailable(cause: error);
    failureValue = failure;
    failureCompletion.completeError(failure, stackTrace);
  }
}

class _SinglePlayerFactory implements AudioPlayerFactory {
  _SinglePlayerFactory(this._player);

  final AudioPlayerAdapter _player;
  bool _created = false;

  @override
  AudioPlayerAdapter create() {
    if (_created) {
      throw StateError('The injected player has already been used.');
    }
    _created = true;
    return _player;
  }
}
