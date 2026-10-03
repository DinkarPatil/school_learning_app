# Task 4 Report

## Status

DONE

Task 4 replaced the active monolithic bootstrap with the injectable app shell, controller, theme, named routes, and all-kids home. The legacy Dart catalogs, legacy progress writer, and audio files remain present but are not referenced by the new active app path.

## Files changed

Created:

- `lib/app/app_controller.dart`
- `lib/app/theme.dart`
- `lib/app/router.dart`
- `lib/app/app.dart`
- `lib/features/home/home_screen.dart`
- `test/app/app_controller_test.dart`
- `test/features/home_screen_test.dart`
- `.superpowers/sdd/2026-09-25-client-foundation/task-4-report.md`

Modified:

- `lib/main.dart`
- `test/widget_test.dart`

No packages, `pubspec.yaml` entries, audio files, backend files, or legacy catalog/progress files were changed. No Git commands were run.

## Implementation summary

### Dependency composition and bootstrap

- Added `AppDependencies` with constructed `AppController`, `ContentRepository`, `ProgressStore`, `AudioService`, and `SpeechService` fields.
- Added `AppDependencies.production()` using `rootBundle`, the default `local-child` profile ID, the versioned `ProgressStore`, and the existing audio/speech adapters.
- Added `AppDependencies.fromParts()` for tests and composition roots.
- `SchoolLearningApp` accepts an optional `AppDependencies`; tests inject in-memory preferences, asset bundles, audio player factories, and speech engines.
- Reduced `lib/main.dart` to binding initialization, production dependency creation, and `runApp`.
- `AppDependencies` and the app module export the controller, router, and theme APIs for later feature tasks.

### App controller

- Added a `ChangeNotifier` controller with `initialize()`, `catalog`, `progress`, `activeClassId`, `activeSubjectId`, and `activeActivityId`.
- Content and progress load concurrently with `Future.wait`, and the initialization future is reused so each dependency loads once.
- Content and progress failures are exposed as typed `AppFailure.invalidContent` and `AppFailure.corruptProgress` values; successful parallel loads are retained when the other side fails.
- `openSubject`, `openActivity`, `resetSelection`, and activity lookup validate stable catalog IDs and notify listeners.
- `completeActivity` writes through a shared serialized write queue and is idempotent for an already-completed activity.
- `recordPractice` uses an explicit `copyWith(practiceCount: current + 1)` increment; `recordQuizScore` keeps the best score.
- Completion, practice, and quiz writes all use the versioned `ProgressStore`; no new write path targets `lib/progress_store.dart`.
- Existing `ProgressSnapshot.merge()` maximum-practice-count semantics remain unchanged.

### Theme and routes

- Added ink, surface, primary, success, warning, and error tokens.
- Added accessible Material 3 component themes with 64dp primary button minimums, rounded shapes, focus overlay states, and no fixed text line heights.
- Added named routes `/`, `/subjects`, and `/activity` through `AppRouter`.
- Added small subject/activity route shells with predictable back and Home actions and a recoverable unknown-activity state.
- The Play and learn route uses the migrated `class-0` activities; the normal subject picker does not create a second age-branded home.

### All-kids home

- Added one scrollable home with exactly the approved child choices:
  - Continue learning
  - Choose a subject
  - Play and learn
  - Ask your teacher
- Continue learning resumes `progress.lastActivityId` when valid and otherwise opens subject selection.
- The teacher affordance shows the child-safe message `Your teacher is coming next.`
- The small parent lock control shows `Grown-ups only` until the account phase.
- Cards use semantic labels, rounded surfaces, and minimum 88dp action heights.
- The new shell uses the injected audio/speech services and does not recreate the old global player lifecycle.

## Tests

- `test/app/app_controller_test.dart` covers one-time initialization, concurrent-load reuse, active selection, serialized/idempotent completion, explicit practice increments, and typed invalid-content/corrupt-progress failures.
- `test/features/home_screen_test.dart` covers the four approved home choices, subject/activity route shells, Continue learning, the teacher notice, and the parent lock notice.
- `test/widget_test.dart` is now an all-kids foundation smoke test using injected, plugin-free dependencies.

