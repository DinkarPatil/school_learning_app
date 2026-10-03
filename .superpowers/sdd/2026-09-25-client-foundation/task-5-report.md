# Task 5 Report: Resumable subjects, activities, and migrated games

**Status:** COMPLETE — all required behaviours implemented and verified.

**Workspace note:** The workspace has no Git metadata, so no commits, branches, or Git-based review
packages were produced. All work is in-place in the current workspace.

---

## 1. Files changed

### Created

| File | Purpose |
|---|---|
| `lib/app/app_scope.dart` | `AppScope` inherited widget (plus internal `_AppScopeData`) that publishes the `AppController` to feature screens and rebuilds dependents on controller notifications. `AppScope.of(context)` subscribes; `AppScope.read(context)` does not (used from `initState`). |
| `lib/features/learning/lesson_audio.dart` | `LessonAudioController` + `LessonAudioPhase`. Wraps the injected `AudioService`/`SpeechService`: plays the lesson asset, falls back to spoken text when the asset is missing or fails, exposes explicit `play` / `speak` / `stop`, and reports a child-safe status label. |
| `lib/features/learning/learning_shell.dart` | Shared chrome: `LearningScaffold` (AppBar with 64dp `Back` and 64dp `Home`), `StepHeader`, `LessonAudioBar` (play / play again / stop with explicit semantics), `LearningActionBar`, `LearningStepBody`, `LearningMessage`, `PrimaryActions`, `ResponsiveTileGrid`. |
| `lib/features/learning/subject_screen.dart` | `SubjectScreen` — all-kids, class-aware subject and activity browser plus the Play-and-learn game list. Also exports `classLabel`, `kClassTargetSize`, `numberedClassIds`, `activityIcon`, `subjectIcon`, `activityCountFor`, `completedCountFor`. |
| `lib/features/learning/activity_screen.dart` | `ActivityScreen` — resumable story / flashcards / quiz / practice / reward flow, `buildSteps`, `OptionButton`, `DrawingPad`. |
| `lib/features/games/game_screen.dart` | `GameScreen` — letter book, number book, word book, find-letter and match-case round games adapted from the migrated `little` content. Exports `isGameActivity`, `parseLetter`, `parseNumber`, `parseWord`, `GameLetter`, `GameNumber`, `GameWord`. |
| `test/features/activity_screen_test.dart` | 40 widget/unit tests covering subject selection, unknown activity, story step, audio fallback, quiz feedback, save-failure recovery, practice/quiz completion, game adaptation, shipped-content parsing, app-scope propagation, and touch targets. |
| `test/support/activity_catalog.dart` | Shared test catalog bundle (6 classes, 3 subjects, 13 activities) used by the new test file. |

### Modified

| File | Change |
|---|---|
| `lib/app/router.dart` | Shell screens removed. Route builders now create `SubjectScreen`, `ActivityRouteEntry` (which dispatches to `GameScreen` or `ActivityScreen`), and `HomeScreen`, all wrapped in `AppScope`. Route names in `lib/app/route_names.dart` are unchanged. Router owns the explicit `_goHome` / `_popOrHome` callbacks passed into the screens. |
| `test/support/fakes.dart` | `TestAudioPlayer` now records `playedPaths`; added `TestFailingAudioPlayerFactory` / `TestFailingAudioPlayer`, `RecordingSpeechEngine`, and `TestRecordingProgressStore`. |
| `test/features/home_screen_test.dart` | The three Task-4 shell tests that asserted removed UI were migrated. `subject and activity shells navigate predictably` became `subject and activity screens navigate predictably` and now asserts the class-aware subject flow. `completed activity action is disabled without a save message` and `completion failure shows a retry message` moved to `test/features/activity_screen_test.dart` (as `an already completed activity never saves again` and `a completion save failure shows a child-safe message`) because the behaviour now lives in the multi-step reward flow. |

### Deliberately untouched

`lib/main.dart`, `lib/catalog.dart`, `lib/models.dart`, `lib/progress_store.dart`,
`lib/little_catalog.dart`, `lib/little_player.dart`, `lib/little_screens.dart`,
`lib/app/app_controller.dart`, `lib/app/app.dart`, `lib/app/theme.dart`, `lib/core/**`,
`lib/data/**`, `lib/features/home/home_screen.dart`, `assets/**` (74 files), `pubspec.yaml`.

