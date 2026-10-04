# Phase 1 Hardening Report

Plan: `docs/superpowers/plans/2026-09-25-client-foundation.md`
Ledger: `.superpowers/sdd/2026-09-25-client-foundation/progress.md`
Predecessor: `final-fix-report.md`

Wave: close the seven minor findings the Phase 1 reviews deferred, before starting
Phase 2. Each finding was measured first; three turned out to be real defects, one
was a real defect only in part, two were dismissed with evidence, and one was a
test-harness limitation that is documented rather than fixed.

Execution mode: in-place filesystem fallback, then a normal Git commit and push to
`DinkarPatil/school_learning_app`. The repository now has Git metadata, so this
wave is a real commit.

## Findings triaged

| Finding | Verdict | Outcome |
|---|---|---|
| `AppTheme.maxTextScale` cap | **real defect** | fixed, F1 |
| Shared breakpoint at desktop widths | **real defect** | fixed, F2 |
| Non-scrollable action bar | **real defect** | fixed, F3 |
| Silent save-timeout messaging | **real defect** | fixed, F4 |
| Duplicate/deferred route APIs | **real defect** | fixed, F5 |
| Pointer-only drawing pad | **partial defect** | improved, F6 |
| Ahem-font ceiling on painted-text assertions | **not a product defect** | documented, D7 |

## F1 — The app bar clipped its own title at large text (real defect)

`lib/app/theme.dart`

`toolbarHeight` clamped the text scale at `maxTextScale = 2.0`:

```dart
baseToolbarHeight * math.min(_textScale(context), maxTextScale)
```

Past 2x the toolbar stopped growing while the title kept scaling, so the title was
cut off. Measured before the fix at 360x640:

| Scale | App bar | Title height | Clipped |
|---|---|---|---|
| 1.0 | 72 | 64 | no |
| 2.0 | 144 | 192 | **yes** |
| 3.0 | 144 | 384 | **yes** |

The clamp was well intentioned (stop the bar eating the screen) but it traded
correctness for space. The toolbar now scales with the real text scale. The
`scaffold` loses the extra height at extreme scales instead of hiding the title,
and `LearningStepBody` now caps the action bar (F3) so the content area keeps a
usable share.

`maxTextScale` is removed. `LearningScaffold` keeps `maxLines: 2` on the title, so
the title height is bounded at any scale.

## F2 — Cards stretched the full width of a desktop screen (real defect)

`lib/features/learning/learning_shell.dart`, `home_screen.dart`

Measured on a 1440x900 surface, every home card was **1400dp** wide. Nothing in the
layout responded to wide viewports.

Added `ContentWidthLimiter` and applied it to the home list and to
`LearningStepBody` (both the scrolling content and the action bar). Reading content
is capped at `kMaxContentWidth = 640` and centred.

The limiter engages only above `kWideSurfaceThreshold = 900`. This matters: an
earlier attempt capped unconditionally at 640, which changed text wrapping even on
the 800dp test surface and pushed the last home card below the fold, breaking nine
existing tests. The finding was specifically about desktop widths, so phones and
small tablets now render exactly as before.

## F3 — The action bar could outgrow the body (real defect)

`lib/features/learning/learning_shell.dart`

Task 6 measured the reward action bar at **305dp against a 191dp body** at 2x text
on 320x640, and left it alone because adding a second `Scrollable` broke
`activity_screen_test.dart`'s `scrollUntilVisible(scrollable: find.byType(Scrollable))`,
which requires exactly one match. That blocker was a fragile test helper, not a
design constraint.

- `LearningActionBar` is now capped at 40% of the screen height (floor of one
  action row) and scrolls internally when the actions overflow.
- The over-constrained test helper now targets `find.byType(Scrollable).first`.

## F4 — A save that timed out told the child nothing (real defect)

`lib/features/learning/activity_screen.dart`, `lib/features/games/game_screen.dart`

`_settle` wrapped the save in `.timeout(kSaveTimeout)` and swallowed every error,
including `TimeoutException`. A child whose quiz save stalled simply navigated on
with their score silently lost and no message anywhere.

`_settle` now takes an `onTimeout` callback, and both screens report it through a
child-safe, shared message:

```dart
const String kSaveTimeoutMessage =
    'Saving is taking too long. Your stars may not be saved yet.';
```

The activity screen shows it as an app-level `SnackBar` (which survives both a step
change and a route change) and records `_quizError` so it is still visible if the
child returns to the quiz step. The game screen shows the `SnackBar` and records
`_saveError` on the reward step. The inline-only approach was tried first and was
wrong: `_leaveQuiz` changes step immediately after the timeout, so an inline-only
message was never seen.

