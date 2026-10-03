# Task 6 report — Harden accessibility, responsive layout, and phase verification

Plan: `docs/superpowers/plans/2026-09-25-client-foundation.md`
Brief: `.superpowers/sdd/2026-09-25-client-foundation/task-6-brief.md`
Workspace: in-place filesystem fallback. The workspace has no Git metadata, so no branch, commit, or Git-based review package was produced. No other agents were dispatched.

## Status

**Complete.** All four verification commands pass and all six legacy files plus the dead route API are removed.

| Verification command | Result |
|---|---|
| `dart format --set-exit-if-changed lib test` | `Formatted 31 files (0 changed)` — exit 0 |
| `flutter analyze` | `No issues found!` — exit 0 |
| `flutter test` | `All tests passed!` — 127 tests — exit 0 |
| `flutter build apk --debug` | `Built build\app\outputs\flutter-apk\app-debug.apk` (210,671,000 bytes) — exit 0 |

Baseline before this task: 107 tests passing, `flutter analyze` clean, `dart format` failing on 5 legacy files, debug APK building. Net change: **+20 tests**.

## Files changed

### Production source

| File | Change |
|---|---|
| `lib/app/theme.dart` | Added `AppTheme.toolbarHeight(context)` / `AppTheme.leadingWidth(context)` that scale the app bar with the ambient text scale (capped at 2.0×), named `baseToolbarHeight`/`baseLeadingWidth`/`maxTextScale` constants used by `appBarTheme`, and a high-contrast `snackBarTheme` (dark ink surface, white bold content) used for game completion feedback. |
| `lib/app/router.dart` | Removed the unused `AppRouter.routes(...)` map, the legacy `SubjectRouteArguments` class, and the `home`/`subjects`/`activity` route aliases; `RouteNames` is now the only route-name source. `_isGamesRoute` reduced to the `bool` argument form. |
| `lib/app/app.dart` | `initialRoute` now uses `RouteNames.home`; added the `route_names.dart` import. |
| `lib/app/app_scope.dart` | `AppScope.of` and `AppScope.read` now throw a descriptive `FlutterError` instead of relying on an `assert` plus a `!` (asserts are stripped in release builds, which produced an opaque null-check error). `AppScope.of` still uses `dependOnInheritedWidgetOfExactType`, so notification propagation is unchanged. |
| `lib/features/learning/learning_shell.dart` | `LearningScaffold` uses the text-scaling toolbar/leading sizes. `LearningStepBody` became a `StatefulWidget` owning its own `ScrollController` (see "Scroll position leaked between steps"). `LessonAudioBar` is now a `liveRegion` container carrying `value: controller.statusLabel`; `_AudioAction` exposes `enabled` semantics, a `null` tap action when disabled, and an accessible name that includes the visible label. `Listen`/`Play again` are disabled while audio is busy; `Stop audio` is enabled while busy and disabled while idle. |
| `lib/features/home/home_screen.dart` | App bar uses the text-scaling toolbar/leading sizes. `_LearningChoice` uses a `LayoutBuilder` + text-scale check to switch from the icon/text/chevron row to a stacked layout (badge above full-width text, chevron dropped) when `textScale > 1.15` or the available width is under 320dp. Extracted `_ChoiceBadge`. New `kStackedChoiceWidth` constant. |
| `lib/features/learning/activity_screen.dart` | Disposal-time quiz write is guarded against an in-flight duplicate and marks itself in flight (see "Quiz write duplicated on dispose"). `_leave` (Home/Back) bounds the quiz-save wait with `kSaveTimeout` (4s) through a new `_settle` helper so a stalled store can no longer block navigation forever. `_buildReward` and the new `_stepBackIndex` route both "Practice again" and "Previous step" back to the last step the child can still act on, removing the dead end on the recorded practice step. `LearningStepBody` instances are keyed per step. `DrawingPad` height is responsive (`max(200, width * 0.6)`) instead of a fixed 220, and the clear action is wrapped in `Semantics(button: true, label: 'Clear drawing', hint: …, onTap: …)` around an `ExcludeSemantics` button. `_RewardBadge` uses `FittedBox` instead of a fixed 96px glyph. |
| `lib/features/games/game_screen.dart` | All four `LearningStepBody` call sites are keyed (`book-<activityId>`, `detail-<headline>-<backLabel>`, `round-game`, `round-reward`). New `kGameSavedMessage` ("Saved. You finished this game.") and `_completed` state: finishing a book now shows a `liveRegion` inline confirmation, flips the action to a disabled "Finished", speaks the message, and shows a `SnackBar`; finishing a round game shows the same `SnackBar` (surviving the pop, because the messenger sits above the `Navigator`) and speaks it. The word-detail letter tiles and the detail emoji are wrapped in `FittedBox` so they shrink instead of overflowing. |