---

## 2. Implementation summary

### Contracts consumed, not redefined

`SubjectScreen` / `ActivityScreen` / `GameScreen` receive the controller through `AppScope` and
use only the existing contracts: `catalog`, `progress`, `activityById`, `openSubject`,
`openActivity`, `completeActivity`, `completeActivityIfNeeded`, `recordQuizScore`,
`recordPractice`, `resetSelection`, `audio`, `speech`. No controller, store, repository, or
service signature was changed.

### All-kids, class-aware subject flow

- `SubjectScreen` renders a "Choose a class" filter built from `catalog.classIds`, filtered to
  numbered classes 1+ and sorted numerically, so **Class 1 through Class 5 are all reachable**.
- `class-0` is never a user-facing concept: the generic subject list excludes the `little`
  subject, the class chips never show it, and activity filtering uses the selected numbered class.
- There is **no age gate**; the tests assert no visible text contains "age".
- The default class resumes from `controller.activeClassId`, then the class of
  `progress.lastActivityId`, then the first numbered class.
- Subjects render as a responsive wrapping grid with a unique icon per subject, a
  high-contrast label, and "$done of $total finished" progress.
- Selecting a subject lists activities for the selected class. Each activity card label is built by
  `_activityProgressLabel` from completion **and** best quiz score, so a child who has a best
  score without finishing still sees progress: `Finished`, `Best quiz N of M`, or
  `Finished. Best quiz N of M`, falling back to `Ready to start`.
- The class filter is expressed semantically as a `Semantics(container: true, label: 'Choose a class')`
  group; each chip exposes a real tap action and 64dp minimum size (see fix round).

### Play and learn

`SubjectScreen(gamesOnly: true)` is the same screen in a different mode. It renders the migrated
`little` subject activities (letter / number / word / game) with the same chrome, helpers, and
progress labels. It does not create a second home, does not show the subject title, star counts,
or age copy, and shows no class selector.

### Resumable activity flow

`ActivityScreen` builds one step at a time from `buildSteps(activity)`, skipping steps with no
content, and always appending the reward: story/listen → flashcards → quiz → practice → reward.
Step state lives in the widget, so a child can move forward and backward and can leave at any
time. The AppBar keeps a 64dp `Back` and a 64dp `Home` visible on every step.

- **Story/listen** — story text plus `LessonAudioBar` (`Listen`, `Play again`, `Stop audio`).
- **Flashcards** — one card at a time with `Card N of M`, `Show the answer` / `Next card` /
  `Next step`, and per-card audio.
- **Quiz** — one question at a time, options as ≥64dp buttons, gentle feedback (below).
- **Practice/drawing** — practice prompt and hint, a real drawing pad with a
  `Semantics(label: 'Drawing area')` region and a `Clear drawing` action, then
  `I finished practicing`.
- **Reward** — animated star badge, score summary, and the single `Finish` completion action.

### Audio

`LessonAudioController` plays the injected `AudioService` asset first. If the asset is blank or
`AudioService` throws (converted to `AppFailure.audioUnavailable`), it falls back to
`SpeechService.speak` with the on-screen text. Failures never reach the child UI. Status is
reported as an explicit label. `Semantics(explicitChildNodes: true, label: 'Lesson audio')` groups
the status and the three buttons, each of which has its own explicit label. Every screen stops
audio on `dispose`.

### Quiz scoring (no double counting)

- Per-question state: `_attempts`, `_answers`, `_locked`, and `_scored` sets.
- A question accepts at most `kQuizAttempts = 2` taps. A correct answer locks the question and
  increments `_score` at most once (`_scored.add` guard). A first wrong answer shows
  "Not yet, try again" with the hint and **keeps the options tappable** (one gentle retry). A
  second wrong answer locks the question and shows "The answer is &lt;answer&gt;" with the hint.
- Success shows a large animated 🌟 "Great job!" panel; a locked wrong answer shows a calm bulb
  panel. No shame or failure language.
- Quiz feedback is spoken through the shared `LessonAudioController`.

### Practice and completion