## TDD and debugging evidence

### RED

- `flutter test test/app/app_controller_test.dart test/features/home_screen_test.dart -r expanded`
  - Failed during test loading because the Task 4 app/controller/home files did not exist, as expected.
  - After correcting two test-helper nullability mistakes, the same command still failed only on the missing Task 4 implementation.

### Widget initialization investigation

- A first widget-test attempt exposed fake-async timing when the test awaited controller initialization inside the widget test zone.
- Root cause was test-zone scheduling around the asynchronous asset/progress load, not a production deadlock.
- The smoke test now initializes its injected controller with `tester.runAsync` before pumping the widget. No legacy progress writer is involved.

## Exact commands and results

### Focused tests

- `flutter test test/app/app_controller_test.dart test/features/home_screen_test.dart -r expanded`
  - Final result: all 10 tests passed.
- `flutter test test/app/app_controller_test.dart test/features/home_screen_test.dart test/widget_test.dart -r expanded`
  - Final result: all 11 tests passed.

### Full Flutter suite

- `flutter test -r expanded`
  - Final result: all 63 tests passed, including the existing content, progress, and audio/speech coverage plus 11 Task 4 controller, home, and smoke tests. No failures or warnings were reported by the test runner.

### Analyzer

- `flutter analyze`
  - Final result: `No issues found!` (3.0s).

### Formatter

- `dart format lib/app lib/features/home lib/main.dart test/app test/features test/widget_test.dart`
  - Formatted the changed files successfully.
- `dart format --output=none --set-exit-if-changed lib/app lib/features/home lib/main.dart test/app test/features test/widget_test.dart`
  - Final result: `Formatted 9 files (0 changed)`.
- `dart format --output=none --set-exit-if-changed lib test`
  - Result: exit code 1 because five pre-existing legacy files would be reformatted: `lib/catalog.dart`, `lib/little_catalog.dart`, `lib/little_player.dart`, `lib/little_screens.dart`, and `lib/models.dart`.
  - Those legacy files were intentionally not modified. The scoped changed-file formatter check is clean.

## Concerns and follow-up notes

- The full-tree formatter check remains red only because untouched legacy files predate the current formatter style. Reformatting or removing those files is deferred until the migration/rollback window closes.
- The subject and activity routes are intentionally small shells. Task 5 should replace them with the resumable subject/activity/game screens while preserving the controller contracts and route names.
- The teacher control is a local coming-next notice in this phase; no cloud, account, or AI service is wired.
- Production `rootBundle` loading and the versioned `ProgressStore` are wired, but device-level plugin integration was not exercised in this task. Task 4 tests use injected adapters and in-memory preferences only.
- `AppController.initialize()` is single-shot by design. A future retry/repair flow can add an explicit reset/retry operation without changing the current service boundaries.
- The new shell does not display a dedicated startup-error screen yet; typed failures are available through the controller and the home remains recoverable. Task 5/6 can add the child-safe retry presentation.

## Verification checklist

- [x] New app shell replaces the active manual `AppScreen` bootstrap.
- [x] Production dependencies use `rootBundle`, `local-child`, and the v2 store.
- [x] Widget tests inject fakes and do not require platform plugins.
- [x] Completion writes are serialized and idempotent.
- [x] Local practice increments use explicit `copyWith` changes.
- [x] Home shows only the approved all-kids choices plus the parent lock.
- [x] No packages, audio files, backend files, or legacy active writes were added.
- [x] Focused tests, full suite, analyzer, and scoped formatter verification completed.

## Fix round — review findings

### Status

FIX ROUND COMPLETE

### Findings addressed

1. **Navigation state leak**
   - Generic subject entry now clears `activeClassId`, `activeSubjectId`, and `activeActivityId` before navigating.
   - The router also clears selection for a generic `/subjects` entry, so the route is deterministic even when reached directly.
   - Added a regression test that visits Play and learn, selects a game, returns Home, opens Choose a subject, and verifies `Little Stars` is absent.

