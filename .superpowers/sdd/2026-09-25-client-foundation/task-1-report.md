# Task 1 Report

## Status

DONE

## Files changed

- Created `assets/content/catalog.json`
- Created `lib/core/errors/app_failure.dart`
- Created `lib/data/content/content_models.dart`
- Created `lib/data/content/content_repository.dart`
- Created `test/data/content_repository_test.dart`
- Modified `pubspec.yaml`

No audio files or legacy Dart catalogs were modified. No packages were added.

## Implementation summary

- Added `AppFailure` with typed `invalidContent`, `corruptProgress`, and `audioUnavailable` failures.
- Added immutable content types with `const` constructors and JSON factories:
  - `ActivityType`
  - `FlashcardContent`
  - `QuizContent`
  - `ActivityContent`
  - `SubjectContent`
  - `ContentCatalog`
- JSON factories eagerly validate field types, defensively copy lists/maps, expose unmodifiable collections, and validate quiz answer indexes.
- Added `ContentRepository` with required constructor-injected `AssetBundle` injection and the default `assets/content/catalog.json` path.
- Repository behavior includes:
  - Cached catalog reuse, including in-flight load reuse.
  - Constant-time `activityById` lookup.
  - `null` for unknown IDs.
  - Typed `AppFailure.invalidContent` for JSON, schema, semantic, duplicate-ID, unknown-reference, and stable-ID failures.
  - Validation that every activity ID matches and agrees with `class-{n}-subject-{subject-id}-activity-{activity-id}`.
- Migrated version 1 content into shared JSON:
  - Five numbered classes (`class-1` through `class-5`).
  - Nine class subjects across five levels, for 45 class activities.
  - Three flashcards, three quiz questions, story, practice prompt/hint, and existing lesson audio path per class activity.
  - Existing valid flashcard audio paths where present; no missing English third-card path was invented.
  - Six Little Stars activities for capitals, smalls, numbers, find-letter, match-case, and first words, including all existing letter/number/word translations.
  - Title/story translations for every activity without inventing new cross-language lesson translations.
- Registered only `assets/content/catalog.json` while preserving both existing audio asset directories.
- Added tests using an injected `AssetBundle` stub for loading, stable lookup, language lookup, missing IDs, caching, malformed JSON, unstable IDs, invalid ID characters, defensive copying, migration counts, stable formats, and lesson-audio existence.

## Commands and results

### TDD RED

1. `flutter test test/data/content_repository_test.dart -r expanded`
   - Result: failed during test loading because `app_failure.dart`, `content_models.dart`, and `content_repository.dart` did not exist, as expected.
2. `flutter test test/data/content_repository_test.dart -r expanded --plain-name "rejects characters outside the stable id format"`
   - Result: failed because the repository emitted a `ContentCatalog` instead of `AppFailure.invalidContent`, proving the invalid stable-ID suffix gap.

### Formatting

- `dart format lib/core/errors/app_failure.dart lib/data/content/content_models.dart lib/data/content/content_repository.dart test/data/content_repository_test.dart`
  - Result: formatted 4 files successfully.
- `dart format --output=none --set-exit-if-changed lib/core/errors/app_failure.dart lib/data/content/content_models.dart lib/data/content/content_repository.dart test/data/content_repository_test.dart`
  - Final result: `Formatted 4 files (0 changed)`.

### Analyzer

- Initial `flutter analyze`
  - Result: one `unnecessary_import` lint for `dart:typed_data` in the new test.
- Final `flutter analyze`
  - Result: `No issues found!` (5.8s).

### Focused required test

- `flutter test test/data/content_repository_test.dart -r expanded`
  - Final result: all 7 repository/catalog tests passed.

### Full regression suite

- `flutter test -r expanded`
  - Final result: all 9 tests passed, including the 7 new tests and 2 existing widget tests.

## Self-review and concerns

- No blocking concerns.
- The brief's sample ID (`class-1-english-activity-story`) conflicts with the explicit required format in the task instructions. The explicit format was treated as authoritative, so the implementation and tests use `class-1-subject-english-activity-story`. Later tasks must use the full format.
- Little Stars uses `class-0` as an internal non-numbered-track sentinel so all six game IDs still satisfy the required numeric stable-ID format. The five real numbered classes remain `class-1` through `class-5`; later UI should not present `class-0` as a numbered class.
- The repository converts malformed asset reads and all detected content defects to `AppFailure.invalidContent`; internal causes remain available through `AppFailure.cause` while `toString()` remains child-safe.
- The task remained in scope: legacy catalog files were left unchanged for later migration/removal work, and no unrelated application files were edited.

