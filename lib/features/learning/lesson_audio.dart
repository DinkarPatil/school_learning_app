import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:school_learning_app/core/audio/audio_service.dart';
import 'package:school_learning_app/core/speech/speech_service.dart';

enum LessonAudioPhase { idle, loading, playing, spokenFallback }

class LessonAudioController extends ChangeNotifier {
  LessonAudioController({
    required AudioService audio,
    required SpeechService speech,
  })  : _audio = audio,
        _speech = speech {
    _audioStateSubscription = _audio.stateChanges.listen(_handleAudioState);
    _completionSubscription = _audio.onPlayerComplete.listen((_) {
      _setPhase(LessonAudioPhase.idle);
    });
  }

  final AudioService _audio;
  final SpeechService _speech;

  StreamSubscription<AudioPlaybackState>? _audioStateSubscription;
  StreamSubscription<void>? _completionSubscription;
  LessonAudioPhase _phase = LessonAudioPhase.idle;
  bool _assetFailed = false;
  int _request = 0;
  bool _disposed = false;

  LessonAudioPhase get phase => _phase;

  bool get isBusy =>
      _phase == LessonAudioPhase.loading || _phase == LessonAudioPhase.playing;

  bool get assetFailed => _assetFailed;

  String get statusLabel => switch (_phase) {
        LessonAudioPhase.idle => _assetFailed
            ? 'Audio is not available right now. The words are on screen.'
            : 'Audio is stopped.',
        LessonAudioPhase.loading => 'Audio is getting ready.',
        LessonAudioPhase.playing => 'Audio is playing.',
        LessonAudioPhase.spokenFallback =>
          'Audio is not available right now. Reading the words aloud.',
      };

  Future<void> play({
    required String audioAsset,
    required String speechText,
    String language = 'en-US',
  }) async {
    final request = ++_request;
    _assetFailed = false;
    _setPhase(LessonAudioPhase.loading);
    final asset = audioAsset.trim();
    if (asset.isNotEmpty) {
      try {
        await _audio.playAsset(asset);
        if (_isStale(request)) {
          return;
        }
        _setPhase(LessonAudioPhase.playing);
        return;
      } on Object {
        if (_isStale(request)) {
          return;
        }
        _assetFailed = true;
        _setPhase(LessonAudioPhase.idle);
      }
    }
    await _speak(request, speechText, language);
  }

  Future<void> speak(String text, {String language = 'en-US'}) async {
    final request = ++_request;
    _assetFailed = false;
    await _speak(request, text, language);
  }

  Future<void> stop() async {
    _request++;
    _setPhase(LessonAudioPhase.idle);
    await _swallow(_speech.stop());
    await _swallow(_audio.stop());
  }

  Future<void> _speak(int request, String text, String language) async {
    final spoken = text.trim();
    if (spoken.isEmpty) {
      if (!_isStale(request)) {
        _setPhase(LessonAudioPhase.idle);
      }
      return;
    }
    if (!_isStale(request)) {
      _setPhase(LessonAudioPhase.spokenFallback);
    }
    await _swallow(_speech.speak(spoken, language: language));
    if (_isStale(request)) {
      return;
    }
    _setPhase(LessonAudioPhase.idle);
  }

  void _handleAudioState(AudioPlaybackState state) {
    if (state == AudioPlaybackState.idle &&
        _phase == LessonAudioPhase.playing) {
      _setPhase(LessonAudioPhase.idle);
    }
  }

  bool _isStale(int request) => _disposed || request != _request;

  void _setPhase(LessonAudioPhase phase) {
    if (_disposed || _phase == phase) {
      return;
    }
    _phase = phase;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_completionSubscription?.cancel());
    unawaited(_audioStateSubscription?.cancel());
    _completionSubscription = null;
    _audioStateSubscription = null;
    super.dispose();
  }
}

Future<void> _swallow(Future<void> work) async {
  try {
    await work;
  } on Object {
    return;
  }
}