- `recordPractice(activity.id)` runs through `_recordPractice`, which only sets `_practiceRecorded`
  **after a successful write**. A failure leaves the child on the practice step, shows the
  child-safe "We could not save that yet. Please try again." notice, keeps the button enabled, and
  allows a retry.
- `completeActivity(activity.id)` is called once, guarded by `_completionRequested`. After success
  the reward shows "Saved. You finished this activity." and the `Finish` action is replaced. A
  failure shows the same child-safe message and re-enables `Finish`. A `Go home` action is always
  present, so the child is never trapped.
- An activity that was already completed shows "You finished this activity before.", offers
  `Practice again`, and never calls `completeActivity` again.

### Games

`GameScreen` adapts the migrated `little` content, parsing the shared
`Word emoji | हिन्दी | मराठी` flashcard format with the public `parseLetter` / `parseNumber` /
`parseWord` helpers.

- **Letter books** (`Big ABC`, `Small abc`) — responsive wrapping grid, ≥96dp cards; tapping a
  letter opens an inline detail with an explicit `Back to letters` action and a `Finish` action
  that calls `completeActivity`.
- **Number book** — responsive wrapping grid (not the old fixed five-column row) with ≥120dp
  minimum item width; the detail shows the digit, word, translations, and counting stars with a
  `Count` action and `Back to numbers`.
- **Word book** — word cards; the detail spells the word into ≥64dp letter tiles with
  `Back to words`.
- **Find the letter / Match letters** — 5 rounds, one large target and 3 options per round, a
  star progress row, a gentle "Try again, little star" state that keeps the options tappable, and
  a large "Great job!" state. The round score is stored once through `recordQuizScore`.
- **No `Navigator.maybePop()` anywhere.** The only exit from the reward is an explicit route
  callback: the router's `onGoHome` (`pushNamedAndRemoveUntil('/')`) via a `Go home` action, plus
  `Play again`. There is no silent no-op exit and no trophy trap.
- Back inside the game resets the inline detail/reward before leaving the route.

### Accessibility and layout

- Primary actions live in a persistent `LearningActionBar` outside the scroll view.
- All action buttons keep the theme's 64dp minimum in both axes (asserted by a test).
- `ResponsiveTileGrid` computes the column count from the available width with a minimum item
  width and a column cap, replacing the old fixed five-column number grid and the fixed
  three-option game row. No fixed-height rows anywhere in the new screens.
- Card and control labels are high-contrast; the old fixed giant text is replaced by theme text
  styles plus `FittedBox` scaling for the large letter/number/word glyphs.
- Custom tap targets (cards, chips, audio buttons, back button, options) are wrapped in
  `Semantics` with merged, single labels and a real `onTap`.

---

## 3. Commands and results

All commands were run from `D:\Mobile Application\School Application\School`.

```
> flutter test test/features/activity_screen_test.dart -r expanded
00:00 +0: loading .../test/features/activity_screen_test.dart
00:00 +0: subject selection every class is reachable without an age gate
00:01 +1: subject selection the class filter narrows the activity list
00:02 +2: subject selection an empty class stays reachable and recoverable
00:03 +3: subject selection play and learn reuses migrated game content only
00:03 +4: activity flow unknown activity shows a recoverable message
00:03 +5: activity flow the story step listens and advances one step at a time
00:05 +6: activity flow every activity step keeps a visible home action
00:05 +7: activity flow lesson audio falls back to speech when the asset fails
00:06 +8: activity flow lesson audio plays the migrated asset when it is available
00:06 +9: activity flow audio controls expose one merged semantic group
00:06 +10: activity flow every primary action keeps a 64dp touch target
00:07 +11: quiz a correct answer shows a large success state once
00:08 +12: quiz a wrong answer invites one gentle retry and never double counts
00:08 +13: quiz a repeated wrong answer reveals the answer once
00:09 +14: practice and completion practice and completion are each saved exactly once
00:10 +15: practice and completion a completion save failure shows a child-safe message
00:10 +16: practice and completion a practice save failure keeps the child on the step
00:11 +17: practice and completion a quiz save failure keeps the child on the quiz
00:12 +18: practice and completion leaving the last question still stores the quiz score
00:12 +19: practice and completion an already completed activity never saves again
00:13 +20: migrated games the letter book adapts migrated content and returns
00:14 +21: migrated games the number book keeps large targets on a narrow surface
00:14 +22: migrated games the word book spells out the selected word
00:14 +23: migrated games find the letter scores every round and leaves explicitly
00:15 +24: migrated games match letters offers a gentle retry
00:15 +25: migrated games play again restarts the round counter
00:15 +26: migrated games the small letter book reads the shipped small-first fronts
00:16 +27: migrated games the match game offers small letters for a capital target
00:16 +28: migrated games the find game offers capital letters for a capital target
00:16 +29: migrated content parsing reads the shipped capital-first letter book
00:16 +30: migrated content parsing reads the shipped small-first letter book
00:16 +31: migrated content parsing reads the shipped match-case back format
00:16 +32: migrated content parsing falls back to the capital when no small letter is present
00:16 +33: migrated content parsing reads the shipped number and word back formats
00:16 +34: migrated content parsing parses every shipped little Stars card
00:16 +35: app scope propagates controller notifications to descendants
00:16 +36: app scope rebuilds after a recorded quiz score
00:17 +37: app scope replaces the controller without leaking the old listener
00:17 +38: class selector accessibility every class chip meets the 64dp minimum size
00:17 +39: class selector accessibility a class chip exposes a working semantic tap action
00:17 +40: All tests passed!
```
**Result: 40/40 passed.**