2. **Class reachability and magic class sentinel**
   - Removed the `class-0` literal and the controller’s implicit default-class selection.
   - Generic subject activity lists now show all activities for the selected subject, including Class 1 and Class 2.
   - Games are identified by the `little` subject rather than a class sentinel.
   - Added Class 2 content to the shell fixture and asserted both class activities are available.

3. **Touch targets**
   - Raised the text-button minimum to 64dp.
   - Constrained Home, back, and parent-lock controls to 64dp targets, including an AppBar leading width/toolbar height adjustment.
   - Added widget assertions for the parent lock, Home escape control, and back control.

4. **Completion failure handling**
   - Added `completeActivityIfNeeded()` to report whether a write occurred while preserving the existing `completeActivity()` API.
   - The activity shell catches `AppFailure`, shows `We could not save that yet. Please try again.`, and leaves the action available for retry.
   - Completed activities disable the action and do not show `Activity saved.` for an idempotent no-op.
   - Added a shared failing progress-store fake plus controller and widget coverage.

5. **Route-name ownership**
   - Added leaf file `lib/app/route_names.dart`.
   - `AppRouter` retains its public constants as aliases, and the home screen now uses `RouteNames` instead of hardcoded route strings.
   - Existing route behavior and names remain unchanged.

6. **Smoke-test injection**
   - Extracted shared audio player and speech engine fakes to `test/support/fakes.dart`.
   - `test/widget_test.dart` now injects those fakes and pre-initializes through `tester.runAsync` before pumping.

7. **Semantics**
   - Merged card semantics into one label containing title and meaningful subtitle, with descendant semantics excluded to remove duplicates.
   - Kept explicit semantic labels and actions for the parent lock and back control.
   - Teacher remains an explicit labeled learning choice; no audio control is introduced in this shell phase.

### Files changed in fix round

Created:

- `lib/app/route_names.dart`
- `test/support/fakes.dart`

Modified:

- `lib/app/app_controller.dart`
- `lib/app/router.dart`
- `lib/app/theme.dart`
- `lib/app/app.dart`
- `lib/features/home/home_screen.dart`
- `test/app/app_controller_test.dart`
- `test/features/home_screen_test.dart`
- `test/widget_test.dart`
- `.superpowers/sdd/2026-09-25-client-foundation/task-4-report.md`

No legacy files were removed or modified. No audio files, backend files, packages, or full-tree formatter scope were changed.

### Exact fix-round commands and results

- `flutter test test/app/app_controller_test.dart test/features/home_screen_test.dart test/widget_test.dart -r expanded`
  - RED phase before production fixes: failed on the new regression expectations for class reachability, subject reset, 64dp targets, merged semantics, and completion failure handling.
  - Final result: all 17 focused shell/smoke tests passed.
- `flutter test test/app/app_controller_test.dart test/features/home_screen_test.dart -r expanded`
  - Final result: all 16 controller and home tests passed.
- `flutter test -r expanded`
  - Final result: all 69 Flutter tests passed.
- `flutter analyze`
  - Final result: `No issues found!` (3.0s).
- `dart format --output=none --set-exit-if-changed lib/app lib/features/home lib/main.dart test/app test/features test/support test/widget_test.dart`
  - Final result: `Formatted 11 files (0 changed)`.

The full-tree formatter scope was intentionally not run or changed in this fix round.

### Remaining concerns

- Subject and activity routes remain small shells; Task 5 must add the class-aware learning flow and activity UI while preserving the deterministic generic subject entry.
- The generic subject list intentionally exposes all class activities until the later class-selection UX is implemented.
- `completeActivity()` remains the compatible `Future<void>` API; `completeActivityIfNeeded()` is the shell’s outcome-reporting path.
- No audio control exists in the Task 4 shell yet; the later activity screen must provide an explicit semantic audio label when it is added.
- Device-level plugin integration was not run; all fix-round tests use injected fakes and in-memory progress preferences.
- The pre-existing full-tree formatter caveat for untouched legacy files remains unchanged.
