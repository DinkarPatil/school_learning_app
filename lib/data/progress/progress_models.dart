import 'dart:convert';

const _notProvided = Object();

enum ProgressDecodeStatus { absent, readable, unreadable }

class ProgressDecodeResult {
  const ProgressDecodeResult._({
    required this.status,
    required this.rawValue,
    this.snapshot,
    this.error,
  });

  const ProgressDecodeResult.absent(String? rawValue)
      : this._(
          status: ProgressDecodeStatus.absent,
          rawValue: rawValue,
        );

  const ProgressDecodeResult.readable(
      String rawValue, ProgressSnapshot snapshot)
      : this._(
          status: ProgressDecodeStatus.readable,
          rawValue: rawValue,
          snapshot: snapshot,
        );

  const ProgressDecodeResult.unreadable(String rawValue, Object? error)
      : this._(
          status: ProgressDecodeStatus.unreadable,
          rawValue: rawValue,
          error: error,
        );

  final ProgressDecodeStatus status;
  final String? rawValue;
  final ProgressSnapshot? snapshot;
  final Object? error;

  bool get isAbsent => status == ProgressDecodeStatus.absent;

  bool get isReadable => status == ProgressDecodeStatus.readable;

  bool get isUnreadable => status == ProgressDecodeStatus.unreadable;
}

class ProgressSnapshot {
  const ProgressSnapshot._({
    required this.schemaVersion,
    required this.completedActivityIds,
    required this.quizBestScores,
    required this.practiceCount,
    required this.lastActivityId,
    required this.lastPracticeDay,
  });

  factory ProgressSnapshot({
    int schemaVersion = currentSchemaVersion,
    Set<String> completedActivityIds = const <String>{},
    Map<String, int> quizBestScores = const <String, int>{},
    int practiceCount = 0,
    String? lastActivityId,
    String? lastPracticeDay,
  }) {
    if (schemaVersion != currentSchemaVersion) {
      throw ArgumentError.value(schemaVersion, 'schemaVersion');
    }
    if (practiceCount < 0) {
      throw ArgumentError.value(practiceCount, 'practiceCount');
    }
    return ProgressSnapshot._(
      schemaVersion: schemaVersion,
      completedActivityIds: Set<String>.unmodifiable(completedActivityIds),
      quizBestScores: Map<String, int>.unmodifiable(quizBestScores),
      practiceCount: practiceCount,
      lastActivityId: lastActivityId,
      lastPracticeDay: lastPracticeDay,
    );
  }

  factory ProgressSnapshot.empty() => const ProgressSnapshot._(
        schemaVersion: currentSchemaVersion,
        completedActivityIds: <String>{},
        quizBestScores: <String, int>{},
        practiceCount: 0,
        lastActivityId: null,
        lastPracticeDay: null,
      );

  factory ProgressSnapshot.decode(String? raw) {
    final result = ProgressSnapshot.tryDecode(raw);
    if (result.isReadable) {
      return result.snapshot!;
    }
    return ProgressSnapshot.empty();
  }