```
> flutter test
00:22 +106: .../test/features/activity_screen_test.dart: class selector accessibility a class chip exposes a working semantic tap action
00:22 +107: All tests passed!
```
**Result: 107/107 passed** (baseline before this task was 69).

```
> flutter analyze
Analyzing School...
No issues found! (ran in 3.1s)
```

```
> dart format --output=none --set-exit-if-changed lib/app/app_scope.dart lib/app/router.dart \
    lib/features/learning/activity_screen.dart lib/features/learning/learning_shell.dart \
    lib/features/learning/lesson_audio.dart lib/features/learning/subject_screen.dart \
    lib/features/games/game_screen.dart test/features/activity_screen_test.dart \
    test/features/home_screen_test.dart test/support/activity_catalog.dart test/support/fakes.dart
Formatted 11 files (0 changed) in 0.05 seconds.
format exit=0
```

The focused file was additionally run four more times to check for flakiness in the randomised
round games: `+40: All tests passed!` on every run.

---

## 4. Test coverage against the brief's Step 1 list

| Required behaviour | Test |
|---|---|
| Subject selection | `every class is reachable without an age gate`, `the class filter narrows the activity list`, `an empty class stays reachable and recoverable`, `play and learn reuses migrated game content only` |
| Unknown activity | `unknown activity shows a recoverable message` (asserts "Let us choose something else" and "Go home", then returns Home) |
| Story step | `the story step listens and advances one step at a time`, `every activity step keeps a visible home action` |
| Quiz feedback | `a correct answer shows a large success state once`, `a wrong answer invites one gentle retry and never double counts`, `a repeated wrong answer reveals the answer once` |
| Practice completion | `practice and completion are each saved exactly once`, `a practice save failure keeps the child on the step`, `a completion save failure shows a child-safe message`, `a quiz save failure keeps the child on the quiz`, `leaving the last question still stores the quiz score`, `an already completed activity never saves again` |
| Audio fallback | `lesson audio falls back to speech when the asset fails`, `lesson audio plays the migrated asset when it is available`, `audio controls expose one merged semantic group` |
| Returning Home | `unknown activity shows a recoverable message`, `subject and activity screens navigate predictably` (home test), `find the letter scores every round and leaves explicitly`, `leaving the last question still stores the quiz score` |
| Games | `the letter book adapts migrated content and returns`, `the small letter book reads the shipped small-first fronts`, `the number book keeps large targets on a narrow surface`, `the word book spells out the selected word`, `find the letter scores every round and leaves explicitly`, `match letters offers a gentle retry`, `the match game offers small letters for a capital target`, `the find game offers capital letters for a capital target`, `play again restarts the round counter` |
| Shipped content | `reads the shipped capital-first letter book`, `reads the shipped small-first letter book`, `reads the shipped match-case back format`, `falls back to the capital when no small letter is present`, `reads the shipped number and word back formats`, `parses every shipped little Stars card` (runs against the real `assets/content/catalog.json`) |
| App scope | `propagates controller notifications to descendants`, `rebuilds after a recorded quiz score`, `replaces the controller without leaking the old listener` |
| Layout/touch | `every primary action keeps a 64dp touch target`, `every class chip meets the 64dp minimum size`, `a class chip exposes a working semantic tap action` |

