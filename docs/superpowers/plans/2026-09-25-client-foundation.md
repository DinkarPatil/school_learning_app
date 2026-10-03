# Client Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the current monolithic Flutter shell with a tested, all-kids learning home that preserves the existing lessons and games, works offline, handles audio failures safely, and is usable with large text and small screens.

**Architecture:** Move stable learning data into a shared JSON catalog and expose it through a repository. Use a small `ChangeNotifier` application controller for navigation, progress, and service orchestration, with named routes and feature-focused screens. Keep authentication, cloud AI, and billing out of this phase so the result is independently testable and usable offline.

**Tech Stack:** Flutter, Dart, Material 3, `shared_preferences`, `audioplayers`, `flutter_tts`, JSON assets, `flutter_test`.

**Spec:** `docs/superpowers/specs/2026-09-25-all-kids-ai-learning-app-design.md`

## Global Constraints

- Keep one child-friendly home for all children; do not add an age gate.
- Make primary actions at least 64dp tall and essential targets at least 48dp.
- Use high-contrast text; never rely on color alone to communicate state.
- Make learning, games, and progress usable offline.
- Keep the OpenAI key, payment secrets, and future account credentials out of this phase and out of Flutter assets.
- Preserve English, Hindi, and Marathi content and existing valid audio assets.
- Never leave an audio button stuck in a loading or playing state after an error.
- Support larger system text and narrow Android layouts without clipped content.
- Do not add a package unless the existing dependency set cannot satisfy the task.
- Do not commit changes unless the user explicitly requests a commit.

## Review Focus

- Corrupt or legacy local progress: startup must recover safely and preserve valid progress.
- Missing or invalid audio asset: the activity must fall back to speech or a friendly message.
- Small screen with large text: primary actions and labels must remain visible and tappable.
- Rapid repeated taps: progress, audio, and completion actions must not duplicate state.
- Unknown or incomplete content IDs: navigation must show a recoverable empty state rather than throw.

---

## File Map

Create these focused files:

- `assets/content/catalog.json` — shared stable IDs and migrated lesson/game content.
- `lib/app/app.dart` — app composition and lifecycle.
- `lib/app/app_controller.dart` — navigation, active profile, progress, and service orchestration.
- `lib/app/router.dart` — named route definitions.
- `lib/app/theme.dart` — child-first theme tokens and accessible component themes.
- `lib/core/errors/app_failure.dart` — typed user-safe failures.
- `lib/core/audio/audio_service.dart` — injectable playback contract and implementation.
- `lib/core/speech/speech_service.dart` — injectable TTS contract and implementation.
- `lib/data/content/content_models.dart` — immutable content models.
- `lib/data/content/content_repository.dart` — asset loading and activity lookup.
- `lib/data/progress/progress_models.dart` — profile-scoped progress model and merge rules.
- `lib/data/progress/progress_store.dart` — versioned local persistence and legacy migration.
- `lib/features/home/home_screen.dart` — all-kids home.
- `lib/features/learning/subject_screen.dart` — subject and activity selection.
- `lib/features/learning/activity_screen.dart` — resumable lesson steps and completion.
- `lib/features/games/game_screen.dart` — adapters for migrated letter, number, word, and matching games.
- `test/data/content_repository_test.dart`
- `test/data/progress_store_test.dart`
- `test/core/audio_service_test.dart`
- `test/app/app_controller_test.dart`
- `test/features/home_screen_test.dart`
- `test/features/activity_screen_test.dart`

Modify these existing files:

- `pubspec.yaml` — register `assets/content/catalog.json` while preserving audio assets.
- `lib/main.dart` — reduce it to bootstrap and app construction.
- `test/widget_test.dart` — replace obsolete age-track expectations with foundation smoke tests.

Keep legacy `lib/catalog.dart`, `lib/little_catalog.dart`, and `lib/little_screens.dart` only as temporary migration references while the new repository is populated; remove them after the new screens pass their tests and the old routes are no longer referenced.

---

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

---

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

---

### Task 3: Isolate audio and speech behind recoverable services

**Files:**
- Create: `lib/core/audio/audio_service.dart`
- Create: `lib/core/speech/speech_service.dart`
- Test: `test/core/audio_service_test.dart`

**Interfaces:**
- `AudioService.playAsset(String path)` returns `Future<void>` and throws `AppFailure.audioUnavailable` on failure.
- `AudioService.stop()` is idempotent.
- `SpeechService.speak(String text, {String language = 'en-US'})` returns `Future<void>`.
- `SpeechService.stop()` is idempotent.
- Both services are injectable into the app controller.

- [ ] **Step 1: Write failing audio tests**

Use fake player and speech implementations to verify stop, completion, missing asset, and error reset:

```dart
test('failed playback leaves the service stopped', () async {
  final service = AudioService(playerFactory: _FailingPlayerFactory());

  await expectLater(
    service.playAsset('audio/missing.wav'),
    throwsA(isA<AppFailure>()),
  );
  expect(service.state, AudioPlaybackState.idle);
});
```

- [ ] **Step 2: Run the focused test and verify it fails**

Run: `flutter test test/core/audio_service_test.dart -r expanded`  
Expected: FAIL because the service contracts do not exist.

- [ ] **Step 3: Implement the audio state machine**

Wrap every `audioplayers` call in error handling. Set state to idle before and after failed playback, cancel subscriptions before replacing the player, and expose no raw plugin exception to child UI.

- [ ] **Step 4: Implement the TTS adapter and fallback helper**

Move the current TTS configuration into `SpeechService`, keep English/Hindi/Marathi language mapping, and provide `speakOrFallback(primaryText, fallbackText)` for missing lesson audio.

- [ ] **Step 5: Run the focused test and verify it passes**

Run: `flutter test test/core/audio_service_test.dart -r expanded`  
Expected: PASS.

---

### Task 4: Build the app controller, theme, router, and all-kids home

**Files:**
- Create: `lib/app/app_controller.dart`
- Create: `lib/app/theme.dart`
- Create: `lib/app/router.dart`
- Create: `lib/app/app.dart`
- Create: `lib/features/home/home_screen.dart`
- Modify: `lib/main.dart`
- Test: `test/app/app_controller_test.dart`
- Test: `test/features/home_screen_test.dart`
- Modify: `test/widget_test.dart`

**Interfaces:**
- `AppController.initialize()` loads content and progress once.
- `AppController` exposes `catalog`, `progress`, `activeClassId`, `activeSubjectId`, and `activeActivityId`.
- `AppController.openSubject(String subjectId)`, `openActivity(String activityId)`, and `completeActivity(String activityId)` update state and notify listeners.
- `AppDependencies` exposes an `AppController` plus `content`, `progress`, `audio`, and `speech` service interfaces; tests provide fakes for each service.
- `SchoolLearningApp` accepts an optional `AppDependencies` object for tests and uses production defaults otherwise.
- `AppRouter` owns route names `/`, `/subjects`, and `/activity`; the parent lock control shows a grown-ups-only notice until the account phase.

- [ ] **Step 1: Write failing controller and home tests**

Verify initialization, Continue learning, subject selection, activity selection, and the visible “Ask your teacher” affordance without requiring a network service:

```dart
testWidgets('home offers learning choices for every child', (tester) async {
  await tester.pumpWidget(SchoolLearningApp(dependencies: _testDependencies()));
  await tester.pumpAndSettle();

  expect(find.text('Continue learning'), findsOneWidget);
  expect(find.text('Choose a subject'), findsOneWidget);
  expect(find.text('Play and learn'), findsOneWidget);
  expect(find.text('Ask your teacher'), findsOneWidget);
});
```

- [ ] **Step 2: Run the focused tests and verify they fail**

Run: `flutter test test/app/app_controller_test.dart test/features/home_screen_test.dart -r expanded`  
Expected: FAIL because the new app shell does not exist.

- [ ] **Step 3: Implement the controller and dependency container**

Load content and progress concurrently during initialization. Expose typed `AppFailure` values for invalid content and corrupt progress. Serialize completion writes so rapid taps cannot overwrite newer progress.

- [ ] **Step 4: Implement the accessible theme**

Define ink, surface, primary, success, warning, and error tokens with readable contrast. Set minimum button sizes, rounded shapes, visible focus states, and a text theme that does not use fixed line heights for scaled content.

- [ ] **Step 5: Implement named routes and the home screen**

Create one scrollable home with large cards for Continue, Subjects, Games, and Teacher. Add a visible lock control for the parent route. Use `Semantics` labels and ensure every card has a minimum 64dp action height.

- [ ] **Step 6: Reduce `main.dart` to bootstrap**

Initialize bindings, create production dependencies, and run `SchoolLearningApp`. Remove the old manual `AppScreen` switch from the entry path.

- [ ] **Step 7: Run the focused tests and verify they pass**

Run: `flutter test test/app/app_controller_test.dart test/features/home_screen_test.dart test/widget_test.dart -r expanded`  
Expected: PASS.

---

### Task 5: Implement resumable subjects, activities, and migrated games

**Files:**
- Create: `lib/features/learning/subject_screen.dart`
- Create: `lib/features/learning/activity_screen.dart`
- Create: `lib/features/games/game_screen.dart`
- Test: `test/features/activity_screen_test.dart`
- Modify: `lib/app/router.dart`