## F5 — Four dead navigation callbacks on HomeScreen (real defect)

`lib/features/home/home_screen.dart`

`HomeScreen` accepted `onContinue`, `onOpenSubjects`, `onOpenGames`, and `onTeacher`.
No caller in `lib/` or `test/` ever passed any of them; each existed only to be
consulted and then fall through to the default behaviour. Removed, along with the
two branches that checked them.

## F6 — The drawing pad was opaque to assistive technology (partial defect)

`lib/features/learning/activity_screen.dart`

The pad announced only "Drawing area" with no state, and offered a single
always-enabled "Clear drawing". A screen-reader user could not tell whether a mark
registered, and could only erase everything, never undo.

- The pad's semantic `value` now reports `Nothing drawn yet` / `1 line drawn` /
  `N lines drawn`.
- Added "Undo last line".
- Both buttons are disabled, in semantics and visually, until there is a stroke to
  act on — matching how `_OptionCard` already reports state.

Pointer drawing itself is unchanged. Drawing a freehand mark with a keyboard or
switch is not solvable without a fundamentally different interaction, and the
practice step is completable without drawing, so this closes the observability gap
rather than pretending full parity.

## D7 — The Ahem-font ceiling is a test-harness limit, not a defect

`flutter test` substitutes the Ahem font, whose glyphs are about 1.1 em wide. The
painted-text fit oracle therefore cannot run at 2x on a 320-360dp surface: an
eight-character 22dp title needs roughly 352dp at 2x. The oracle runs at 1.3x/360dp,
which corresponds to roughly 2.5x in Roboto, while the visibility, 64dp, and
semantics assertions run at 2x/320dp.

Fixing this literally needs a real font bundled into the test assets, which is
outside Phase 1 scope and would change every text measurement in the suite. Left
documented rather than worked around.

## Files changed

Production:

- `lib/app/theme.dart` — removed `maxTextScale`; the toolbar scales with real text.
- `lib/features/learning/learning_shell.dart` — added `ContentWidthLimiter`, `kMaxContentWidth`, `kWideSurfaceThreshold`, `kSaveTimeoutMessage`; capped the action bar; applied the limiter to the step body.
- `lib/features/home/home_screen.dart` — wrapped the list in `ContentWidthLimiter`; removed the four dead callbacks.
- `lib/features/learning/activity_screen.dart` — timeout reporting; drawing pad `value`; "Undo last line"; disabled-when-empty buttons.
- `lib/features/games/game_screen.dart` — timeout reporting.

Tests:

- `test/features/accessibility_test.dart` — new `wide surfaces and large text` group (5 tests: app bar scaling to 4x, desktop cap and centring, phone width untouched, action bar cap, drawing pad state/undo); updated the drawing-pad semantics test for the corrected disabled state; added the `_drawOneLine` helper.
- `test/features/activity_screen_test.dart` — 3 new stalled-save tests (quiz step, activity exit, game exit); scoped `scrollUntilVisible` to the first scrollable.

No packages added. No comments added to production code beyond the two that record
*why* a non-obvious value or guard exists (`ContentWidthLimiter`, `cache: false`
from the previous wave).

## Verification

Run in `D:\Mobile Application\School Application\School`.

```text
> dart format --set-exit-if-changed lib test
Formatted 33 files (0 changed) in 0.15 seconds.
(exit 0)

> flutter analyze
Analyzing School...
No issues found! (ran in 3.0s)

> flutter test --timeout 90s
00:28 +167: All tests passed!

> flutter build apk --debug
Running Gradle task 'assembleDebug'...                             20.4s
√ Built build\app\outputs\flutter-apk\app-debug.apk
```

- Tests: 159 -> 167 passing, 0 failing. 8 added, 0 removed.
- APK: `build/app/outputs/flutter-apk/app-debug.apk`, `2026-10-04 05:32:23`,
  210,698,297 bytes (200.94 MB).

## Remaining concerns

1. At extreme text scales the app bar now grows without an upper bound. That is
   correct behaviour (no clipping) but on a short screen at 4x the app bar plus the
   capped action bar leave a small content area. The content still scrolls. If this
   matters, the fix is a scrollable app bar, not a clamp.
2. The action bar scrolls internally when it overflows. Below 2x text on a phone it
   never overflows, so this is a safety net rather than a common path.
3. `ContentWidthLimiter` leaves phone and small-tablet layouts byte-identical, so
   the desktop behaviour has only synthetic-widget coverage. It has not been
   checked on a physical tablet or desktop build.
4. Drawing remains pointer-only; see F6.
5. Phase 2 has not started. It requires a FastAPI service, a database, and a
   migration story for the existing local progress keys.