"Exactly once" for `completeActivity`, `recordPractice`, and `recordQuizScore` is asserted with a
`_CountingController` test subclass that overrides the three existing controller methods and
records every call, so the counts are observed without redefining any contract. Save-failure
paths are exercised with `TestRecordingProgressStore`, which fails a configurable number of
writes and records the snapshots that did get through.

---

## 5. Concerns and notes for review

1. **`AudioService` never settles inside `flutter_test`'s fake-async zone.** `AudioService`
   awaits `StreamSubscription.cancel()` while disposing a player, and that future does not
   complete under `FakeAsync` (it completes under real async, as `test/core/audio_service_test.dart`
   shows). The failing-audio path therefore stalls in widget tests. I did not modify the Task 3
   audio service; instead the two audio tests use the standard workaround — tap, then
   `tester.runAsync(() => Future.delayed(...))` to give the real event loop a turn, then
   `pumpAndSettle`. This is a test-harness constraint, not a production defect, but any future
   widget test that exercises the *disposing* audio path will need the same pattern.
2. **The quiz offers exactly one retry, then reveals the answer.** The design spec says "invite
   retry and provide a smaller hint before showing the answer". I capped attempts at two so the
   answer-lock is unambiguous and no answer can ever be counted twice. If review prefers
   unlimited retries, the cap is the single `kQuizAttempts` constant.
3. **The disposal fallback for the quiz score is best-effort.** `_persistQuizScoreOnDispose` reads
   the cached activity id and calls `recordQuizScore` after the screen is torn down. If the whole
   app is shutting down the write may not land. This path exists only as a safety net; the normal
   exits (Previous step, Back, Home) await the write before navigating.
4. **The round-game mode is now derived from content, not the activity id.** `GameLetter.smallFromBack`
   records whether the small letter came from the back detail, and `_matchesSmallLetters` selects
   the match-case presentation when every card has it. The previous `activity.id.endsWith('match-case')`
   heuristic is gone, so a renamed or newly added matching game works without code changes.
5. **`AppRouter.routes(...)` is kept and is now consistent with `onGenerateRoute`.** It is still
   unused by the app, but its builders are no longer a parallel implementation. Removing it, or
   wiring it as the single source for `onGenerateRoute`, is a reasonable Task 6 cleanup.
6. **Card/detail layout still scrolls.** The primary action bar is pinned, but long detail
   content can exceed a 320x640 surface. The tests scroll before tapping. Task 6's large-text-scale
   and narrow-surface work should re-check this.
7. **Legacy `little_screens.dart` is still present and unreferenced** by the new routes, as
   instructed. Task 6 owns removing it. Its `Navigator.maybePop()` exits and fixed-height rows are
   therefore still in the tree but unreachable from the new router.

---
---

# Fix round 1/5 — review findings addressed

**Status:** COMPLETE. Six findings addressed; all verification commands green.

**No Git metadata in the workspace, so nothing was committed. No other agents were dispatched.**

## Findings addressed

### F1 (Critical) — Practice save failures latched the completion flag before the write

`lib/features/learning/activity_screen.dart` set `_practiceRecorded = true` *before* awaiting
`recordPractice`, and `_guard` swallowed the error, so a failing store advanced the child to the
reward while `practiceCount` stayed at 0 — an unrecorded completion with no retry path.

**Fix.** Replaced the inline closure with `_recordPractice(controller, activity, steps, index)`.
It now sets an in-flight flag, attempts the write through the new `_trySave` helper, and only sets
`_practiceRecorded = true` after a successful write. On failure it clears the flag, stores
`kSaveFailureMessage` in `_practiceError`, and stays on the practice step with the action still
enabled so the child can retry. The step is unchanged (`Step 4 of 5`), so there is no phantom
progress. The error is rendered by a new `_SaveRetryNotice` widget (error-coloured, bordered,
`Semantics(liveRegion: true)` so it is announced).

