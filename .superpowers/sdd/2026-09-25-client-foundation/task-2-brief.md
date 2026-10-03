### Task 2: Replace local progress storage with versioned, profile-scoped persistence

**Files:**
- Create: `lib/data/progress/progress_models.dart`
- Create: `lib/data/progress/progress_store.dart`
- Test: `test/data/progress_store_test.dart`

**Interfaces:**
- `ProgressSnapshot.empty()` returns a safe empty snapshot.
- `ProgressSnapshot.decode(String? raw)` returns an empty snapshot for null, empty, or corrupt data.
- `ProgressStore.load()` returns `Future<ProgressSnapshot>`.
- `ProgressStore.save(ProgressSnapshot snapshot)` returns `Future<void>`.
- `ProgressSnapshot.merge(ProgressSnapshot other)` returns the monotonic union of completion sets and the maximum quiz score.
- The current legacy `progress_json` value is read once and migrated into the versioned store.

- [ ] **Step 1: Write failing progress tests**

Cover empty values, corrupt JSON, legacy key migration, profile isolation, and monotonic merging:

```dart
test('corrupt stored progress becomes an empty snapshot', () {
  final decoded = ProgressSnapshot.decode('{not-json');
  expect(decoded.completedActivityIds, isEmpty);
  expect(decoded.quizBestScores, isEmpty);
});

test('merge keeps the highest score and all completed activities', () {
  final first = ProgressSnapshot.empty().copyWith(
    completedActivityIds: {'one'},
    quizBestScores: {'one|quiz': 40},
  );
  final second = ProgressSnapshot.empty().copyWith(
    completedActivityIds: {'two'},
    quizBestScores: {'one|quiz': 80},
  );

  final merged = first.merge(second);
  expect(merged.completedActivityIds, {'one', 'two'});
  expect(merged.quizBestScores['one|quiz'], 80);
});
```

- [ ] **Step 2: Run the focused test and verify it fails**

Run: `flutter test test/data/progress_store_test.dart -r expanded`  
Expected: FAIL because the versioned models and store do not exist.

- [ ] **Step 3: Implement safe decoding and monotonic merge**

Use `jsonDecode` behind a guarded type check. Store `schemaVersion`, `completedActivityIds`, `quizBestScores`, `practiceCount`, `lastActivityId`, and `lastPracticeDay`. Keep the old fields readable during migration but do not write them again.

- [ ] **Step 4: Implement SharedPreferences migration**

Read the new key first. If it is absent, decode `progress_json`, map legacy class/subject/chapter keys to stable activity IDs, save the migrated value, and leave the legacy key untouched for rollback safety.

- [ ] **Step 5: Run the focused test and verify it passes**

Run: `flutter test test/data/progress_store_test.dart -r expanded`  
Expected: PASS.
