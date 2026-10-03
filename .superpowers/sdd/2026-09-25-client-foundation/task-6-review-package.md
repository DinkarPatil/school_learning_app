# Task 6 Review Package

## Review mode

No Git metadata exists in this workspace. Inspect the current files directly and use the report’s deleted-file list; do not modify files or run broad test suites.

## Files under review

- `lib/app/theme.dart`
- `lib/app/router.dart`
- `lib/app/app.dart`
- `lib/app/app_scope.dart`
- `lib/features/home/home_screen.dart`
- `lib/features/learning/learning_shell.dart`
- `lib/features/learning/subject_screen.dart`
- `lib/features/learning/activity_screen.dart`
- `lib/features/games/game_screen.dart`
- `test/features/accessibility_test.dart`
- `test/widget_test.dart`
- `test/data/content_repository_test.dart`
- `test/support/legacy_little_catalog.dart`
- `test/support/fakes.dart`

## Deleted files claimed

- `lib/catalog.dart`
- `lib/models.dart`
- `lib/progress_store.dart`
- `lib/little_catalog.dart`
- `lib/little_player.dart`
- `lib/little_screens.dart`

## Claims to verify

- Large text and narrow surfaces keep primary actions visible, 64dp, and hittable.
- Semantics labels, live regions, and busy/disabled states are accurate.
- No legacy source/test references remain; the content parity oracle is frozen and self-contained.
- Activity save retries, quiz exit persistence, AppScope notifications, and class-chip behavior remain intact.
- Route names and Home/back behavior still work.
- Game completion feedback and drawing/audio accessibility are present.
- No unrelated files, packages, or audio assets changed.

## Evidence

The implementer reports full formatter, analyzer, 127-test, focused accessibility/content/widget, and debug APK results in `task-6-report.md`.