### Tests

| File | Change |
|---|---|
| `test/features/accessibility_test.dart` | **New**, 17 tests. Groups: large text on a narrow surface (8), semantic labels (5), completion feedback (2), contrast (2). See "New accessibility tests" below. |
| `test/widget_test.dart` | Shipped-catalog reads now resolve through `_shippedCatalogFile()`, which tries the package-relative path and then the parent directory and fails with an explicit message instead of a bare relative-path read. Added "the shipped catalog drives the subject picker" (asserts every numbered class in the shipped catalog is reachable) and "a content failure still leaves a usable home screen" (a bundle that always throws still boots a usable Home). |
| `test/data/content_repository_test.dart` | No longer imports any legacy source. The Little Stars parity test now reads the frozen oracle from `test/support/legacy_little_catalog.dart` and additionally asserts the flashcard counts, so a truncated fixture fails loudly. |
| `test/features/activity_screen_test.dart` | Updated the three audio semantic-label expectations to the new combined names (`Listen. Play lesson audio`, `Play again. Play the lesson again`, `Stop audio. Stop the lesson audio`); replaced the trailing "tap Stop while idle" step in the audio-fallback test with an assertion that Stop is disabled when idle. Added "leaving during an in-flight quiz save never writes twice". |
| `test/support/fakes.dart` | `TestRecordingProgressStore` gained an optional `Completer<void>? gate` so a save can be held open mid-write. |
| `test/support/legacy_little_catalog.dart` | **New** frozen fixture: `LegacyLittleCatalog.letters` (26), `.numbers` (10), `.words` (10) with the exact capital/small/word/emoji/hindi/marathi strings copied out of `lib/little_catalog.dart`. |

## Files deleted

All six were removed after a repository-wide search confirmed no remaining source or test reference (the only matches left were each file importing its own siblings):

| File | Reason |
|---|---|
| `lib/catalog.dart` | imported only `models.dart`; `LearningCatalog` unreferenced |
| `lib/models.dart` | `AppScreen` enum and legacy models; imported only by `catalog.dart` and `progress_store.dart` |
| `lib/progress_store.dart` | legacy `progress_json` writer; imported nothing |
| `lib/little_catalog.dart` | imported only by `little_screens.dart` and the content-repository test (now frozen) |
| `lib/little_player.dart` | `LittleSpeaker`/`littleSpeaker`; imported only by `little_screens.dart` |
| `lib/little_screens.dart` | age-gated Little Stars home; imported nothing |

The parity oracle was moved **before** deletion and verified field-by-field against the live `LittleCatalog` with a throwaway parity test (all 26 letters, 10 numbers and 10 words matched on every field, including emoji code points and `digits`/`letters` getters). The throwaway test was then deleted. `test/data/content_repository_test.dart` now imports only `package:school_learning_app/...` sources and `../support/legacy_little_catalog.dart`.

`lib/` root now contains only `main.dart`; all active code lives under `lib/app`, `lib/core`, `lib/data`, `lib/features`.

## Implementation summary

### New accessibility tests (written first, then made to pass)

`test/features/accessibility_test.dart` uses `tester.platformDispatcher.textScaleFactorTestValue` for text scaling and `tester.binding.setSurfaceSize` for the surface, because `MaterialApp` installs its own `MediaQuery.fromView` and an ancestor override is ignored.

Three reusable oracles keep the assertions honest:

