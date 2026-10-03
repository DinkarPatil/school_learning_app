import 'dart:async';
import 'dart:convert';

import 'package:school_learning_app/core/errors/app_failure.dart';
import 'package:school_learning_app/data/progress/progress_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract interface class ProgressPreferences {
  Future<String?> readString(String key);

  Future<void> writeString(String key, String value);
}

class SharedPreferencesProgressPreferences implements ProgressPreferences {
  const SharedPreferencesProgressPreferences(this._preferences);

  final SharedPreferences _preferences;

  @override
  Future<String?> readString(String key) async => _preferences.getString(key);

  @override
  Future<void> writeString(String key, String value) async {
    final saved = await _preferences.setString(key, value);
    if (!saved) {
      throw StateError('SharedPreferences rejected $key.');
    }
  }
}

class ProgressStore {
  ProgressStore({
    required this.profileId,
    ProgressPreferences? preferences,
    SharedPreferences? sharedPreferences,
  }) : _preferences = preferences ??
            (sharedPreferences == null
                ? null
                : SharedPreferencesProgressPreferences(sharedPreferences));

  static const String versionedKey = 'learning_progress_v2';
  static const String legacyKey = 'progress_json';
  static const String recoveryKeyPrefix = 'learning_progress_v2_unreadable';
  static const String _migrationMarkerKey =
      'learning_progress_v2_migration_complete';
  static Future<void> _migrationTail = Future<void>.value();

  final String profileId;
  ProgressPreferences? _preferences;
  Future<ProgressSnapshot>? _loading;
  bool _hasUnreadableProgress = false;
  String? _unreadableRawValue;

  String get storageKey => '$versionedKey:$profileId';

  String get recoveryKey => '$recoveryKeyPrefix:$profileId';

  bool get hasUnreadableProgress => _hasUnreadableProgress;

  String? get unreadableRawValue => _unreadableRawValue;

  Future<ProgressSnapshot> load() {
    final loading = _loading;
    if (loading != null) {
      return loading;
    }
    final future = _load();
    _loading = future;
    return future.whenComplete(() {
      if (identical(_loading, future)) {
        _loading = null;
      }
    });
  }

  Future<void> save(ProgressSnapshot snapshot) async {
    if (_hasUnreadableProgress) {
      throw AppFailure.corruptProgress(
        cause: StateError(
          'Unreadable saved progress must be reset before it can be written.',
        ),
      );
    }
    try {
      final preferences = await _resolvePreferences();
      await preferences.writeString(storageKey, snapshot.encode());
    } on AppFailure {
      rethrow;
    } catch (error) {
      throw AppFailure.corruptProgress(cause: error);
    }
  }

  Future<void> resetUnreadableProgress({ProgressSnapshot? replacement}) async {
    try {
      final preferences = await _resolvePreferences();
      await preferences.writeString(
        storageKey,
        (replacement ?? ProgressSnapshot.empty()).encode(),
      );
      await _clearRecoveryCopy(preferences);
    } on AppFailure {
      rethrow;
    } catch (error) {
      throw AppFailure.corruptProgress(cause: error);
    }
    _hasUnreadableProgress = false;
    _unreadableRawValue = null;
  }

  Future<ProgressSnapshot> _load() async {
    try {
      final preferences = await _resolvePreferences();
      final currentRaw = await preferences.readString(storageKey);
      if (currentRaw != null) {
        return _adoptStoredValue(currentRaw, preferences);
      }
      final migrationComplete =
          await preferences.readString(_migrationMarkerKey);
      if (migrationComplete != null) {
        return ProgressSnapshot.empty();
      }
      return _withMigrationLock(() async {
        final latestCurrentRaw = await preferences.readString(storageKey);
        if (latestCurrentRaw != null) {
          return _adoptStoredValue(latestCurrentRaw, preferences);
        }
        final latestMigrationComplete =
            await preferences.readString(_migrationMarkerKey);
        if (latestMigrationComplete != null) {
          return ProgressSnapshot.empty();
        }

        final legacyRaw = await preferences.readString(legacyKey);
        if (legacyRaw == null) {
          return ProgressSnapshot.empty();
        }
        final migrated = _decodeLegacy(legacyRaw);
        await preferences.writeString(storageKey, migrated.encode());
        await preferences.writeString(_migrationMarkerKey, 'true');
        return migrated;
      });
    } on AppFailure {
      rethrow;
    } catch (error) {
      throw AppFailure.corruptProgress(cause: error);
    }
  }

  Future<ProgressSnapshot> _adoptStoredValue(
    String raw,
    ProgressPreferences preferences,
  ) async {
    final result = ProgressSnapshot.tryDecode(raw);
    if (result.isReadable) {
      _hasUnreadableProgress = false;
      _unreadableRawValue = null;
      await _clearRecoveryCopy(preferences);
      return result.snapshot!;
    }
    _hasUnreadableProgress = true;
    _unreadableRawValue = raw;
    await _preserveUnreadableValue(preferences, raw);
    throw AppFailure.corruptProgress(cause: result.error);
  }

