# Task 2 Report

## Status

DONE

## Files changed

- Created `lib/data/progress/progress_models.dart`
- Created `lib/data/progress/progress_store.dart`
- Created `test/data/progress_store_test.dart`
- Created `.superpowers/sdd/2026-09-25-client-foundation/task-2-report.md`

No Git commands were run. The legacy `lib/progress_store.dart`, `lib/models.dart`, app controller, and UI were not changed.

## Implementation summary

### Versioned progress model

- Added immutable `ProgressSnapshot` data with schema version `2` and the required fields:
  - `schemaVersion`
  - `completedActivityIds`
  - `quizBestScores`
  - `practiceCount`
  - `lastActivityId`
  - `lastPracticeDay`
- Added `ProgressSnapshot.empty()` for a safe zero-value snapshot.
- Added guarded `ProgressSnapshot.decode(String? raw)`:
  - `null`, blank, malformed JSON, non-object JSON, unsupported versions, and malformed field types return an empty snapshot.
  - Decoding never exposes JSON/type exceptions to startup.
  - Collections are defensively copied and exposed as unmodifiable sets/maps.
- Added deterministic JSON encoding that writes only the six versioned fields. Legacy field names are never written by the new model.
- Added `copyWith()` with explicit support for clearing nullable `lastActivityId` and `lastPracticeDay` values.
- Added monotonic `merge()`:
  - Completion IDs use set union.
  - Quiz scores retain the maximum value.
  - Practice counts add across distinct snapshots.
  - A structurally identical snapshot, including a separately decoded/reloaded copy, is treated as the same snapshot and does not double-count practice.
  - The latest non-null `lastPracticeDay` is retained; the incoming non-null `lastActivityId` is retained.

### Profile-scoped persistence

- Added `ProgressStore({required profileId, ...})` with profile-scoped keys of the form:
  - `learning_progress_v2:<profileId>`
- The required versioned key base remains exactly `learning_progress_v2`.
- Added an injectable `ProgressPreferences` wrapper so store tests use an in-memory implementation and do not initialize platform plugins.
- Added `SharedPreferencesProgressPreferences` as the production adapter around an injected `SharedPreferences` instance.
- `ProgressStore` also retains a production default that lazily obtains `SharedPreferences.getInstance()`.
- `save()` writes only the current profile's versioned key.
- Persistence read/write failures are converted to `AppFailure.corruptProgress` while preserving the underlying cause.
- Concurrent calls to `load()` on the same store share the in-flight load rather than launching duplicate migrations.

### Safe one-time legacy migration

- Every load reads the profile's versioned value first.
- A present but corrupt versioned value decodes to an empty snapshot and is not replaced by legacy data.
- If the versioned value is absent and migration has not already completed:
  - `progress_json` is decoded defensively.
  - Legacy `class|subject|chapter` keys become full Task 1 stable IDs: `class-{n}-subject-{subject}-activity-{chapter}`.
  - The actual legacy chapter value `starter` is normalized to Task 1's `story` activity suffix, producing IDs such as `class-1-subject-english-activity-story`.
  - Legacy quiz-score keys receive the same stable-ID conversion.
  - Legacy Little Stars completion IDs are migrated to the `class-0-subject-little-activity-*` format, including Task 1 slug aliases for `findLetter`, `matchCase`, and `firstWords`.
  - `totalPracticeSessions` becomes `practiceCount`; `lastPracticeDay` is retained.
  - The migrated versioned snapshot is saved and a migration-complete marker is saved.
  - `progress_json` remains byte-for-byte untouched for rollback safety.
- The migration-complete marker prevents the retained unscoped legacy value from being copied into every profile. Only the first profile that loads an unmigrated store receives the legacy snapshot; later profiles start empty unless they have their own v2 value.

## Test coverage

The focused suite contains 13 tests covering:

- `null`, empty, and whitespace values
- malformed JSON and non-object values
- malformed versioned fields
- versioned-only serialization
- completion union
- maximum quiz score
- additive practice count
- idempotent merge of a separately decoded identical snapshot
- absent stored values
- save/load profile isolation
- exact stable-ID migration
- Little Stars legacy migration
- one-time migration into the first loading profile
- repeated load after the v2 key exists
- v2-first behavior after legacy data changes
- corrupt v2 behavior without legacy fallback
- typed persistence failure

## Exact commands and results

### TDD RED: required focused test

- `flutter test test/data/progress_store_test.dart -r expanded`
  - Initial result: failed during test loading because `lib/data/progress/progress_models.dart` and `lib/data/progress/progress_store.dart` did not exist.
  - This was the expected RED result from the brief.

### First implementation verification

- `flutter test test/data/progress_store_test.dart -r expanded`
  - Result: compile failure identified invalid field-formal parameters in a factory constructor and incorrect invocation of a private factory constructor.
  - Root cause: Dart only permits field-formal parameters in generative constructors, and factory constructors are invoked through the class name.
  - Fix: changed the factory parameters to ordinary parameters and invoked `ProgressSnapshot._fromJson` through the class name.