- `expectOnScreen` — the widget's centre must lie inside the visible surface rect.
- `expectMinimumTarget` — width and height must both be at least `kPrimaryActionHeight` (64).
- `_expectFitsInCard` — for each word, `RenderParagraph.getBoxesForSelection` must return a box whose `right` edge stays inside `paragraph.size.width`. This is the only mechanical way to detect horizontal text clipping, and it is font-honest. An earlier per-*line* version produced false positives (line boxes include the trailing space advance), so the check is per word.

Large-text/narrow-surface coverage (320×640 at 2.0× text scale, and 360×640 at 1.3× for the fit oracle): home choice cards, the parent lock, the teacher control, all five class chips, the three lesson-audio controls, the drawing area and its reset action, and the full activity reward action bar. The fit oracle runs at 1.3× because the `flutter_test` Ahem font is roughly 1.1 em per glyph; at 2.0× on a 320–360dp surface no layout can fit an eight-character 22dp title, so 1.3× is the strongest scale the test font admits and corresponds to roughly 2.5× in Roboto. This is stated in the report rather than hidden.

Semantic coverage: the lock is labelled and tappable on Home, absent (both semantics and tooltip) inside a game, and the game exposes Back plus Home; the teacher control's merged label contains its visible text; the audio controls carry names that include their visible labels, a live-region `value`, and enabled/disabled semantics that flip with `LessonAudioController.isBusy`; the drawing pad exposes a semantic "Drawing area" surface plus a tappable "Clear drawing"; class chips stay operable and report selection through semantics alone.

Contrast coverage locks in "dark ink on light surfaces, white only on sufficiently dark accent surfaces": white on `primary`/`error`/`success`/`warning`, and `AppColors.ink` on every light surface the app paints, all at ≥ 4.5:1.

### Real defects the new tests found and that were fixed

1. **Scroll position leaked between activity steps.** `LearningStepBody`'s `ListView` had no controller, so it used the `Scaffold`'s `PrimaryScrollController` and the offset persisted. Tapping "Next step" dropped the child mid-content with the step header scrolled off — at 320×640 and 2.0× text the reward step opened showing only the middle of the page. `LearningStepBody` is now stateful with its own controller, and every call site passes a distinct key so each step (and each game book/detail/round/reward view) starts at the top.
2. **Fixed 72dp app bar clipped two-line titles at large text.** `AppBarTheme.toolbarHeight` is now scaled by the ambient text scale through `AppTheme.toolbarHeight(context)`, used by both `LearningScaffold` and `HomeScreen`.
3. **Home choice text overflowed its card.** With the badge, chevron and 18dp padding the text column had 146dp on a 320dp surface; "Continue" needs ~229dp at 1.3×. The stacked layout gives the text the full card width.
4. **The reward step stranded a child on a step with no action.** "Previous step" landed on the practice step whose only action ("I finished practicing") is permanently disabled after a successful save. Both reward back-actions now skip a recorded practice step.
5. **Audio had no busy or disabled semantics.** `LessonAudioController.isBusy` was dead code. It now drives real enabled/disabled state, and the status is exposed as a live-region `value`.
6. **Accessible names omitted the visible label (WCAG 2.5.3).** `_AudioAction` announced "Play lesson audio" for a button reading "Listen". Names are now `Listen. Play lesson audio`.
7. **Disposal-time quiz write could duplicate an in-flight save.** `dispose()` only checked `_quizScoreSaved`, so leaving while a quiz save was still open issued a second `recordQuizScore`. The guard is now `_quizScoreSaved || _quizSaveInFlight` and the dispose path marks itself in flight. Verified as a real regression: with the guard removed the new test reports two writes instead of one.
8. **Home/Back could wait forever on a stalled store.** `_leave` awaited the quiz save with no bound. It now goes through `_settle`, which applies a 4s timeout and swallows the result, then navigates regardless.

### Preserved on purpose

- The save-retry design is untouched: `_quizSaveInFlight` is still set immediately *before* the write and cleared after, and `_quizScoreSaved` is only set on success, so a failed save stays retryable. The new disposal guard reads the same in-flight flag; it introduces no pre-write latch.
- `AppScope.of` still registers a dependency through `dependOnInheritedWidgetOfExactType`, so controller notifications keep propagating to descendants. The error-path change only affects the missing-`AppScope` case.
- Class chips keep `Semantics(button: true, selected: …, onTap: …)` and remain operable through `tester.semantics.tap`. The accessibility test asserts selection moving from Class 1 to Class 4 with no pointer involvement.