  static ProgressDecodeResult tryDecode(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return ProgressDecodeResult.absent(raw);
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return ProgressDecodeResult.unreadable(
          raw,
          const FormatException('Stored progress must be a JSON object.'),
        );
      }
      final json = <String, dynamic>{};
      for (final entry in decoded.entries) {
        if (entry.key is! String) {
          return ProgressDecodeResult.unreadable(
            raw,
            const FormatException('Stored progress keys must be strings.'),
          );
        }
        json[entry.key! as String] = entry.value;
      }
      return ProgressDecodeResult.readable(
          raw, ProgressSnapshot._fromJson(json));
    } on Object catch (error) {
      return ProgressDecodeResult.unreadable(raw, error);
    }
  }

  factory ProgressSnapshot._fromJson(Map<String, dynamic> json) {
    final versionValue = json['schemaVersion'];
    if (versionValue != null && versionValue != currentSchemaVersion) {
      throw const FormatException('Unsupported progress schema version.');
    }
    final practiceCount = json['practiceCount'] ?? 0;
    if (practiceCount is! int) {
      throw const FormatException('practiceCount must be an integer.');
    }
    return ProgressSnapshot(
      completedActivityIds: _stringSet(
        json['completedActivityIds'],
        'completedActivityIds',
      ),
      quizBestScores: _scoreMap(json['quizBestScores']),
      practiceCount: practiceCount,
      lastActivityId: _optionalString(json['lastActivityId'], 'lastActivityId'),
      lastPracticeDay: _optionalString(
        json['lastPracticeDay'],
        'lastPracticeDay',
      ),
    );
  }

  static const int currentSchemaVersion = 2;

  final int schemaVersion;
  final Set<String> completedActivityIds;
  final Map<String, int> quizBestScores;
  final int practiceCount;
  final String? lastActivityId;
  final String? lastPracticeDay;

  Map<String, dynamic> toJson() {
    final completed = completedActivityIds.toList()..sort();
    final scoreKeys = quizBestScores.keys.toList()..sort();
    return <String, dynamic>{
      'schemaVersion': schemaVersion,
      'completedActivityIds': completed,
      'quizBestScores': <String, int>{
        for (final key in scoreKeys) key: quizBestScores[key]!,
      },
      'practiceCount': practiceCount,
      'lastActivityId': lastActivityId,
      'lastPracticeDay': lastPracticeDay,
    };
  }

  String encode() => jsonEncode(toJson());

  ProgressSnapshot copyWith({
    int? schemaVersion,
    Set<String>? completedActivityIds,
    Map<String, int>? quizBestScores,
    int? practiceCount,
    Object? lastActivityId = _notProvided,
    Object? lastPracticeDay = _notProvided,
  }) {
    return ProgressSnapshot(
      schemaVersion: schemaVersion ?? this.schemaVersion,
      completedActivityIds: completedActivityIds ?? this.completedActivityIds,
      quizBestScores: quizBestScores ?? this.quizBestScores,
      practiceCount: practiceCount ?? this.practiceCount,
      lastActivityId: identical(lastActivityId, _notProvided)
          ? this.lastActivityId
          : lastActivityId as String?,
      lastPracticeDay: identical(lastPracticeDay, _notProvided)
          ? this.lastPracticeDay
          : lastPracticeDay as String?,
    );
  }

  ProgressSnapshot merge(ProgressSnapshot other) {
    if (_sameSnapshotAs(other)) {
      return this;
    }
    final mergedScores = <String, int>{...quizBestScores};
    for (final entry in other.quizBestScores.entries) {
      final current = mergedScores[entry.key];
      if (current == null || entry.value > current) {
        mergedScores[entry.key] = entry.value;
      }
    }
    return ProgressSnapshot(
      completedActivityIds: <String>{
        ...completedActivityIds,
        ...other.completedActivityIds,
      },
      quizBestScores: mergedScores,
      practiceCount: other.practiceCount > practiceCount
          ? other.practiceCount
          : practiceCount,
      lastActivityId: other.lastActivityId ?? lastActivityId,
      lastPracticeDay: _latestDay(lastPracticeDay, other.lastPracticeDay),
    );
  }

  bool _sameSnapshotAs(ProgressSnapshot other) {
    if (schemaVersion != other.schemaVersion ||
        practiceCount != other.practiceCount ||
        lastActivityId != other.lastActivityId ||
        lastPracticeDay != other.lastPracticeDay ||
        completedActivityIds.length != other.completedActivityIds.length ||
        quizBestScores.length != other.quizBestScores.length) {
      return false;
    }
    if (!completedActivityIds.containsAll(other.completedActivityIds)) {
      return false;
    }
    for (final entry in quizBestScores.entries) {
      if (other.quizBestScores[entry.key] != entry.value) {
        return false;
      }
    }
    return true;
  }
}

Set<String> _stringSet(Object? value, String field) {
  if (value == null) {
    return const <String>{};
  }
  if (value is! List) {
    throw FormatException('$field must be a list.', value);
  }
  final result = <String>{};
  for (final item in value) {
    if (item is! String || item.trim().isEmpty) {
      throw FormatException('$field must contain non-empty strings.', value);
    }
    result.add(item);
  }
  return result;
}

Map<String, int> _scoreMap(Object? value) {
  if (value == null) {
    return const <String, int>{};
  }
  if (value is! Map) {
    throw const FormatException('quizBestScores must be an object.');
  }
  final result = <String, int>{};
  for (final entry in value.entries) {
    final key = entry.key;
    final score = entry.value;
    if (key is! String || key.trim().isEmpty || score is! int || score < 0) {
      throw FormatException('Invalid quiz score.', entry);
    }
    result[key] = score;
  }
  return result;
}

String? _optionalString(Object? value, String field) {
  if (value == null) {
    return null;
  }
  if (value is String && value.trim().isNotEmpty) {
    return value;
  }
  throw FormatException('$field must be a non-empty string.', value);
}

String? _latestDay(String? first, String? second) {
  if (first == null) {
    return second;
  }
  if (second == null) {
    return first;
  }
  return first.compareTo(second) >= 0 ? first : second;
}
