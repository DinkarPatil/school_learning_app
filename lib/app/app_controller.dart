import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:school_learning_app/core/audio/audio_service.dart';
import 'package:school_learning_app/core/errors/app_failure.dart';
import 'package:school_learning_app/core/haptics/haptics_service.dart';
import 'package:school_learning_app/core/speech/speech_service.dart';
import 'package:school_learning_app/data/content/content_models.dart';
import 'package:school_learning_app/data/content/content_repository.dart';
import 'package:school_learning_app/data/progress/progress_models.dart';
import 'package:school_learning_app/data/progress/progress_store.dart';

enum AppStartupState { loading, ready, failed }

class AppController extends ChangeNotifier {
  AppController({
    required ContentRepository content,
    required ProgressStore progress,
    AudioService? audio,
    SpeechService? speech,
    HapticsService? haptics,
    DateTime Function()? clock,
  })  : _content = content,
        _progressStore = progress,
        _audio = audio ?? AudioService(),
        _speech = speech ?? SpeechService(),
        _haptics = haptics ?? HapticsService(),
        _clock = clock ?? DateTime.now;

  final ContentRepository _content;
  final ProgressStore _progressStore;
  final AudioService _audio;
  final SpeechService _speech;
  final HapticsService _haptics;
  final DateTime Function() _clock;

  ContentCatalog? _catalog;
  ProgressSnapshot _progress = ProgressSnapshot.empty();
  AppFailure? _failure;
  Future<void>? _initializeFuture;
  Future<void> _writeTail = Future<void>.value();
  String? _activeClassId;
  String? _activeSubjectId;
  String? _activeActivityId;
  bool _isLoading = false;
  bool _isInitialized = false;
  bool _isDisposed = false;
  String? _contentLanguage;

  ContentCatalog? get catalog => _catalog;

  ProgressSnapshot get progress => _progress;

  AppFailure? get failure => _failure;

  AppFailure? get error => _failure;

  String? get activeClassId => _activeClassId;

  String? get activeSubjectId => _activeSubjectId;

  String? get activeActivityId => _activeActivityId;

  bool get isLoading => _isLoading;

  bool get isInitialized => _isInitialized;

  ContentRepository get content => _content;

  ProgressStore get progressStore => _progressStore;

  AudioService get audio => _audio;

  SpeechService get speech => _speech;

  HapticsService get haptics => _haptics;

  AppStartupState get startupState {
    if (_isLoading) {
      return AppStartupState.loading;
    }
    if (hasContentFailure) {
      return AppStartupState.failed;
    }
    if (_catalog != null) {
      return AppStartupState.ready;
    }
    return AppStartupState.loading;
  }

  bool get hasContentFailure => _failure?.code == AppFailureCode.invalidContent;

  bool get hasUnreadableProgress => _progressStore.hasUnreadableProgress;

  String get contentLanguage {
    final language = _contentLanguage;
    if (language != null) {
      return language;
    }
    return _catalog?.sourceLanguage ?? ContentCatalog.defaultSourceLanguage;
  }

  bool setContentLanguage(String? language) {
    final catalog = _catalog;
    if (catalog == null) {
      return false;
    }
    final normalized = normalizeLanguageCode(language ?? '');
    if (normalized == null || !catalog.supportsLanguage(normalized)) {
      return false;
    }
    if (_contentLanguage == normalized) {
      return true;
    }
    _contentLanguage = normalized;
    _notify();
    return true;
  }

  ActivityText textFor(ActivityContent activity) {
    return activity.text(_contentLanguage, sourceLanguage: contentLanguage);
  }

  Future<void> initialize() {
    final current = _initializeFuture;
    if (current != null) {
      return current;
    }
    final future = _initialize();
    _initializeFuture = future;
    return future;
  }

  Future<void> retryInitialize() async {
    final pending = _initializeFuture;
    if (_isLoading && pending != null) {
      await _swallowFailure(pending);
      return;
    }
    _initializeFuture = null;
    _isInitialized = false;
    _failure = null;
    await _swallowFailure(initialize());
  }

  Future<void> _swallowFailure(Future<void> attempt) async {
    try {
      await attempt;
    } on AppFailure {
      return;
    }
  }

  Future<void> _initialize() async {
    _isLoading = true;
    _failure = null;
    _notify();
    ContentCatalog? loadedCatalog;
    ProgressSnapshot? loadedProgress;
    try {
      final contentFuture = _loadContent().then<void>((value) {
        loadedCatalog = value;
      });
      final progressFuture = _loadProgress().then<void>((value) {
        loadedProgress = value;
      });
      await Future.wait<void>(<Future<void>>[contentFuture, progressFuture]);
      _catalog = loadedCatalog;
      _progress = loadedProgress ?? ProgressSnapshot.empty();
      _setInitialSelection();
      _isInitialized = true;
    } on Object catch (error, stackTrace) {
      if (loadedProgress != null) {
        _progress = loadedProgress!;
      }
      if (loadedCatalog != null) {
        _catalog = loadedCatalog;
        _setInitialSelection();
      }
      _failure = _normalizeFailure(error);
      Error.throwWithStackTrace(_failure!, stackTrace);
    } finally {
      _isLoading = false;
      _notify();
    }
  }