**Test.** `a practice save failure keeps the child on the step` — fails one write via
`TestRecordingProgressStore`, asserts the message, that the child is still on step 4, that
`recordPractice` was called once, that `practiceCount` is still 0, that the button is still
enabled, then retries and asserts the second call succeeds with `practiceCount == 1` and the step
advancing to 5.

### F2 (Critical) — Quiz save failures latched the score flag before the write

`_saveQuizScore` had the same shape: `_quizScoreSaved = true` before awaiting
`recordQuizScore`, with errors swallowed, so a failure silently discarded the score.

**Fix.** `_saveQuizScore` is now `_persistQuizScore`, which returns a `bool`. It only sets
`_quizScoreSaved` on success, sets `_quizError` on failure, and guards re-entrancy with
`_quizSaveInFlight`. The last-question "Next step" action now stays on the quiz step when the
write fails, so the child can retry the same action. The error uses the same
`_SaveRetryNotice` widget.

**Test.** `a quiz save failure keeps the child on the quiz` — fails one write, asserts the
message, that the child is still on step 3 (not 4), that `recordQuizScore` was called once, and
that nothing reached the store; then retries and asserts the store received `quizBestScores` of 2.

### F3 (Critical) — Quiz score was only persisted on the "Next step" path

The child could answer the last question, tap "Previous step", and reach the reward with an
unpersisted score. There was no persistence on Previous, on leaving the activity, or on disposal.

**Fix.** The score is now flushed on every exit path from the quiz step:

- **Last-question Next step** — `_persistQuizScore`; navigation only proceeds on success so the
  child can retry in place.
- **Previous step** — `_leaveQuiz` awaits `_persistQuizScore` before moving, then navigates
  regardless of the result (a failed write is retried on the next exit because the latch is only
  set on success).
- **Back and Home** — both route through `_leave`, which resolves the activity, awaits
  `_persistQuizScore`, and then performs the navigation. `_leave` owns the raw navigation so
  there is no recursion, and it guards with `context.mounted` across the async gap.
- **Disposal fallback** — `_persistQuizScoreOnDispose` uses the activity id cached during
  `_resolveActivity` and the controller captured in `initState`, so it never touches `context`
  during teardown.

Duplicate protection is unchanged and layered: `_quizSaveInFlight` prevents concurrent writes,
`_quizScoreSaved` prevents repeats after success, and the controller's own best-score rule
ignores non-improving writes.

**Test.** `leaving the last question still stores the quiz score` — answers both questions, taps
"Previous step", and asserts `recordQuizScore` was called once and the store holds
`quizBestScores[_storyActivityId] == 2`; then taps Previous again and Home and asserts the call
count and store writes did not increase (no duplicates).

### F4 (Important) — `AppScope` did not propagate controller notifications

`AppScope` wrapped the child in an `AnimatedBuilder`, but `_AppScopeData.updateShouldNotify`
compared only controller identity, so once the child was built, progress changes never reached
`dependOnInheritedWidgetOfExactType` dependents.

**Fix.** `AppScope` is now a `StatefulWidget` that subscribes to the controller with
`addListener`, increments a `_revision` counter in the listener (`setState`, guarded by
`mounted`), and publishes the revision on `_AppScopeData`. `updateShouldNotify` returns true when
either the controller identity or the revision changes. `didUpdateWidget` re-attaches when the
controller is replaced and `dispose` removes the listener, so a replaced controller cannot leak a
listener. The `AnimatedBuilder` is gone.

**Tests.**
- `propagates controller notifications to descendants` — the subject screen's activity card
  changes from "Ready to start" to "Finished" after `completeActivityIfNeeded` called from outside
  the widget tree.
- `rebuilds after a recorded quiz score` — the card label changes to "Best quiz 2 of 2" after
  `recordQuizScore`.
- `replaces the controller without leaking the old listener` — a build-counting child proves the
  old controller notifies, that swapping controllers rebuilds with the new one, that the *old*
  controller no longer notifies (build count unchanged), and that the new one does.

To make the quiz score visible independently of completion, the activity-card progress label is
now built by `_activityProgressLabel`, which reports completion and best score separately.

