import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:school_learning_app/core/errors/app_failure.dart';
import 'package:school_learning_app/data/progress/progress_models.dart';
import 'package:school_learning_app/data/progress/progress_store.dart';

void main() {
  group('ProgressSnapshot', () {
    test('null and empty values decode to a safe empty snapshot', () {
      for (final raw in <String?>[null, '', '   ']) {
        final decoded = ProgressSnapshot.decode(raw);

        expect(decoded.schemaVersion, 2);
        expect(decoded.completedActivityIds, isEmpty);
        expect(decoded.quizBestScores, isEmpty);
        expect(decoded.practiceCount, 0);
        expect(decoded.lastActivityId, isNull);
        expect(decoded.lastPracticeDay, isNull);
      }
    });

    test('corrupt JSON and non-object values decode to an empty snapshot', () {
      for (final raw in <String>['{not-json', '[]', '42', '"progress"']) {
        final decoded = ProgressSnapshot.decode(raw);

        expect(decoded.completedActivityIds, isEmpty);
        expect(decoded.quizBestScores, isEmpty);
        expect(decoded.practiceCount, 0);
      }
    });

    test('malformed versioned fields decode to an empty snapshot', () {
      final decoded = ProgressSnapshot.decode(
        '{"schemaVersion":2,"completedActivityIds":"not-a-list"}',
      );

      expect(decoded, isNotNull);
      expect(decoded.completedActivityIds, isEmpty);
      expect(decoded.quizBestScores, isEmpty);
    });

    test('tryDecode separates absent, readable, and unreadable values', () {
      for (final raw in <String?>[null, '', '   ']) {
        final result = ProgressSnapshot.tryDecode(raw);
        expect(result.isAbsent, isTrue, reason: '$raw');
        expect(result.snapshot, isNull);
      }

      final readable = ProgressSnapshot.tryDecode(
        ProgressSnapshot.empty().copyWith(practiceCount: 5).encode(),
      );
      expect(readable.isReadable, isTrue);
      expect(readable.snapshot!.practiceCount, 5);

      for (final raw in <String>[
        '{not-json',
        '[]',
        '42',
        '{"schemaVersion":2,"completedActivityIds":"not-a-list"}',
        '{"schemaVersion":7}',
      ]) {
        final result = ProgressSnapshot.tryDecode(raw);
        expect(result.isUnreadable, isTrue, reason: raw);
        expect(result.rawValue, raw, reason: raw);
        expect(result.error, isNotNull, reason: raw);
        expect(result.snapshot, isNull, reason: raw);
      }
    });

    test('encoding writes only the versioned progress fields', () {
      final snapshot = ProgressSnapshot.empty().copyWith(
        completedActivityIds: {'class-1-subject-english-activity-story'},
        quizBestScores: {
          'class-1-subject-english-activity-story': 80,
        },
        practiceCount: 3,
        lastActivityId: 'class-1-subject-english-activity-story',
        lastPracticeDay: '2026-09-25',
      );

      final encoded = jsonDecode(snapshot.encode()) as Map<String, dynamic>;

      expect(
        encoded.keys,
        unorderedEquals(<String>[
          'schemaVersion',
          'completedActivityIds',
          'quizBestScores',
          'practiceCount',
          'lastActivityId',
          'lastPracticeDay',
        ]),
      );
      expect(encoded['schemaVersion'], 2);
      expect(encoded['practiceCount'], 3);
      expect(
        encoded.containsKey('lessonsCompleted'),
        isFalse,
      );
      expect(
        encoded.containsKey('practicesCompleted'),
        isFalse,
      );
    });

    test('merge unions completions, best scores, and highest practice count',
        () {
      final first = ProgressSnapshot.empty().copyWith(
        completedActivityIds: {'one'},
        quizBestScores: {'one|quiz': 40, 'shared': 60},
        practiceCount: 2,
        lastActivityId: 'one',
        lastPracticeDay: '2026-09-23',
      );
      final second = ProgressSnapshot.empty().copyWith(
        completedActivityIds: {'two'},
        quizBestScores: {'two|quiz': 75, 'shared': 50},
        practiceCount: 3,
        lastActivityId: 'two',
        lastPracticeDay: '2026-09-25',
      );

      final merged = first.merge(second);

      expect(merged.completedActivityIds, {'one', 'two'});
      expect(
        merged.quizBestScores,
        {'one|quiz': 40, 'two|quiz': 75, 'shared': 60},
      );
      expect(merged.practiceCount, 3);
      expect(
        merged.copyWith(practiceCount: merged.practiceCount + 1).practiceCount,
        4,
      );
      expect(merged.lastActivityId, 'two');
      expect(merged.lastPracticeDay, '2026-09-25');
    });

    test('merging the same snapshot does not count practice twice', () {
      final snapshot = ProgressSnapshot.empty().copyWith(
        completedActivityIds: {'one'},
        practiceCount: 2,
        lastActivityId: 'one',
      );

      final repeatedSnapshot = ProgressSnapshot.decode(snapshot.encode());
      final merged = snapshot.merge(repeatedSnapshot);

      expect(merged.practiceCount, 2);
      expect(merged.completedActivityIds, {'one'});
      expect(merged.lastActivityId, 'one');
    });
  });

  group('ProgressStore', () {
    test('load without stored values returns an empty snapshot', () async {
      final preferences = _MemoryProgressPreferences();
      final store = ProgressStore(
        profileId: 'child-a',
        preferences: preferences,
      );

      final loaded = await store.load();

      expect(loaded.completedActivityIds, isEmpty);
      expect(loaded.quizBestScores, isEmpty);
      expect(preferences.values, isEmpty);
    });

    test('saved progress is isolated by profile', () async {
      final preferences = _MemoryProgressPreferences();
      final childA = ProgressStore(
        profileId: 'child-a',
        preferences: preferences,
      );
      final childB = ProgressStore(
        profileId: 'child-b',
        preferences: preferences,
      );
      final childASnapshot = ProgressSnapshot.empty().copyWith(
        completedActivityIds: {'child-a-activity'},
        practiceCount: 2,
      );
      final childBSnapshot = ProgressSnapshot.empty().copyWith(
        completedActivityIds: {'child-b-activity'},
        practiceCount: 7,
      );

      await childA.save(childASnapshot);
      await childB.save(childBSnapshot);

      expect((await childA.load()).completedActivityIds, {
        'child-a-activity',
      });
      expect((await childA.load()).practiceCount, 2);
      expect((await childB.load()).completedActivityIds, {
        'child-b-activity',
      });
      expect((await childB.load()).practiceCount, 7);
      expect(
        preferences.values['learning_progress_v2:child-a'],
        isNotNull,
      );
      expect(
        preferences.values['learning_progress_v2:child-b'],
        isNotNull,
      );
    });

    test('legacy progress migrates to exact stable activity IDs', () async {
      const legacyRaw = '''
      {
        "lessonsCompleted": ["1|english|starter"],
        "quizBestScores": {
          "1|english|starter": 55,
          "2|mathematics|numbers": 70
        },
        "practicesCompleted": ["1|english|starter"],
        "totalPracticeSessions": 3,
        "lastPracticeDay": "2026-09-24",
        "littleCompleted": ["capitals", "findLetter"],
        "littleStars": 2
      }
      ''';
      final preferences = _MemoryProgressPreferences(
        initialValues: const <String, String>{'progress_json': legacyRaw},
      );
      final store = ProgressStore(
        profileId: 'child-a',
        preferences: preferences,
      );

      final migrated = await store.load();

      expect(
        migrated.completedActivityIds,
        {
          'class-1-subject-english-activity-story',
          'class-0-subject-little-activity-capitals',
          'class-0-subject-little-activity-find-letter',
        },
      );
      expect(
        migrated.quizBestScores,
        {
          'class-1-subject-english-activity-story': 55,
          'class-2-subject-mathematics-activity-numbers': 70,
        },
      );
      expect(migrated.practiceCount, 3);
      expect(migrated.lastPracticeDay, '2026-09-24');
      expect(preferences.values['progress_json'], legacyRaw);

      final persisted = jsonDecode(
        preferences.values['learning_progress_v2:child-a']!,
      ) as Map<String, dynamic>;
      expect(
        persisted.keys,
        unorderedEquals(<String>[
          'schemaVersion',
          'completedActivityIds',
          'quizBestScores',
          'practiceCount',
          'lastActivityId',
          'lastPracticeDay',
        ]),
      );
    });

    test(
        'legacy migration skips malformed entries and preserves valid progress',
        () async {
      final preferences = _MemoryProgressPreferences(
        initialValues: const <String, String>{
          'progress_json': '''{
            "lessonsCompleted": [
              17,
              "",
              "not-a-stable-id",
              "1|english|starter"
            ],
            "quizBestScores": {
              "1|english|starter": "not-a-score",
              "2|mathematics|numbers": 80
            },
            "practicesCompleted": [17, "1|english|starter"],
            "totalPracticeSessions": 4,
            "lastPracticeDay": 42,
            "littleCompleted": ["not a stable id", 17, "capitals"],
            "littleStars": "discarded"
          }''',
        },
      );
      final store = ProgressStore(
        profileId: 'child-a',
        preferences: preferences,
      );

      final migrated = await store.load();

      expect(migrated.completedActivityIds, {
        'class-1-subject-english-activity-story',
        'class-0-subject-little-activity-capitals',
      });
      expect(migrated.quizBestScores, {
        'class-2-subject-mathematics-activity-numbers': 80,
      });
      expect(migrated.practiceCount, 4);
      expect(migrated.lastPracticeDay, isNull);
    });

    test('legacy progress migrates only into the first loading profile',
        () async {
      final preferences = _MemoryProgressPreferences(
        initialValues: const <String, String>{
          'progress_json': '''{
            "lessonsCompleted": ["1|english|starter"],
            "quizBestScores": {},
            "practicesCompleted": ["1|english|starter"],
            "totalPracticeSessions": 3,
            "lastPracticeDay": "2026-09-24"
          }''',
        },
      );
      final childA = ProgressStore(
        profileId: 'child-a',
        preferences: preferences,
      );
      final childB = ProgressStore(
        profileId: 'child-b',
        preferences: preferences,
      );

      final firstProfile = await childA.load();
      final secondProfile = await childB.load();

      expect(firstProfile.practiceCount, 3);
      expect(firstProfile.completedActivityIds, {
        'class-1-subject-english-activity-story',
      });
      expect(secondProfile.practiceCount, 0);
      expect(secondProfile.completedActivityIds, isEmpty);
    });

    test('concurrent profile loads migrate legacy progress only once',
        () async {
      final preferences = _MemoryProgressPreferences(
        initialValues: const <String, String>{
          'progress_json': '''{
            "lessonsCompleted": ["1|english|starter"],
            "quizBestScores": {"1|english|starter": 55},
            "practicesCompleted": ["1|english|starter"],
            "totalPracticeSessions": 3,
            "lastPracticeDay": "2026-09-24"
          }''',
        },
      );
      final childA = ProgressStore(
        profileId: 'child-a',
        preferences: preferences,
      );
      final childB = ProgressStore(
        profileId: 'child-b',
        preferences: preferences,
      );

      final childALoad = childA.load();
      final childBLoad = childB.load();
      final loaded = await Future.wait(<Future<ProgressSnapshot>>[
        childALoad,
        childBLoad,
      ]);

      expect(loaded[0].practiceCount, 3);
      expect(loaded[0].completedActivityIds, {
        'class-1-subject-english-activity-story',
      });
      expect(loaded[1].practiceCount, 0);
      expect(loaded[1].completedActivityIds, isEmpty);
    });

    test('migration runs once and repeated loads prefer versioned progress',
        () async {
      final preferences = _MemoryProgressPreferences(
        initialValues: const <String, String>{
          'progress_json': '''{
            "lessonsCompleted": ["1|english|starter"],
            "quizBestScores": {"1|english|starter": 55},
            "practicesCompleted": ["1|english|starter"],
            "totalPracticeSessions": 3,
            "lastPracticeDay": "2026-09-24"
          }''',
        },
      );
      final store = ProgressStore(
        profileId: 'child-a',
        preferences: preferences,
      );

      final firstLoad = await store.load();
      preferences.values['progress_json'] = '''{
        "lessonsCompleted": [],
        "quizBestScores": {},
        "practicesCompleted": [],
        "totalPracticeSessions": 99,
        "lastPracticeDay": null
      }''';
      final secondLoad = await store.load();

      expect(firstLoad.practiceCount, 3);
      expect(secondLoad.practiceCount, 3);
      expect(secondLoad.completedActivityIds, {
        'class-1-subject-english-activity-story',
      });
      final persisted = ProgressSnapshot.decode(
        preferences.values['learning_progress_v2:child-a'],
      );
      expect(persisted.practiceCount, 3);
    });

    test('unreadable versioned progress fails safely without legacy fallback',
        () async {
      final preferences = _MemoryProgressPreferences(
        initialValues: const <String, String>{
          'learning_progress_v2:child-a': '{not-json',
          'progress_json': '''{
            "lessonsCompleted": ["1|english|starter"],
            "quizBestScores": {},
            "practicesCompleted": [],
            "totalPracticeSessions": 8,
            "lastPracticeDay": null
          }''',
        },
      );
      final store = ProgressStore(
        profileId: 'child-a',
        preferences: preferences,
      );

      await expectLater(
        store.load(),
        throwsA(
          isA<AppFailure>().having(
            (failure) => failure.code,
            'code',
            AppFailureCode.corruptProgress,
          ),
        ),
      );

      expect(store.hasUnreadableProgress, isTrue);
      expect(store.unreadableRawValue, '{not-json');
      expect(preferences.values['learning_progress_v2:child-a'], '{not-json');
      expect(
        preferences.values['learning_progress_v2_unreadable:child-a'],
        '{not-json',
        reason: 'the unreadable value must be preserved for recovery',
      );
    });

    test('a future schema version is preserved instead of discarded', () async {
      const futureRaw =
          '{"schemaVersion":9,"completedActivityIds":["class-1-subject-english-activity-story"]}';
      final preferences = _MemoryProgressPreferences(
        initialValues: const <String, String>{
          'learning_progress_v2:child-a': futureRaw,
        },
      );
      final store = ProgressStore(
        profileId: 'child-a',
        preferences: preferences,
      );

      await expectLater(
        store.load(),
        throwsA(
          isA<AppFailure>().having(
            (failure) => failure.code,
            'code',
            AppFailureCode.corruptProgress,
          ),
        ),
      );

      expect(store.hasUnreadableProgress, isTrue);
      expect(
        preferences.values['learning_progress_v2_unreadable:child-a'],
        futureRaw,
      );
      expect(preferences.values['learning_progress_v2:child-a'], futureRaw);
    });

    test('saves are refused until the unreadable copy is reset', () async {
      final preferences = _MemoryProgressPreferences(
        initialValues: const <String, String>{
          'learning_progress_v2:child-a': '{not-json',
        },
      );
      final store = ProgressStore(
        profileId: 'child-a',
        preferences: preferences,
      );
      await expectLater(store.load(), throwsA(isA<AppFailure>()));

      await expectLater(
        store.save(ProgressSnapshot.empty().copyWith(practiceCount: 2)),
        throwsA(
          isA<AppFailure>().having(
            (failure) => failure.code,
            'code',
            AppFailureCode.corruptProgress,
          ),
        ),
      );
      expect(preferences.values['learning_progress_v2:child-a'], '{not-json');
    });

    test('resetting unreadable progress restores a writable empty snapshot',
        () async {
      final preferences = _MemoryProgressPreferences(
        initialValues: const <String, String>{
          'learning_progress_v2:child-a': '{not-json',
        },
      );
      final store = ProgressStore(
        profileId: 'child-a',
        preferences: preferences,
      );
      await expectLater(store.load(), throwsA(isA<AppFailure>()));

      await store.resetUnreadableProgress();

      expect(store.hasUnreadableProgress, isFalse);
      expect(store.unreadableRawValue, isNull);
      expect(preferences.values['learning_progress_v2_unreadable:child-a'], '');

      final loaded = await store.load();
      expect(loaded.practiceCount, 0);
      expect(loaded.completedActivityIds, isEmpty);

      await store.save(loaded.copyWith(practiceCount: 3));
      expect((await store.load()).practiceCount, 3);
      expect(store.hasUnreadableProgress, isFalse);
    });

    test('a readable value clears a stale recovery copy', () async {
      final preferences = _MemoryProgressPreferences(
        initialValues: const <String, String>{
          'learning_progress_v2:child-a':
              '{"schemaVersion":2,"practiceCount":4}',
          'learning_progress_v2_unreadable:child-a': '{not-json',
        },
      );
      final store = ProgressStore(
        profileId: 'child-a',
        preferences: preferences,
      );

      final loaded = await store.load();

      expect(loaded.practiceCount, 4);
      expect(store.hasUnreadableProgress, isFalse);
      expect(preferences.values['learning_progress_v2_unreadable:child-a'], '');
    });

    test('persistence failures are exposed as corrupt progress failures',
        () async {
      final preferences = _MemoryProgressPreferences()
        ..writeFailure = StateError('disk unavailable');
      final store = ProgressStore(
        profileId: 'child-a',
        preferences: preferences,
      );

      await expectLater(
        store.save(ProgressSnapshot.empty()),
        throwsA(
          isA<AppFailure>().having(
            (failure) => failure.code,
            'code',
            AppFailureCode.corruptProgress,
          ),
        ),
      );
    });
  });
}

class _MemoryProgressPreferences implements ProgressPreferences {
  _MemoryProgressPreferences({Map<String, String>? initialValues})
      : values = <String, String>{...?initialValues};

  final Map<String, String> values;
  Object? writeFailure;

  @override
  Future<String?> readString(String key) async => values[key];

  @override
  Future<void> writeString(String key, String value) async {
    final failure = writeFailure;
    if (failure != null) {
      throw failure;
    }
    values[key] = value;
  }
}