### Final-phase polish applied (all low risk)

- `LessonAudioBar` is a `liveRegion` with a `value`, and the visible status text is `ExcludeSemantics`d to avoid a duplicate announcement.
- `DrawingPad` is width-responsive and its clear action has a real semantic tap and hint.
- Game completion shows an inline live-region confirmation, a disabled "Finished" state, spoken feedback, and a `SnackBar` that survives the route pop.
- `FittedBox` on the reward star, the word-detail letter tiles and the detail emoji.
- `AppScope` missing-ancestor errors are descriptive in release builds.

## Exact commands and results

```
> dart format --set-exit-if-changed lib test
Formatted 31 files (0 changed) in 0.12 seconds.
exit=0

> flutter analyze
Analyzing School...
No issues found! (ran in 2.5s)
exit=0

> flutter test
00:27 +127: All tests passed!
exit=0

> flutter build apk --debug
Running Gradle task 'assembleDebug'...                              7.6s
√ Built build\app\outputs\flutter-apk\app-debug.apk
exit=0
```

Focused runs during the task:

```
> flutter test test/features/accessibility_test.dart -r expanded
00:13 +17: All tests passed!

> flutter test test/data/content_repository_test.dart -r expanded
00:00 +12: All tests passed!

> flutter test test/widget_test.dart -r expanded
00:02 +3: All tests passed!
```

Toolchain: Flutter 3.41.9 (stable), Dart 3.11.5, Android SDK 36.1.0. `flutter doctor` reports no issues, so the APK build ran normally — no toolchain failure to report.

## Concerns and limitations

1. **The text-fit oracle cannot run at 2.0× on a narrow surface.** `flutter_test` substitutes the Ahem font, whose glyphs are about 1.1 em wide, so an eight-character 22dp title needs ~229dp of width at 1.3× and ~352dp at 2.0×. No layout on a 320–360dp surface can satisfy that, so the fit assertion runs at 1.3×/360dp while the visibility, 64dp and semantics assertions run at 2.0×/320dp. On a real device with Roboto the 1.3× case is equivalent to roughly 2.5×. A reviewer wanting a literal 2.0× fit check would need a bundled real font in the test assets, which is outside this phase.
2. **The action bar is a `Wrap` in a fixed-height container, not scrollable.** At 2.0× on 320×640 the reward action bar measures 305dp and the body 191dp; it fits and the content still scrolls. At extreme scales (≥3×) the bar could outgrow the body and overflow. Fixing it properly needs a second `Scrollable` in the tree, which would break `activity_screen_test.dart`'s `scrollUntilVisible(…, scrollable: find.byType(Scrollable))` (it requires exactly one match). Left alone deliberately, with the 2.0× test guarding the current bound.
3. **`AppTheme.maxTextScale` is capped at 2.0.** Beyond 2.0 the app bar stops growing, so a 3× user sees a clipped two-line title again. Capping keeps the app bar from eating the whole screen; the cap is a named constant if the value needs revisiting.
4. **The drawing pad is finger/pointer only.** It has no keyboard or switch-access alternative beyond the semantic label; the "clear" action is fully operable. Building strokes from accessibility actions is out of scope here.
5. **A few Task 4/5 minor findings remain open.** `HomeScreen` still accepts five optional callback parameters used by tests rather than by the router; the `Semantics`+`ExcludeSemantics` pattern is verbose and duplicated across the feature screens (a shared labelled-button helper would remove ~200 lines but is a larger refactor than this phase warrants); and `AppController` has near-duplicate `failure`/`error` getters plus two near-duplicate completion methods (`completeActivity` / `completeActivityIfNeeded`) retained for test compatibility.
6. **No backend or secret verification was performed.** This phase is Flutter-only, per the plan's pre-flight ruling, and no packages, comments, or audio assets were added or modified.

---

# Fix round 1/4 — Task 6 review findings

All four Important findings from the Task 6 review were addressed. Unrelated minor findings were deliberately left untouched, as instructed. No commit was made and no other agents were dispatched.

