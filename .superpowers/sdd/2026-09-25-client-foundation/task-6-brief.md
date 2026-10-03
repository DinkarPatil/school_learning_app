### Task 6: Harden accessibility, responsive layout, and phase verification

**Files:**
- Modify: `lib/app/theme.dart`
- Modify: `lib/features/home/home_screen.dart`
- Modify: `lib/features/learning/subject_screen.dart`
- Modify: `lib/features/learning/activity_screen.dart`
- Modify: `lib/features/games/game_screen.dart`
- Modify: `lib/app/router.dart`
- Modify: `lib/app/app_scope.dart`
- Modify: `test/widget_test.dart`
- Modify: `test/data/content_repository_test.dart`
- Create: `test/features/accessibility_test.dart`

**Interfaces:**
- Primary actions retain a usable semantic label and 64dp minimum height at large text scale.
- The drawing pad exposes a semantic “Drawing area” label and a clear/reset action.
- Audio and teacher controls expose explicit labels and busy/disabled semantics.

- [ ] **Step 1: Write failing accessibility tests**

Use `MediaQuery` text scaling and a narrow surface size to assert that home and activity primary actions are visible and hittable. Assert semantics labels for the lock, teacher, audio, class chips, and drawing controls.

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

- [ ] **Step 6: Remove obsolete route and legacy references**

After the new tests pass, remove the old manual `AppScreen` router, unused `AppRouter.routes`/legacy route argument APIs, and unreferenced legacy `lib/catalog.dart`, `lib/little_catalog.dart`, `lib/little_player.dart`, `lib/little_screens.dart`, `lib/models.dart`, and `lib/progress_store.dart` files. Before deleting `lib/little_catalog.dart`, move its content-parity oracle into a frozen test fixture so the catalog regression test remains self-contained. Verify no active source imports a removed file.