### F5 (Important) — Class chips had no semantic tap action and were only 48dp

The chip wrapper declared `Semantics(button: true, …)` but `ExcludeSemantics`-ed the `ChoiceChip`
and provided no `onTap`, so a screen reader could identify the chip but not activate it. The
chips also fell below the 64dp minimum used everywhere else.

**Fix.** `ClassFilter` now passes `onTap: () => onSelected(classId)` and an explanatory
`hint: 'Show activities for Class N'` on each chip's semantics node, and wraps the chip in a
`ConstrainedBox` with `kClassTargetSize` (64dp) minimum width and height. The exported
`kClassTargetSize` constant makes the target explicit and testable. The chips remain operable by
pointer and by semantics.

**Tests.** `every class chip meets the 64dp minimum size` asserts width and height ≥ 64 for
Class 1–5. `a class chip exposes a working semantic tap action` asserts
`getSemanticsData().hasAction(SemanticsAction.tap)`, the label, that the unselected flag is false,
then invokes the action through `tester.semantics.tap(find.semantics.byLabel('Class 2'))` and
asserts the activity list switches to "Choose an activity for Class 2." and the selected flag
becomes true.

### F6 (Important) — Shipped-content fixture did not mirror the real catalog, and the parser
could not read the real formats

The test fixture used capital-first fronts for `Small abc` and reused the match-case back format
there. The shipped catalog uses `front: "a A"` with back `"Apple 🍎 | …"` for `Small abc`, and
`front: "A"` with back `"a | Apple 🍎 | …"` for `Match Letters`. The old `parseLetter` took
`frontTokens.first` as the capital, so `a A` produced capital `a` / small `A`, and it used
`details.first` as the word label, so `a | Apple 🍎 | …` produced word `a` and shifted the
translations by one. `parseWord` also assumed the emoji shares the first back segment.

**Fix.**

- **Fixture** — `test/support/activity_catalog.dart` now builds a separate `smallCards` list with
  `front: "a A"` and the plain `Word emoji | …` back, matching the shipped values; `matchCards`
  keeps the `front: "A"` / `back: "a | …"` format; `capitals`, `numbers`, and `first-words` are
  unchanged from the shipped shapes.
- **`parseLetter`** — classifies each front token by case to find the capital and the small
  letter regardless of order; scans the back for a bare letter (the small letter) and collects the
  remaining labelled segments; derives the capital as front-capital → back-bare uppercased →
  first front token uppercased, and the small letter as front-small → back-bare → lowercased
  capital. `word` and `emoji` come from the first labelled segment, and `translations` are the
  segments after it. A new `GameLetter.smallFromBack` flag records whether the small letter came
  from the back.
- **Round-game mode** — `_matchesSmallLetters` replaces the `activity.id.endsWith('match-case')`
  heuristic, so the match-case presentation (capital target, small-letter options, "Match me!")
  is selected from the content itself.
- **`parseWord`** — drops a leading back segment that merely repeats the front word, so both
  `CAT 🐱 | …` and `CAT | 🐱 | …` yield the same word, emoji, and translations.
- **`parseNumber`** — guards the empty-details case for the word/translation split.

**Tests.** Four focused parser unit tests cover the capital-first book, the small-first book, the
match-case back format, and the no-small-letter fallback; a fifth covers the shipped number and
word back formats including the split-word variant; and `parses every shipped little Stars card`
runs the parsers over the real `assets/content/catalog.json` for all six migrated `little`
activities, asserting case-correct capital/small pairs, non-empty word and emoji, exactly two
translations, and the correct `smallFromBack` for match-case. Two widget tests cover the small
letter book detail and the two round-game presentations.

**Mutation check.** I temporarily reverted `parseLetter` to the pre-fix implementation and ran the
parsing group: `reads the shipped small-first letter book` failed with `Expected: 'A' / Actual:
'a'`, `reads the shipped match-case back format` failed with `Expected: 'Apple' / Actual: 'a'`,
and `parses every shipped little Stars card` failed with `Expected: 'A' / Actual: 'a'` — 3 of 6
parsing tests failed. The fix was then restored and all 6 pass. The new tests do catch the shipped
values.

## Files changed in this fix round