## Findings addressed

### 1. Round game announced the round twice

`lib/features/games/game_screen.dart` wrapped only the star row in `Semantics(container: true, label: 'Round X of 5. Score Y.', child: ExcludeSemantics(...))`, leaving the visible `Text('Round X of 5')` outside as a separate semantics node. A screen reader therefore announced the round once from the merged node and again from the loose text.

Fix: the star row and the visible round text now sit together inside the same `ExcludeSemantics`, wrapped in a single `Column`, under one `Semantics` node. Exactly one announcement carries both round and score. Visual order (stars, then the round line) and the 8dp gap are unchanged, so the layout is byte-for-byte equivalent apart from the `SizedBox` moving inside the node.

Test: `test/features/accessibility_test.dart` → "a round game announces round and score exactly once". It asserts the exact merged label exists once, that the loose duplicate is gone, that the visible round text is now a descendant of the merged node, and — after answering round 1 and advancing — that the merged label becomes `Round 2 of 5. Score 1.` with still exactly one `Round` node.

Regression proof: with the merge reverted, the test fails with `Found 2 widgets with element matching predicate ... Which: is too many`.

### 2. `_leaveQuiz` could hang on a stalled store

`_leaveQuiz` awaited `_persistQuizScore` directly, so unlike Home/Back (which go through `_settle`) the quiz's "Previous step" action had no bound and could wait forever on a stalled store.

Fix: `_leaveQuiz` now calls `await _settle(() => _persistQuizScore(controller, activity))`, reusing the same 4-second `kSaveTimeout` helper, so the child always moves back a step within the bound. The in-flight/dispose guard from the first round is unchanged, and `_settle` swallows the timeout so nothing propagates as an unhandled async error. Disabling the Previous action while a save is in flight was deliberately *not* done: `_persistQuizScore` already returns `false` immediately when in flight, so Previous remains a working escape route, and disabling it would remove a way out.

Test: `test/features/activity_screen_test.dart` → "a stalled quiz save never blocks leaving the quiz". Using the `TestRecordingProgressStore.gate` from the first round, the store is held open mid-write, the child taps "Previous step", and the test pumps past `kSaveTimeout + 1s` and asserts the child is on `Step 2 of 5` showing `Card 1 of 2`. The gate is then released and the test asserts exactly one quiz write landed with the correct score.

Regression proof: with `_settle` reverted, the test fails with `Found 0 widgets with text "Step 2 of 5"`.

### 3. Saved-message test could pass on the SnackBar

`test/features/accessibility_test.dart` selected `find.bySemanticsLabel(kGameSavedMessage).last`, which after the round-game/book completion resolves to the `SnackBar` copy rather than the app's own inline live region, so the live-region assertion was not testing the app's node.

Fix: the inline confirmation in `lib/features/games/game_screen.dart` now carries `key: const Key('game-saved-confirmation')` on its `Semantics` widget. The test uses `find.byKey(const Key('game-saved-confirmation'))` — a finder only the app's node can match — and asserts that node's `label` is exactly `kGameSavedMessage` and that its `flagsCollection.isLiveRegion` is true. The test also still asserts `find.text(kGameSavedMessage), findsNWidgets(2)` to document that the SnackBar copy exists and is deliberately not what is being checked.

### 4. `ChoiceCard` still used a fixed row at large text / narrow width

`lib/features/learning/subject_screen.dart` kept the badge + `Expanded` text + chevron `Row` unconditionally, so subject, activity and game tiles squeezed their text into roughly 154dp on a 320dp surface at 2.0× text scale.

Fix: the responsive rule is now shared rather than duplicated. `lib/features/learning/learning_shell.dart` gained `kStackedCardWidth` (320), `kStackedCardTextScale` (1.15), `useStackedCardLayout(context, constraints)` and a `CardBadge` widget. `ChoiceCard` now uses a `LayoutBuilder` and stacks badge-above-full-width-text with no chevron when cramped, exactly as the home choice card does, while keeping its `ConstrainedBox(minHeight: 88)`, its `Semantics(button: true, label: '<title>. <subtitle>[. <progress>]', onTap: …)` merged label and its 64dp-minimum badge.