  Future<void> _preserveUnreadableValue(
    ProgressPreferences preferences,
    String raw,
  ) async {
    try {
      if (await preferences.readString(recoveryKey) == raw) {
        return;
      }
      await preferences.writeString(recoveryKey, raw);
    } on Object {
      return;
    }
  }

  Future<void> _clearRecoveryCopy(ProgressPreferences preferences) async {
    try {
      if (await preferences.readString(recoveryKey) == null) {
        return;
      }
      await preferences.writeString(recoveryKey, '');
    } on Object {
      return;
    }
  }

  static Future<T> _withMigrationLock<T>(
    Future<T> Function() action,
  ) {
    final previous = _migrationTail;
    final release = Completer<void>();
    _migrationTail = release.future;
    return () async {
      await previous;
      try {
        return await action();
      } finally {
        release.complete();
      }
    }();
  }

  Future<ProgressPreferences> _resolvePreferences() async {
    final preferences = _preferences;
    if (preferences != null) {
      return preferences;
    }
    try {
      final sharedPreferences = await SharedPreferences.getInstance();
      return _preferences =
          SharedPreferencesProgressPreferences(sharedPreferences);
    } catch (error) {
      throw AppFailure.corruptProgress(cause: error);
    }
  }
}

ProgressSnapshot _decodeLegacy(String raw) {
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      return ProgressSnapshot.empty();
    }
    final json = <String, dynamic>{};
    for (final entry in decoded.entries) {
      if (entry.key is! String) {
        return ProgressSnapshot.empty();
      }
      final key = entry.key as String;
      json[key] = entry.value;
    }

    final completedActivityIds = <String>{};
    String? lastActivityId;
    for (final legacyId in _legacyStringList(json['lessonsCompleted'])) {
      final stableId = _stableActivityId(legacyId);
      if (stableId != null) {
        completedActivityIds.add(stableId);
        lastActivityId = stableId;
      }
    }
    for (final legacyId in _legacyStringList(json['littleCompleted'])) {
      final stableId = _littleActivityId(legacyId);
      if (stableId != null) {
        completedActivityIds.add(stableId);
      }
    }

    final quizBestScores = <String, int>{};
    final rawScores = json['quizBestScores'];
    if (rawScores is Map) {
      for (final entry in rawScores.entries) {
        final legacyId = entry.key;
        final score = entry.value;
        if (legacyId is! String || score is! int || score < 0) {
          continue;
        }
        final stableId = _stableActivityId(legacyId);
        if (stableId != null) {
          final current = quizBestScores[stableId];
          if (current == null || score > current) {
            quizBestScores[stableId] = score;
          }
        }
      }
    }

    final rawPracticeCount = json['totalPracticeSessions'];
    final practiceCount =
        rawPracticeCount is int && rawPracticeCount >= 0 ? rawPracticeCount : 0;

    return ProgressSnapshot(
      completedActivityIds: completedActivityIds,
      quizBestScores: quizBestScores,
      practiceCount: practiceCount,
      lastActivityId: lastActivityId,
      lastPracticeDay: _legacyOptionalString(json['lastPracticeDay']),
    );
  } catch (_) {
    return ProgressSnapshot.empty();
  }
}

Iterable<String> _legacyStringList(Object? value) sync* {
  if (value is! List) {
    return;
  }
  for (final item in value) {
    if (item is String && item.isNotEmpty) {
      yield item;
    }
  }
}

String? _legacyOptionalString(Object? value) {
  if (value is String && value.isNotEmpty) {
    return value;
  }
  return null;
}

String? _stableActivityId(String legacyId) {
  final parts = legacyId.split('|');
  if (parts.length != 3) {
    return null;
  }
  final classLevel = int.tryParse(parts[0]);
  final subject = parts[1];
  var activity = parts[2];
  if (classLevel == null ||
      classLevel < 0 ||
      !_stableSegment.hasMatch(subject)) {
    return null;
  }
  if (activity == 'starter') {
    activity = 'story';
  }
  if (!_stableSegment.hasMatch(activity)) {
    return null;
  }
  return 'class-$classLevel-subject-$subject-activity-$activity';
}

String? _littleActivityId(String legacyId) {
  const aliases = <String, String>{
    'findLetter': 'find-letter',
    'matchCase': 'match-case',
    'firstWords': 'first-words',
  };
  final activity = aliases[legacyId] ?? legacyId;
  if (!_stableSegment.hasMatch(activity)) {
    return null;
  }
  return 'class-0-subject-little-activity-$activity';
}

final RegExp _stableSegment = RegExp(r'^[a-z0-9_-]+$');