- `flutter test test/data/progress_store_test.dart -r expanded`
  - Result: 11 tests passed and one migration assertion failed.
  - The implementation correctly kept a quiz-only activity in `quizBestScores` but not `completedActivityIds`; the test incorrectly treated taking a quiz as activity completion.
  - Test expectation was corrected without changing production behavior.

### Profile-isolation self-review RED/GREEN

- `flutter test test/data/progress_store_test.dart -r expanded --plain-name "legacy progress migrates only into the first loading profile"`
  - RED result: failed with expected `0`, actual `3`, proving a second profile could re-migrate the retained legacy count.
  - Fix: added a one-time migration-complete marker after successful v2 migration.

- `flutter test test/data/progress_store_test.dart -r expanded --plain-name "legacy progress migrates only into the first loading profile"`
  - GREEN result: all 1 selected test passed.

### Formatting

- `dart format lib/data/progress/progress_models.dart lib/data/progress/progress_store.dart test/data/progress_store_test.dart`
  - Initial result: formatted 3 files successfully; 2 changed.
- `dart format lib/data/progress/progress_store.dart test/data/progress_store_test.dart`
  - Result: formatted 2 files successfully; 0 changed.
- `dart format --output=none --set-exit-if-changed lib/data/progress/progress_models.dart lib/data/progress/progress_store.dart test/data/progress_store_test.dart`
  - Final result: `Formatted 3 files (0 changed)`.

### Required focused test

- `flutter test test/data/progress_store_test.dart -r expanded`
  - Final result: all 13 focused progress tests passed.

### Analyzer

- `flutter analyze`
  - Final result: `No issues found!` (4.9s).

### Full regression suite

- `flutter test -r expanded`
  - Final result: all 27 tests passed, including 13 new progress tests, 12 Task 1 content tests, and 2 existing widget tests.

## Self-review

### Migration idempotence

- The first unmigrated profile reads `progress_json`, writes its v2 snapshot, then writes the migration marker.
- Any later load of that profile returns the existing v2 value before reading legacy data.
- Any later profile with no v2 value sees the migration marker and returns empty rather than copying legacy progress.
- The focused tests change the legacy value after first migration and prove that a repeated load still returns the original v2 practice count and completion set.
- The legacy value is never removed or rewritten.

### Repeated-load behavior

- Repeated sequential loads re-read the current v2 value, so externally replaced v2 data is observed.
- Repeated concurrent loads on the same `ProgressStore` share `_loading` and cannot launch two migrations for that store.
- Corrupt v2 data remains present and safely decodes to empty; migration does not silently overwrite it with legacy data.
- A separately decoded copy of the same snapshot merges without doubling its practice count.

### Code review outcome

- No Critical or Important implementation issues remain after the profile-isolation RED/GREEN fix.
- No security concerns were introduced; no secrets, personal data, logging, or network behavior were added.
- The implementation remains isolated from the legacy `ProgressStore` and existing app bootstrap, as required.

## Concerns and integration notes

- No blocking concerns.
- The required v2 schema has no separate Little Stars star count or practice-completion set. Legacy `littleStars` and `practicesCompleted` are safely read/validated, while migrated Little Stars completion IDs and aggregate `practiceCount` provide the v2 data. A later schema revision can add dedicated fields if product behavior requires them.
- Exact duplicate-snapshot detection is necessarily structural because the required schema has no revision/event identifier. Two genuinely distinct deltas that are identical in every stored field and have the same practice count cannot be distinguished; the implementation favors the explicit no-double-count requirement. A future server-sync schema should add stable event or revision IDs for exact accounting.
- The legacy value has no embedded owner. The first profile to load the unmigrated store receives it; the marker prevents subsequent profiles from inheriting that unscoped history. Task 4 should load the initial active/default profile during bootstrap.
- The migration marker is a separate internal SharedPreferences entry named `learning_progress_v2_migration_complete`; profile snapshots remain under the required `learning_progress_v2:<profileId>` keys.

## Fix round — Important review findings

### Status

FIX ROUND COMPLETE

### Findings addressed

1. **Cross-profile migration race**
   - Added a process-wide static migration queue using a shared `Future<void>` tail and `Completer<void>` release barrier.
   - Ordinary v2 loads still return before entering the migration queue.
   - The migration section re-reads both the requesting profile's v2 key and the global migration marker after acquiring the barrier, preventing a waiting store from acting on stale pre-lock state.
   - The barrier releases in `finally`, so failed reads, decoding, or writes cannot permanently block later migrations.
   - Added a concurrent regression test that starts `childA.load()` and `childB.load()` before awaiting either future. Child A receives the legacy snapshot and child B remains empty.

2. **Practice count double-counting**
   - Changed `ProgressSnapshot.merge()` from addition to `max(this.practiceCount, other.practiceCount)`.
   - Completion union, maximum quiz scores, latest practice day, and last-activity behavior are unchanged.
   - Direct local increments remain available through `copyWith(practiceCount: current + 1)` and are covered by the merge test.
   - Updated the merge test to require count `3` when merging snapshots with counts `2` and `3`, then verify `copyWith` can produce `4`.