`lib/features/home/home_screen.dart` was refactored onto the same shared helpers, so the two cards cannot drift apart: its local `kStackedChoiceWidth` and `_ChoiceBadge` were removed in favour of `useStackedCardLayout` and `CardBadge`. The home card's rendered layout and semantics are unchanged at every size.

Tests: `test/features/accessibility_test.dart` → "subject activity cards stay usable at large text" opens a subject activity list at 2.0× on 320×640 and asserts, for both activity cards, that the card and its title are on screen, that the card is at least 64dp in both dimensions, that the chevron is gone, and that the title receives the full card width. It then checks the merged semantic label is still present exactly once, that both cards still read "Ready to start", and that tapping a card opens the activity (`Step 1 of 5`). Two new helpers back it: `_expectNoChevron` and `_expectFullWidthText`.

Regression proof: with `useStackedCardLayout` forced to `false`, the test fails on the chevron; with the chevron also removed, it fails with `Class 1 Story only receives 182.0dp of the 248.0dp card, so the badge is still beside it`.

## Files changed in this round

| File | Change |
|---|---|
| `lib/features/games/game_screen.dart` | Merged the star row and the visible round text into one `Semantics`/`ExcludeSemantics` node; added `key: const Key('game-saved-confirmation')` to the inline saved confirmation. |
| `lib/features/learning/activity_screen.dart` | `_leaveQuiz` routes through `_settle` so the quiz exit shares the 4s bound used by Home/Back. |
| `lib/features/learning/learning_shell.dart` | Added `kStackedCardWidth`, `kStackedCardTextScale`, `useStackedCardLayout(...)` and the shared `CardBadge` widget. |
| `lib/features/learning/subject_screen.dart` | `ChoiceCard` gained the responsive stacked layout via `LayoutBuilder` + `useStackedCardLayout` + `CardBadge`. |
| `lib/features/home/home_screen.dart` | Switched to the shared `useStackedCardLayout` / `CardBadge`; removed the local `kStackedChoiceWidth` and `_ChoiceBadge`. No behaviour change. |
| `test/features/accessibility_test.dart` | Added "a round game announces round and score exactly once" and "subject activity cards stay usable at large text"; rewrote the saved-message assertion to use `find.byKey(const Key('game-saved-confirmation'))`; added `_expectNoChevron` and `_expectFullWidthText`; relaxed `_expectFitsInCard` to iterate over repeated labels such as "Ready to start". |
| `test/features/activity_screen_test.dart` | Added "a stalled quiz save never blocks leaving the quiz"; imported `activity_screen.dart` for `kSaveTimeout`. |

No files were added or deleted in this round. `test/support/fakes.dart` and `test/support/legacy_little_catalog.dart` were not touched; the `TestRecordingProgressStore.gate` used by the new test was added in the first round.

## Exact commands and results

```
> dart format --set-exit-if-changed lib test
Formatted 31 files (0 changed) in 0.15 seconds.
exit=0

> flutter analyze
Analyzing School...
No issues found! (ran in 4.1s)
exit=0

> flutter test test/features/accessibility_test.dart -r expanded
00:14 +19: All tests passed!
exit=0

> flutter test
00:28 +130: All tests passed!
exit=0

> flutter build apk --debug
Running Gradle task 'assembleDebug'...                             23.4s
√ Built build\app\outputs\flutter-apk\app-debug.apk
exit=0
```

APK: `build\app\outputs\flutter-apk\app-debug.apk`, 210,672,047 bytes. Suite is now 130 tests, up from 127 (+3: the round-game merged-semantics test, the subject-card large-text test, and the bounded quiz-exit test). The first round's `dart format` pass reformatted four files (`lib/features/games/game_screen.dart`, `lib/features/home/home_screen.dart`, `lib/features/learning/subject_screen.dart`, `test/features/accessibility_test.dart`); the verification pass above reports 0 changed.

Toolchain unchanged: Flutter 3.41.9 (stable), Dart 3.11.5, Android SDK 36.1.0. The debug APK build ran normally; no toolchain failure to report.

## Remaining concerns

