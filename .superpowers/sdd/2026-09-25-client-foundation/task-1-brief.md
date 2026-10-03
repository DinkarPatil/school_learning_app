### Task 1: Create the shared content catalog and repository

**Files:**
- Create: `assets/content/catalog.json`
- Create: `lib/data/content/content_models.dart`
- Create: `lib/data/content/content_repository.dart`
- Create: `lib/core/errors/app_failure.dart`
- Test: `test/data/content_repository_test.dart`
- Modify: `pubspec.yaml:21-25`

**Interfaces:**
- `ContentRepository.load(AssetBundle bundle)` returns `Future<ContentCatalog>`.
- `ContentRepository.activityById(String id)` returns `ActivityContent?`.
- `ContentCatalog.activities` is a `List<ActivityContent>`.
- `ActivityContent` exposes `id`, `classId`, `subjectId`, `title`, `activityType`, `story`, `flashcards`, `questions`, `practicePrompt`, `practiceHint`, `audioAsset`, and `translations`.
- Stable IDs use `class-{n}-subject-{subject-id}-activity-{activity-id}`.

- [ ] **Step 1: Write failing repository tests**

Create tests that load a small test catalog through an injected `AssetBundle` stub and verify stable IDs, activity lookup, language lookup, and missing IDs:

```dart
test('loads activities and finds them by stable id', () async {
  final repository = ContentRepository(bundle: _catalogBundle());
  final catalog = await repository.load();
  final activity = repository.activityById('class-1-english-activity-story');

  expect(activity, isNotNull);
  expect(activity!.subjectId, 'english');
  expect(activity.translations['hi'], isNotEmpty);
  expect(repository.activityById('missing'), isNull);
});
```

- [ ] **Step 2: Run the focused test and verify it fails**

Run: `flutter test test/data/content_repository_test.dart -r expanded`  
Expected: FAIL because the content repository and models do not exist.

- [ ] **Step 3: Add immutable content models**

Implement `ActivityType`, `FlashcardContent`, `QuizContent`, `ActivityContent`, `SubjectContent`, and `ContentCatalog` with `const` constructors, `fromJson` factories, defensive list copying, and no widget dependencies.

- [ ] **Step 4: Add JSON asset loading and lookup**

Implement `ContentRepository` with `rootBundle` injected through a constructor. Reject malformed catalogs with `AppFailure.invalidContent`, cache the loaded catalog, and return `null` for unknown IDs instead of throwing.

- [ ] **Step 5: Migrate the existing catalog into `catalog.json`**

Preserve all five classes, nine class subjects, five class levels, stories, three flashcards, three quiz questions, practice prompts, and the six existing letter/number/word/game activities. Use the existing audio paths without changing the files.

- [ ] **Step 6: Register the content asset and run the test**

Run: `flutter test test/data/content_repository_test.dart -r expanded`  
Expected: PASS.