3. **All-or-nothing legacy decoding**
   - Legacy completion lists now skip non-list values and malformed individual items while retaining valid stable IDs.
   - Legacy quiz maps now skip malformed keys, scores, and unstable IDs while retaining valid best scores.
   - Invalid or missing `totalPracticeSessions` values now safely produce `0` without discarding other valid migrated fields.
   - Invalid `lastPracticeDay` values now safely produce `null` without discarding valid progress.
   - Removed validation-only reads for discarded `practicesCompleted` and `littleStars` legacy fields.
   - Added a mixed malformed/valid migration fixture covering lesson completions, quiz scores, practice-list data, Little Stars completions, aggregate practice count, and practice day.

### Files changed in fix round

- Modified `lib/data/progress/progress_models.dart`
- Modified `lib/data/progress/progress_store.dart`
- Modified `test/data/progress_store_test.dart`
- Appended `.superpowers/sdd/2026-09-25-client-foundation/task-2-report.md`

`lib/main.dart` and the legacy `lib/progress_store.dart` were not changed. No Git commands were run and no agents were dispatched.

### Fix-round exact commands and results

#### Practice merge RED/GREEN

- `flutter test test/data/progress_store_test.dart -r expanded --plain-name "merge unions completions"`
  - RED result: failed with expected `3`, actual `5`, reproducing additive double-counting.
- `flutter test test/data/progress_store_test.dart -r expanded --plain-name "merge unions completions"`
  - GREEN result: all 1 selected test passed after switching merge to the maximum practice count.

#### Concurrent migration RED/GREEN

- `flutter test test/data/progress_store_test.dart -r expanded --plain-name "concurrent profile loads migrate legacy progress only once"`
  - RED result: failed with expected `0`, actual `3` for child B, reproducing cross-profile duplicate migration.
- `flutter test test/data/progress_store_test.dart -r expanded --plain-name "concurrent profile loads migrate legacy progress only once"`
  - GREEN result: all 1 selected test passed after adding the process-wide migration barrier and post-lock rechecks.

#### Defensive legacy parsing RED/GREEN

- `flutter test test/data/progress_store_test.dart -r expanded --plain-name "legacy migration skips malformed entries"`
  - RED result: failed because the expected valid completed-activity set was empty, reproducing all-or-nothing decoding.
- `flutter test test/data/progress_store_test.dart -r expanded --plain-name "legacy migration skips malformed entries"`
  - GREEN result: all 1 selected test passed after per-entry defensive parsing.

#### Formatter

- `dart format lib/data/progress/progress_models.dart lib/data/progress/progress_store.dart test/data/progress_store_test.dart`
  - Result: formatted 3 files successfully; 3 changed.
- `dart format --output=none --set-exit-if-changed lib/data/progress/progress_models.dart lib/data/progress/progress_store.dart test/data/progress_store_test.dart`
  - Final result: `Formatted 3 files (0 changed)` (0.04s).

#### Focused progress tests

- `flutter test test/data/progress_store_test.dart -r expanded`
  - Final result: all 15 focused progress tests passed.

#### Analyzer

- `flutter analyze`
  - Final result: `No issues found!` (6.3s).

#### Full Flutter tests

- `flutter test -r expanded`
  - Final result: all 29 tests passed, including 15 progress tests, 12 Task 1 content tests, and 2 existing widget tests.

### Fix-round self-review

- The static migration barrier is shared by all `ProgressStore` instances in the process, while each instance retains its ordinary `_loading` guard.
- A store waiting at the barrier rechecks state, so the second concurrent profile observes the migration marker and cannot copy legacy progress.
- The barrier always completes, including on exceptions, preventing a failed migration from deadlocking later stores.
- Merge no longer depends on structural duplicate detection to prevent count inflation; maximum-count semantics apply to every merge, including differently structured snapshots.
- `copyWith` remains the explicit mutation path for a locally recorded practice session.
- Legacy parsing preserves every valid destination-bearing entry and skips malformed siblings. Structurally corrupt JSON still produces an empty snapshot.
- The migration marker and retained `progress_json` behavior remain unchanged.

### Remaining concerns

- No blocking concerns.
- Because schema v2 has no practice event IDs, merge can safely retain only the larger absolute counter. Two genuinely independent offline increments that produce indistinguishable absolute snapshots cannot be added exactly; Task 4 must serialize local increments and persist each explicit `copyWith` increment.
- The migration barrier is process-wide, not cross-process or transactional with SharedPreferences. It closes the reported concurrent-store race in the Flutter app process, but a crash or marker-write failure between the v2 write and marker write can leave migration state requiring later operational review.
- `practicesCompleted` and `littleStars` remain intentionally discarded because schema v2 has no corresponding fields; malformed values in those discarded legacy fields no longer affect valid migration.
- The active application writer switch remains deliberately deferred to Task 4.