| File | Change |
|---|---|
| `lib/features/learning/activity_screen.dart` | `_recordPractice` / `_persistQuizScore` latch only after a successful write and expose retry; `_SaveRetryNotice`; `_leave` / `_leaveQuiz` / `_persistQuizScoreOnDispose` flush the quiz score on every exit; `_controller` and `_activityId` cached for the disposal path; `_trySave` replaces `_guard`; added `_quizError`, `_practiceError`, `_quizSaveInFlight`, `_practiceSaveInFlight`. |
| `lib/app/app_scope.dart` | Rewritten as a `StatefulWidget` with a revision counter, explicit listener attach/detach, and `updateShouldNotify` on controller identity **or** revision. |
| `lib/features/learning/subject_screen.dart` | Class chips get a real `onTap`, a `hint`, and a 64dp `ConstrainedBox` via the new `kClassTargetSize`; activity-card progress label extracted into `_activityProgressLabel` so best quiz score is reported independently of completion. |
| `lib/features/games/game_screen.dart` | `parseLetter` / `parseWord` / `parseNumber` handle the real capital-first, small-first, and match-case formats; `GameLetter.smallFromBack` added; `_matchesSmallLetters` replaces the id-based match-case heuristic. |
| `test/features/activity_screen_test.dart` | 17 new tests: `a completion save failure shows a child-safe message`, `a practice save failure keeps the child on the step`, `a quiz save failure keeps the child on the quiz`, `leaving the last question still stores the quiz score`, `the small letter book reads the shipped small-first fronts`, `the match game offers small letters for a capital target`, `the find game offers capital letters for a capital target`, 6 `migrated content parsing` tests, 3 `app scope` tests, 2 `class selector accessibility` tests. |
| `test/support/fakes.dart` | Added `TestRecordingProgressStore` (configurable `failuresRemaining`, records saved snapshots). |
| `test/support/activity_catalog.dart` | `Small abc` fixture now mirrors the shipped `a A` front and plain `Word emoji | …` back. |

**Not touched (per instruction):** `lib/core/audio/audio_service.dart`,
`lib/core/speech/speech_service.dart`, `lib/app/app_controller.dart`, `lib/data/**`, `pubspec.yaml`,
and all legacy files (`lib/little_*.dart`, `lib/catalog.dart`, `lib/models.dart`,
`lib/progress_store.dart`, `lib/main.dart`). `assets/**` is unmodified (74 files).

## Commands and results (fix round)

```
> flutter test test/features/activity_screen_test.dart -r expanded
00:17 +40: All tests passed!
```

```
> flutter test
00:22 +107: All tests passed!
```

```
> flutter analyze
Analyzing School...
No issues found! (ran in 3.1s)
```

```
> dart format --output=none --set-exit-if-changed lib/app/app_scope.dart lib/app/router.dart \
    lib/features/learning/activity_screen.dart lib/features/learning/learning_shell.dart \
    lib/features/learning/lesson_audio.dart lib/features/learning/subject_screen.dart \
    lib/features/games/game_screen.dart test/features/activity_screen_test.dart \
    test/features/home_screen_test.dart test/support/activity_catalog.dart test/support/fakes.dart
Formatted 11 files (0 changed) in 0.05 seconds.
format exit=0
```

The focused file was run four extra times for flakiness: `+40: All tests passed!` each time.
The mutation check described in F6 was performed and reverted; the final tree is the fixed tree.

## Remaining concerns after the fix round

1. `AudioService` still cannot settle inside `flutter_test`'s fake-async zone, so the two audio
   tests keep the `tester.runAsync` workaround. Unchanged from the first round; the audio/speech
   services were out of scope for this round.
2. The disposal-time quiz-score flush is best-effort — if the app is being torn down the write may
   not land. All user-initiated exits await the write before navigating.
3. `kQuizAttempts = 2` still caps the quiz at one gentle retry before the answer is revealed.
4. `AppRouter.routes(...)` is still unused and could be removed or wired as the single source for
   `onGenerateRoute` in Task 6.
5. Long detail content still scrolls on a 320x640 surface; the pinned action bar keeps primary
   actions reachable, but Task 6 should re-check under large text scale.
6. `lib/little_screens.dart` is still present and unreferenced, as instructed. Task 6 owns removal.