  Future<ContentCatalog> _loadContent() async {
    try {
      return await _content.load();
    } on Object catch (error, stackTrace) {
      Error.throwWithStackTrace(
        _normalizeFailure(error, content: true),
        stackTrace,
      );
    }
  }

  Future<ProgressSnapshot> _loadProgress() async {
    try {
      return await _progressStore.load();
    } on Object catch (error, stackTrace) {
      Error.throwWithStackTrace(
        _normalizeFailure(error, content: false),
        stackTrace,
      );
    }
  }

  bool openSubject(String subjectId) {
    final currentCatalog = _catalog;
    if (currentCatalog == null ||
        !currentCatalog.subjects.any((subject) => subject.id == subjectId)) {
      return false;
    }
    _activeSubjectId = subjectId;
    _activeActivityId = null;
    _notify();
    return true;
  }

  bool openActivity(String activityId) {
    final activity = _activityById(activityId);
    if (activity == null) {
      return false;
    }
    _activeClassId = activity.classId;
    _activeSubjectId = activity.subjectId;
    _activeActivityId = activity.id;
    _notify();
    return true;
  }

  Future<void> completeActivity(String activityId) async {
    await completeActivityIfNeeded(activityId);
  }

  Future<bool> completeActivityIfNeeded(String activityId) {
    final result = _writeTail.then<bool>((_) => _completeActivity(activityId));
    _writeTail = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {},
    );
    return result;
  }

  Future<bool> _completeActivity(String activityId) async {
    if (_activityById(activityId) == null ||
        _progress.completedActivityIds.contains(activityId)) {
      return false;
    }
    final next = _progress.copyWith(
      completedActivityIds: <String>{
        ..._progress.completedActivityIds,
        activityId,
      },
      lastActivityId: activityId,
    );
    await _progressStore.save(next);
    _progress = next;
    _activeClassId = _activityById(activityId)?.classId;
    _activeSubjectId = _activityById(activityId)?.subjectId;
    _activeActivityId = activityId;
    _notify();
    return true;
  }

  Future<void> recordPractice(String activityId) {
    final result = _writeTail.then<void>((_) => _recordPractice(activityId));
    _writeTail = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {},
    );
    return result;
  }

  Future<void> _recordPractice(String activityId) async {
    if (_activityById(activityId) == null) {
      return;
    }
    final next = _progress.copyWith(
      practiceCount: _progress.practiceCount + 1,
      lastActivityId: activityId,
      lastPracticeDay: _today(),
    );
    await _progressStore.save(next);
    _progress = next;
    _notify();
  }

  Future<void> recordQuizScore(String activityId, int score) {
    final result = _writeTail.then<void>(
      (_) => _recordQuizScore(activityId, score),
    );
    _writeTail = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {},
    );
    return result;
  }

  Future<void> _recordQuizScore(String activityId, int score) async {
    if (_activityById(activityId) == null || score < 0) {
      return;
    }
    final current = _progress.quizBestScores[activityId] ?? 0;
    if (score <= current) {
      return;
    }
    final next = _progress.copyWith(
      quizBestScores: <String, int>{
        ..._progress.quizBestScores,
        activityId: score,
      },
      lastActivityId: activityId,
    );
    await _progressStore.save(next);
    _progress = next;
    _notify();
  }

  void resetSelection() {
    if (_activeClassId == null &&
        _activeSubjectId == null &&
        _activeActivityId == null) {
      return;
    }
    _activeClassId = null;
    _activeSubjectId = null;
    _activeActivityId = null;
    _notify();
  }

  Future<void> resetUnreadableProgress() {
    final result = _writeTail.then<void>((_) => _resetUnreadableProgress());
    _writeTail = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {},
    );
    return result;
  }

  Future<void> _resetUnreadableProgress() async {
    await _progressStore.resetUnreadableProgress();
    _progress = ProgressSnapshot.empty();
    if (_failure?.code == AppFailureCode.corruptProgress) {
      _failure = null;
    }
    _setInitialSelection();
    _notify();
  }

  ActivityContent? activityById(String activityId) => _activityById(activityId);

  ActivityContent? _activityById(String activityId) {
    for (final activity in _catalog?.activities ?? const <ActivityContent>[]) {
      if (activity.id == activityId) {
        return activity;
      }
    }
    return null;
  }

  void _setInitialSelection() {
    _contentLanguage ??= _catalog?.sourceLanguage;
    final lastActivityId = _progress.lastActivityId;
    final lastActivity =
        lastActivityId == null ? null : _activityById(lastActivityId);
    if (lastActivity != null) {
      _activeClassId = lastActivity.classId;
      _activeSubjectId = lastActivity.subjectId;
      _activeActivityId = lastActivity.id;
      return;
    }
    _activeClassId = null;
    _activeSubjectId = null;
    _activeActivityId = null;
  }

  String _today() {
    final now = _clock();
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    return '${now.year}-$month-$day';
  }

  AppFailure _normalizeFailure(Object error, {bool content = false}) {
    if (error is AppFailure) {
      return error;
    }
    if (content) {
      return AppFailure.invalidContent(cause: error);
    }
    return AppFailure.corruptProgress(cause: error);
  }

  void _notify() {
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}