## Fix round — review findings

### Findings addressed

- Restored all four duplicated Little Stars Ice cream records to the exact legacy values `Ice cream 🍦 | आइसक्रीम | आईस्क्रीम` in the capitals, smalls, find-letter, and match-case activities.
- Restored all first-word values to their exact legacy uppercase spelling. The current workspace already contained the correct `PEN 🖊️` emoji; the new parity test now locks that value against `LittleCatalog.words` so it cannot drift to `✏️` or another value.
- Added a full parity test covering every legacy letter across all four duplicated letter activities, every number, and every first word, including exact emoji, Hindi, and Marathi values.
- Changed required JSON strings to reject empty or whitespace-only values with `FormatException`; optional strings remain unchanged and may still be empty.
- Added repository semantic validation for nonblank primary activity titles and nonblank stories on `ActivityType.story` activities. These failures continue through the existing repository wrapper as `AppFailure.invalidContent`.
- Added a characterization test proving non-story activities may still have empty `story` and `audioAsset` fields.

### Fix-round files changed

- Modified `assets/content/catalog.json`
- Modified `lib/data/content/content_models.dart`
- Modified `lib/data/content/content_repository.dart`
- Modified `test/data/content_repository_test.dart`
- Appended `.superpowers/sdd/2026-09-25-client-foundation/task-1-report.md`

`lib/little_catalog.dart`, all audio files, and all other legacy sources remain unchanged.

### Fix-round commands and results

#### TDD RED evidence

- `flutter test test/data/content_repository_test.dart -r expanded --plain-name "Little Stars values exactly match the legacy catalog"`
  - First result: failed because actual JSON used `Ice cream 🍨 | आइसक्रीम | आइसक्रीम` instead of the legacy `Ice cream 🍦 | आइसक्रीम | आईस्क्रीम`.
  - After the Ice cream correction: failed because first-word backs were title-cased (`Cat`) instead of exact legacy uppercase (`CAT`), proving the parity test also caught casing drift.
- `flutter test test/data/content_repository_test.dart -r expanded --plain-name "rejects a blank primary activity title"`
  - Result: failed because the repository emitted a `ContentCatalog` instead of `AppFailure.invalidContent`.
- `flutter test test/data/content_repository_test.dart -r expanded --plain-name "rejects a blank story for story activities"`
  - Result: failed because the repository emitted a `ContentCatalog` instead of `AppFailure.invalidContent`.
- `flutter test test/data/content_repository_test.dart -r expanded --plain-name "allows empty story and audio for non-story activities"`
  - RED-phase result: passed, confirming optional empty fields were already valid and had to remain so.
- `flutter test test/data/content_repository_test.dart -r expanded --plain-name "content factory rejects blank required strings"`
  - Result: failed because `ContentCatalog.fromJson` returned a catalog for a whitespace-only required title.

#### Formatting

- `dart format lib/data/content/content_models.dart lib/data/content/content_repository.dart test/data/content_repository_test.dart`
  - Result: formatted 3 files successfully; 2 changed.
- `dart format --output=none --set-exit-if-changed lib/data/content/content_models.dart lib/data/content/content_repository.dart test/data/content_repository_test.dart`
  - Final result: `Formatted 3 files (0 changed)`.

#### Required focused tests and analyzer

- `flutter test test/data/content_repository_test.dart -r expanded`
  - Final result: all 12 focused repository/catalog tests passed.
- `flutter analyze`
  - Final result: `No issues found!` (4.3s).

#### Full regression suite

- `flutter test -r expanded`
  - Final result: all 14 tests passed, including 12 repository/catalog tests and 2 existing widget tests.

### Fix-round remaining concerns

- No blocking concerns.
- The new exact-content parity test intentionally imports `lib/little_catalog.dart` as its migration oracle. When the later rewrite removes the legacy catalog, this test must be moved to an equivalent frozen fixture or removed in the same task; it should not be allowed to remain broken.
- The previously reported stable-ID format and `class-0` Little Stars sentinel decisions remain unchanged.
