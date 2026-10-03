# Task 4 Review Package

## Review mode

No Git metadata exists in this workspace. Inspect the listed files directly; do not modify them or run broad test suites.

## Files under review

- `lib/app/app_controller.dart`
- `lib/app/theme.dart`
- `lib/app/router.dart`
- `lib/app/app.dart`
- `lib/features/home/home_screen.dart`
- `lib/main.dart`
- `test/app/app_controller_test.dart`
- `test/features/home_screen_test.dart`
- `test/widget_test.dart`

## Claims to verify

- Production bootstrap uses the v2 profile-scoped store and no longer routes active writes to the legacy store.
- AppDependencies injects all services and the controller for plugin-free tests.
- Controller initialization, selection, serialized/idempotent completion, and explicit practice increments are correct.
- Home has the approved all-kids choices, accessible large actions, teacher notice, and parent lock notice.
- Named routes have predictable back/Home behavior and unknown-activity recovery.
- No legacy age-specific home or old player lifecycle is reintroduced.

## Evidence

The implementer reports focused, smoke, full-suite, analyzer, and scoped formatter results in `task-4-report.md`. The full-tree formatter warning is expected to be revisited in Task 6.
