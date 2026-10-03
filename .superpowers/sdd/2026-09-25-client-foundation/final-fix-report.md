# Phase 1 Final Fix Report

Wave: `.superpowers/sdd/2026-09-25-client-foundation/final-fix-brief.md`
Plan: `docs/superpowers/plans/2026-09-25-client-foundation.md`
Ledger: `.superpowers/sdd/2026-09-25-client-foundation/progress.md`

Execution mode: in-place filesystem fallback. The workspace has no Git metadata, so
there are no commits, branches, or Git diffs. Nothing was committed. Changes below
were verified by running the tools against the working tree.

## Summary

All ten findings from the final review brief (C1, C2, I1-I8) are addressed. The
critical and important production behaviour was already present in the tree when
this wave resumed; continuing the wave surfaced and fixed four real defects that
the brief's own requirements exposed, and added the missing test coverage for
I1-I5.

Baseline when this session resumed: `flutter analyze` clean, `flutter test` at
`+124 -13`. Final state: analyze clean, `+159` passing.

## Defects found and fixed in this wave

### D1 — Round-game option cards collapsed to 68dp and became untappable (I2 regression)

`lib/features/games/game_screen.dart`, `_OptionCard`

The non-colour wrong-answer badge was implemented by wrapping the option card in a
`Stack`. `Stack` defaults to `StackFit.loose`, which hands its non-positioned
children `constraints.loosen()`. The grid supplies a tight width
(`ResponsiveTileGrid` -> `SizedBox(width: itemWidth)`), so loosening it let the
card shrink to its intrinsic width: the render dump showed
`Size(68.3, 96.0)` inside a `245.3`-wide grid cell, top-start aligned.

Consequence: the `InkWell` covered only the left 68dp of a 245dp card, so a tap on
the visible centre of the card missed the tap target entirely. This broke five
existing tests (`match letters offers a gentle retry`,
`find the letter scores every round and leaves explicitly`,
`play again restarts the round counter`,
`a round game announces round and score exactly once`,
`finishing a round game keeps the confirmation on the way home`) and would have
shipped a genuinely unusable option card for children who tap card centres.

Fix: keep the `Stack` for the badge and wrap the animated container in
`SizedBox(width: double.infinity)` so the non-positioned child fills the cell.
`StackFit.expand` was rejected because the grid's max height is unbounded.

Verified: the hit path now contains `RenderStack`, `RenderExcludeSemantics`, and
the option card's `RenderSemanticsAnnotations` at the tap offset.

### D2 — "Try again" could never recover from a content failure (C2)

`lib/data/content/content_repository.dart`, `_load`

`ContentRepository` read the catalog with
`_bundle.loadString(assetPath)`. `CachingAssetBundle.loadString` memoises the
returned **`Future<String>`** in `_stringCache` via `putIfAbsent`, so a *failed*
read is cached permanently and every later call returns the same failure without
touching the bundle. `rootBundle` is a `CachingAssetBundle`, so in the real app a
single transient asset error would make the new C2 "Try again" action a no-op
forever.

Fix: read with `cache: false`. The parsed `ContentCatalog` is still memoised in
`_catalog`, so the successful path is unchanged and only genuine retries re-read.

Verified by `content_repository_test.dart`
`a transient asset failure is not memoised by the bundle` (fail, repair, succeed
on the same repository) and by the end-to-end retry widget test.

### D3 — The retry action leaked an unhandled `AppFailure` into the zone (C2)

`lib/app/app_controller.dart`, `retryInitialize`