**Interfaces:**
- `SubjectScreen` receives `AppController` through an inherited app scope.
- `ActivityScreen(activityId)` resolves content through `AppController`.
- `GameScreen(activityId)` adapts the existing letter, number, word, and matching content to the new route.
- Activity completion calls `AppController.completeActivity(activityId)` exactly once per completed activity.

- [ ] **Step 1: Write failing activity tests**

Cover subject selection, unknown activity, story step, quiz feedback, practice completion, audio fallback, and returning Home:

```dart
testWidgets('unknown activity shows a recoverable message', (tester) async {
  final dependencies = _testDependencies();
  await tester.pumpWidget(SchoolLearningApp(dependencies: dependencies));
  await tester.pumpAndSettle();

  dependencies.controller.openActivity('missing');
  await tester.pumpAndSettle();

  expect(find.text('Let us choose something else'), findsOneWidget);
  expect(find.text('Go home'), findsOneWidget);
});
```

- [ ] **Step 2: Run the focused test and verify it fails**

Run: `flutter test test/features/activity_screen_test.dart -r expanded`  
Expected: FAIL because the activity screens do not exist.

- [ ] **Step 3: Implement subject selection**

Render subject cards with unique icons, high-contrast labels, and activity progress. Use a responsive grid with wrapping constraints; do not use the old five-column number grid or fixed three-button game rows.

- [ ] **Step 4: Implement the resumable activity flow**

Render one step at a time: story/listen, flashcards, quiz, practice, and reward. Keep step state in the activity widget, save completion only after the final meaningful action, and provide a persistent Home action.

- [ ] **Step 5: Add visual quiz feedback**

Show a large success animation or a gentle retry state. Store quiz score through the controller’s serialized progress writer. Speak the result when speech is available.

- [ ] **Step 6: Adapt the existing games**

Render the migrated letter, number, word, find-letter, and match-case activities through `GameScreen`. Replace `Navigator.maybePop()` exits with an explicit route callback to the home/activity route.

- [ ] **Step 7: Run the focused test and verify it passes**

Run: `flutter test test/features/activity_screen_test.dart -r expanded`  
Expected: PASS.

---

### Task 6: Harden accessibility, responsive layout, and phase verification

**Files:**
- Modify: `lib/app/theme.dart`
- Modify: `lib/features/home/home_screen.dart`
- Modify: `lib/features/learning/subject_screen.dart`
- Modify: `lib/features/learning/activity_screen.dart`
- Modify: `lib/features/games/game_screen.dart`
- Modify: `test/widget_test.dart`
- Create: `test/features/accessibility_test.dart`

**Interfaces:**
- Primary actions retain a usable semantic label and 64dp minimum height at large text scale.
- The drawing pad exposes a semantic “Drawing area” label and a clear/reset action.
- Audio and teacher controls expose explicit labels and busy/disabled semantics.

- [ ] **Step 1: Write failing accessibility tests**

Use `MediaQuery` text scaling and a narrow surface size to assert that home and activity primary actions are visible and hittable. Assert semantics labels for the lock, teacher, audio, and drawing controls.

- [ ] **Step 2: Run the accessibility tests and verify they fail**

Run: `flutter test test/features/accessibility_test.dart -r expanded`  
Expected: FAIL until labels, responsive constraints, and fixed-height assumptions are removed.

- [ ] **Step 3: Fix fixed-height and contrast issues**

Replace fixed giant text and fixed game rows with `FittedBox`, `Wrap`, responsive grids, and scrollable content. Use dark ink on light surfaces and white only on sufficiently dark accent surfaces.

- [ ] **Step 4: Add semantic labels and focus order**

Wrap icon-only and custom controls in `Semantics`, add tooltips where icons are not accompanied by text, and ensure the parent lock cannot be reached accidentally from a game action.

- [ ] **Step 5: Run all Flutter verification commands**

Run: `dart format --set-exit-if-changed lib test`  
Expected: no formatting changes required.

Run: `flutter analyze`  
Expected: no errors or warnings.

Run: `flutter test`  
Expected: all tests pass.

Run: `flutter build apk --debug`  
Expected: a debug APK is produced successfully.

- [ ] **Step 6: Remove obsolete route references**

After the new tests pass, remove the old manual `AppScreen` router and age-specific Little Stars home from the active app path. Keep only migration data needed by the new content repository.

---

## Phase Boundary

This plan intentionally stops before parent authentication, cloud AI, or payment implementation. After this phase is verified, create separate approved plans for:

1. FastAPI auth, Neon persistence, parent PIN, child profiles, and progress sync.
2. OpenAI teacher endpoint, voice/text interaction, and lesson-scoped safety.
3. Razorpay-compatible checkout, subscriptions, webhooks, and entitlements.

Each later plan must preserve the interfaces introduced here and include its own tests, environment configuration, and security review.