1. **The "Play and learn" tiles now stack at desktop widths.** Sharing the 320dp breakpoint means the games grid — whose tiles are about 242dp wide even on an 800×600 surface, because `ResponsiveTileGrid(minItemWidth: 240, maxColumns: 3)` fits three columns — uses the stacked layout where it previously used the row. This gives the tiles more text room, and no test asserted the old shape, but it is a visible change to the widest layout and is called out here in case the reviewer wants a separate threshold for game tiles.
2. **The 2.0× subject-card check is structural, not font-metric based.** It asserts the title receives the full card width and the chevron is gone, which is what "stacked" means, rather than measuring painted text width. That was deliberate: at 1.3× the Ahem test font happens to let the row layout fit this particular copy (154dp available versus a 148dp longest word), so a width oracle there would not have discriminated. A text-fit oracle for these cards would need a bundled real font.
3. **The 4-second bound is a wall-clock wait, not a cancellation.** After the timeout the child moves on and the abandoned write keeps running; `AppController` serializes writes and is idempotent, so the late completion is harmless, but nothing cancels it. Tightening this would need cancellation support in `ProgressStore`, which is a store-level change outside this review round.
4. **A timed-out quiz exit no longer surfaces a retry message.** The child is returned to the flashcards step with the score unsaved and no explanation. The score is not lost — the disposal path retries it — so this is a messaging gap, not a data gap, and addressing it would mean inventing UI for a step the child has already left.
5. **All first-round concerns still stand**, including the 2.0×/360dp text-fit ceiling from the Ahem font, the non-scrollable action bar, the `AppTheme.maxTextScale` 2.0 cap, the pointer-only drawing pad, and the open Task 4/5 minor findings. None of them were in scope for this round.
---

# Fix round 2/4 — hard-coded badge icon in the stacked `ChoiceCard` branch

The Task 6 fix round 1 regression review found one Important defect. It was addressed in isolation; no unrelated code was touched, no commit was made, and no other agents were dispatched.

## The regression

In fix round 1, `lib/features/learning/subject_screen.dart` was changed to give `ChoiceCard` the same responsive treatment as the home choice card: a `LayoutBuilder` that switches to a stacked layout (badge above full-width text, no chevron) when `useStackedCardLayout` reports a cramped surface or an elevated text scale.

The new stacked branch was written with a literal icon instead of the widget's own argument:

```dart
const CardBadge(
  icon: Icons.auto_stories_outlined,
  color: Color(0xFFD8F3EF),
),
```

`ChoiceCard.icon` is a required parameter fed by `subjectIcon(subject.id)` in the subject grid, `activityIcon(activity.activityType)` in the activity list, and `activityIcon(activity.activityType)` in the "Play and learn" list. Those mappings — `menu_book_outlined` for English, `calculate_outlined` for Mathematics, `text_fields` for letter activities, `pin_outlined` for number activities, `spellcheck_outlined` for word activities, `sports_esports_outlined` for games — were all silently discarded at the responsive breakpoint, so subject, activity and game cards all rendered the same story-book badge. The row branch, which still passed `icon`, was unaffected, so the defect only appeared on narrow or large-text surfaces — exactly the surfaces fix round 1 had just made responsive.

The round-1 test "subject activity cards stay usable at large text" did not catch it because it asserted target size, on-screen position, chevron absence, full-width text, merged label and tap-through, but never the icon.

## The fix

`lib/features/learning/subject_screen.dart`, stacked branch only:

```dart
CardBadge(
  icon: icon,
  color: const Color(0xFFD8F3EF),
),
```

One change: the literal became the `icon` argument, and the widget lost its `const` (it is no longer constant because it reads a field). The `color` value, the 52dp badge size, the 12dp gap below the badge, the title/subtitle/progress ordering, the `Semantics(button: true, label: '<title>. <subtitle>[. <progress>]', onTap: …)` merged label, the `ConstrainedBox(minHeight: 88)` and the row branch are all byte-for-byte unchanged. The per-subject, per-activity-type and per-game icon mapping is now the single source for both branches, so the two layouts can no longer disagree.

## Test added

`test/features/accessibility_test.dart` → "stacked subject and game cards keep their own icons", run at 2.0× text scale on a 320×640 surface, i.e. the responsive breakpoint where the stacked branch is active.