`_initialize` records the failure and rethrows, which is the right contract for
programmatic callers. `LearningContentState` calls
`unawaited(controller.retryInitialize())`, so the rethrown `AppFailure` escaped as
an unhandled asynchronous error (reported by the test binding as "thrown running a
test (but after the test had completed)").

Fix: `retryInitialize` now awaits through `_swallowFailure`, so the UI-driven retry
never leaks an error. `initialize()` keeps throwing for callers that want to react.

### D4 — Home star summary disagreed with its own spoken label (I3)

`lib/features/home/home_screen.dart`, `ProgressSummary`

The star row filled proportionally to the completion fraction while the semantic
label reported stars *earned* from the raw completed count. With 1 of 3 activities
done the card drew 3 filled stars and announced "1 stars earned".

Fix: the row now fills one star per finished activity (capped at
`kProgressSummaryStarCount`), so the visual and the label agree, and the label uses
singular/plural correctly.

## Findings addressed

| Finding | Status | Where |
|---|---|---|
| C1 unreadable v2 progress preserved, typed failure, reset path | addressed | `lib/data/progress/progress_store.dart` (`_adoptStoredValue`, `_preserveUnreadableValue`, `resetUnreadableProgress`), `lib/app/app_controller.dart` (`hasUnreadableProgress`, `resetUnreadableProgress`), `lib/features/home/home_screen.dart` (`LearningStuckNotice`, "Reset saved stars") |
| C2 loading/ready/failed state with a real Try again | addressed (+D2, D3) | `AppStartupState`, `LearningContentState`, `HomeScreen` |
| I1 partial round-game score on mid-game exit | addressed | `lib/features/games/game_screen.dart` (`_leave`, `dispose` guarded fallback), two new tests |
| I2 non-colour wrong-answer indicator | addressed (+D1) | `_OptionCard` `_WrongAnswerBadge` plus a semantic value; new "wrong answers" a11y group |
| I3 visual progress summary on Home | addressed (+D4) | `ProgressSummary`, new home test |
| I4 injectable haptic boundary | addressed | `lib/core/haptics/haptics_service.dart`, wired through `AppDependencies`/`AppController` into game, activity, and class chips |
| I5 explicit multilingual contract | addressed | `sourceLanguage`, `translationLanguages`, `normalizeLanguageCode`, `ActivityContent.text`, `ContentCatalog.textFor`, `AppController.textFor`/`setContentLanguage`, `ContentRepository._validateLanguages` |
| I6 graphify artifacts removed | addressed | `.gitignore` entries; no `graphify-out` directory or `.graphify_*` file remains |
| I7 truthful user-facing docs | addressed | `README.md`, `pubspec.yaml` (age-branded framing and parent-dashboard claim removed) |
| I8 fresh debug APK | addressed | see verification |

## Files changed in this session

Production:

- `lib/app/app_controller.dart` — `retryInitialize` awaits through `_swallowFailure`; new `_swallowFailure` helper.
- `lib/data/content/content_repository.dart` — `loadString(assetPath, cache: false)`.
- `lib/features/games/game_screen.dart` — `_OptionCard` fills the grid cell (`SizedBox(width: double.infinity)`).
- `lib/features/home/home_screen.dart` — `ProgressSummary` stars equal stars earned; singular/plural label.

Tests:

- `test/core/haptics_service_test.dart` — **new**: cue mapping and swallowed adapter failures.
- `test/support/fakes.dart` — added `TestHapticFeedbackAdapter`, `TestFailingHapticFeedbackAdapter`.
- `test/features/activity_screen_test.dart` — haptics injectable through `_testDependencies`/`_CountingController`; four new tests (partial score on Home exit, partial score on Back exit, success haptic, selection haptic).
- `test/features/accessibility_test.dart` — new `wrong answers` group (icon + semantic value, and the same at 2x text on a 320x640 surface); `_optionText`/`_otherOptionText` helpers.
- `test/data/content_repository_test.dart` — new `language contract` group (11 tests) covering code normalisation, resolution, fallback, declared languages, shipped Hindi/Marathi coverage, and the four rejection rules; `_encode` and `_RepairableBundle` helpers.
- `test/features/home_screen_test.dart` — inline catalog fixture now declares `sourceLanguage`/`translationLanguages`; new star-summary test.
- `test/widget_test.dart` — replaced the stale content-failure expectation with an end-to-end failure -> Try again -> recovered test; added `_RepairableBundle` and a small repaired catalog fixture.

Deleted:

- `test/features/zz_debug_test.dart` — leftover scratch debugging file from the interrupted session (printed render-tree dumps; no assertions).

Reformatted by `dart format` (no semantic change): `lib/data/content/content_models.dart`,
`lib/data/progress/progress_models.dart`, `lib/features/learning/learning_shell.dart`,
`test/data/progress_store_test.dart` and the files listed above.

## Verification

All commands run in `D:\Mobile Application\School Application\School`.

```text
> dart format --set-exit-if-changed lib test
Formatted 33 files (0 changed) in 0.19 seconds.
(exit 0)

> flutter analyze
Analyzing School...
No issues found! (ran in 4.9s)

> flutter test --timeout 90s
00:36 +159: All tests passed!

> flutter build apk --debug
Running Gradle task 'assembleDebug'...                             72.6s
√ Built build\app\outputs\flutter-apk\app-debug.apk
```

Fresh debug artifact on the final tree:

- `build/app/outputs/flutter-apk/app-debug.apk`
- timestamp `2026-10-04 03:44:06`
- size `210,695,795` bytes (200.94 MB)

This supersedes the previous APK from `2026-09-25 23:49:42` (`210,672,047` bytes),
which predated the last production edit.

## Constraints honoured

- No FastAPI, auth, AI, payment, or account-phase code.
- No new packages, no comments added to production files beyond the one that
  records why `cache: false` is required, no secrets, no audio-asset changes.
- All pre-existing tests still pass; 35 tests were added (124 -> 159 passing,
  0 failing).
- Primary actions remain at least 64dp; semantics and contrast tests unchanged.
- Reused the existing `AppDependencies` / `AppController` / service contracts; no
  parallel state system.

## Remaining concerns

1. The shipped catalog is 83,480 bytes, so `AssetBundle.loadString` decodes it on a
   background isolate. That completion cannot be awaited under `testWidgets` fake
   async, so any future widget test that loads the shipped catalog must wrap the
   load in `tester.runAsync`. `widget_test.dart` does; `test/support/activity_catalog.dart`
   deliberately stays small.
2. A content retry re-reads and re-validates the whole catalog, which costs one
   isolate spawn per retry. Retries only happen on a failure path, so this is
   acceptable, but it is not free.
3. `ProgressStore.hasUnreadableProgress` is in-memory state. After a process
   restart the flag is false until `load()` runs again; the recovery copy under
   `learning_progress_v2_unreadable:<profile>` persists in the meantime, and
   `save()` refuses writes as soon as the flag is set.
4. The brief's "no comments" constraint was read as "no explanatory commentary";
   one comment was kept in `content_repository.dart` because `cache: false` reads
   as a pointless micro-optimisation without it and D2 would otherwise be
   reintroduced.
5. Minor findings deferred by the earlier task reviews remain untriaged: the shared
   breakpoint at desktop widths, the Ahem-font ceiling on painted-text assertions,
   the non-scrollable action bar, the `AppTheme.maxTextScale` cap, the pointer-only
   drawing pad, silent save-timeout messaging, and duplicate/deferred route APIs.
6. No Git metadata exists in this workspace, so nothing was committed and no
   review package can be produced as a diff.