- Subject picker: asserts the English card contains `Icons.menu_book_outlined` and that no card in the grid falls back to `Icons.auto_stories_outlined` (the hard-coded value), and that `menu_book_outlined` and `calculate_outlined` each appear exactly once across the grid, so the Mathematics mapping is covered too.
- "Play and learn": navigates Home → Play and learn and asserts the icon inside each named game card — `sports_esports_outlined` for "Find the Letter" and "Match Letters", `text_fields` for "Big ABC", `pin_outlined` for "Numbers 1 to 10", `spellcheck_outlined` for "First Words" — each scoped to its own card via a new `_cardFor(title)` helper, plus `find.byIcon(Icons.sports_esports_outlined), findsNWidgets(2)` to pin the game mapping.

A shared `_cardFor(String title)` helper was added so the card-scoped `find.descendant` assertions read consistently; the pre-existing inline card finders were left as they were to keep the diff to the new test.

Regression proof: with the literal icon reinstated, the test fails with `Found 0 widgets with icon "IconData(U+0F1C2)" descending from ... Which: means none were found but one was expected`; with the fix it passes.

## Files changed in this round

| File | Change |
|---|---|
| `lib/features/learning/subject_screen.dart` | Stacked `ChoiceCard` branch now passes `icon` into `CardBadge` instead of a hard-coded `Icons.auto_stories_outlined`. One branch, one argument. |
| `test/features/accessibility_test.dart` | Added "stacked subject and game cards keep their own icons" and the `_cardFor` helper. |

No files were added or deleted. No packages, comments, backend code or audio assets were touched, and no secrets were introduced.

## Exact commands and results

```
> dart format --set-exit-if-changed lib test
Formatted 31 files (0 changed) in 0.18 seconds.
exit=0

> flutter analyze
Analyzing School...
No issues found! (ran in 4.0s)
exit=0

> flutter test test/features/accessibility_test.dart -r expanded
00:35 +20: All tests passed!
exit=0

> flutter test
00:50 +131: All tests passed!
exit=0
```

Suite is now 131 tests, up from 130 (+1: the icon regression test). `dart format` needed no changes, confirming the two-line production edit and the new test are already correctly formatted. Toolchain unchanged: Flutter 3.41.9 (stable), Dart 3.11.5, Android SDK 36.1.0.

## Remaining concerns

1. **The reviewer's icon regression was a direct consequence of sharing the stacked branch without reusing its argument.** The root cause was writing a new layout branch by copy rather than by extracting the existing badge subtree. `CardBadge` is now the single badge implementation for both `ChoiceCard` and the home choice card, and both branches pass their own icon, so the failure mode is closed structurally rather than by a test alone. The new test is a regression guard on top of that.
2. **"Play and learn" tiles still stack at desktop widths**, unchanged from round 1: their grid fits three ~242dp columns even at 800×600, which is under the shared 320dp breakpoint. Noted in round 1 and still open; a separate threshold for game tiles is the obvious option if the reviewer wants the row layout restored there.
3. **Icon identity is asserted by `IconData`, not by rendered pixels.** The test proves the correct `IconData` reaches the right card, which is what the mapping controls; it does not assert glyph shape or contrast. The contrast group already locks the badge's `AppColors.primary` icon on its light badge fill.
4. **The subject-grid icon coverage depends on the shipped test catalog.** The fixture exposes English, Mathematics and Little Stars, so the assertions cover two `subjectIcon` branches. The remaining mappings (`english_grammar`, `marathi`, `hindi`, `evs`, `computer`, `gk`, `communication` and the `little` default) are unexercised by this test; `subjectIcon` is a pure switch with no other caller, and the round-1 `activity_screen_test.dart` parsing group already covers the parser side.
5. **All earlier concerns still stand** and none were in scope for this round: the Ahem-font ceiling on the 2.0× painted-text oracle, the non-scrollable action bar, the `AppTheme.maxTextScale` 2.0 cap, the pointer-only drawing pad, the 4-second bound being a wait rather than a cancellation, the silent timed-out quiz exit, and the open Task 4/5 minor findings.