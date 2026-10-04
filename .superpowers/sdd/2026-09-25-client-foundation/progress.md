# SDD ledger — plan: docs/superpowers/plans/2026-09-25-client-foundation.md

Execution mode: in-place filesystem fallback. The workspace has no Git metadata, so worktrees, commits, Git diffs, and Git-based review packages are unavailable. Implementers must not commit; task reviews inspect the named files and filesystem snapshots.

## Pre-flight conflict scan

| Tasks | Shared interface or file | Finding | Ruling |
|---|---|---|---|
| 1 → 2 | `AppFailure` | Task 1 creates the error type consumed by progress and audio tasks. | Keep `AppFailure` in Task 1 and use it from all later tasks. |
| 1 → 4 | `ContentRepository` and `ContentCatalog` | The app controller depends on repository loading and lookup. | Task 4 consumes the exact Task 1 interfaces without redefining them. |
| 2 → 4 | `ProgressSnapshot` and `ProgressStore` | The controller owns progress writes and reads. | Task 4 consumes the versioned store and serialized writes from Task 2. |
| 3 → 5 | `AudioService` and `SpeechService` | Activities need resilient playback and spoken feedback. | Task 5 consumes the injectable service contracts from Task 3. |
| 4 → 5 | `AppController`, `AppDependencies`, `AppRouter` | Screens need shared state and route arguments. | Task 5 adds only route wiring and feature screens; it does not change controller contracts. |
| 5 → 6 | Feature screens and accessibility tests | Layout and semantics work must be tested after screens exist. | Task 6 hardens the Task 4–5 screens and adds the dedicated accessibility tests. |
| 1 | Catalog JSON versus repository models | Stable IDs and language fields must agree. | Use the plan’s stable ID format and require a translated title/story for every migrated activity. |
| 2 | Legacy and versioned progress | Migration must not erase old data. | Read the new key first, migrate the legacy key, and leave the legacy key untouched. |
| 3 | Audio plugin errors | Plugin exceptions must not leak to child UI. | Convert all playback failures to `AppFailure.audioUnavailable` and reset state to idle. |
| 4 | App bootstrap and tests | Production defaults and test dependencies must use the same constructor. | `SchoolLearningApp` accepts optional `AppDependencies`; tests inject fakes. |
| 5 | Completion callbacks | Repeated taps can duplicate progress. | `completeActivity` serializes writes and is idempotent for an already-completed activity. |
| 6 | Verification commands | The existing project has no Python backend in this phase. | Run Flutter formatting, analysis, tests, and debug APK build; leave backend verification for its phase. |

## Review rulings

- Task 2 review finding about the live legacy `progress_json` writer is deferred to Task 4: Task 2 explicitly leaves `lib/main.dart` and `lib/progress_store.dart` untouched, while Task 4 owns switching the active app to the v2 store. Carrying this as a Task 4 dispatch requirement.
- Task 2 review finding about `practiceCount` addition is a real Task 2 defect: change `merge()` to use the maximum count because the v2 schema has no event IDs; direct local increments remain the caller’s responsibility.
- Task 2 review finding about legacy per-entry decoding is a real Task 2 defect: preserve valid entries and skip malformed entries instead of discarding the whole legacy snapshot.
- Task 2 review minor findings about save/load race, platform failure fallback, redundant validation, and version error consistency are deferred to the final review unless they become load-bearing.

## Review rulings

- Task 4 critical navigation finding is a real defect: Home entry must reset stale selection so the general subject flow cannot render the Little Stars track.
- Task 4 important class-filter finding is a real defect: the shell must not hardcode `class-0` or silently hide classes 2–5 before a class picker exists; derive games from the `little` subject and show all numbered-class activities in the generic subject flow.
- Task 4 important touch-target, completion-error, route-constant, test-injection, and semantics findings are real defects for this task.
- Task 4 minor findings about dead API surface, unused tokens, initialization presentation, resumability copy, test timing, and legacy-test imports are deferred to the final review/Task 6 unless a fix is needed for an important finding.
- The full-tree formatter warning is deferred to Task 6; this task’s scoped formatter is clean.
- Task 4 re-review minor findings are deferred: unused/ divergent `AppRouter.routes`, duplicate test fakes, unused route aliases/arguments, class labels in the subject list, relative asset loading in the smoke test, dialog size assertion, and controller ownership on dependency replacement. Task 5/6 or the final review should triage these.
- Task 5 critical/important findings are real: practice/quiz save failures must be surfaced and retryable, the quiz score must be saved on every exit path, AppScope must propagate controller notifications, class chips must be operable and 64dp, and the shipped-content fixture/parser mismatch must be fixed because it affects real Little Stars content.
- Task 5 minor findings about game finish feedback, dead route APIs, label-in-name text, empty semantics containers, inert Previous controls, empty audio copy, zero-quiz copy, and legacy unused files are deferred to Task 6/final review unless a fix is required for the important findings.
- Task 5 re-review minor findings are deferred: in-flight quiz disposal could issue a duplicate guarded call, exit navigation awaits a potentially slow store, game cards omit best-score labels, reward Previous can land on a disabled practice step, and the AppBar Back quiz-save path lacks a direct widget assertion. Task 6/final review should triage these.
- Task 6 important findings are real: the round-game semantics node duplicates the visible round label, quiz Previous needs the same bounded-save treatment as Home/Back, the live-region test must target the app node rather than the SnackBar, and subject `ChoiceCard` needs the same responsive treatment as the home choice card.
- Task 6 re-review found a new Important regression: the stacked `ChoiceCard` branch hard-codes a generic book badge instead of using the card’s `icon` argument, so subject/activity/game distinctions disappear at the responsive breakpoint.
- Task 6 minor findings (typed games route argument, shared shipped-catalog path helper, report wording, text-scale cap, non-live Great Job banner, disabled reward Home, and pre-existing `lib/graphify-out` placement) are deferred to the final review unless a fix is needed for the important findings.

## Final review fix wave

Brief: `.superpowers/sdd/2026-09-25-client-foundation/final-fix-brief.md`
Report: `.superpowers/sdd/2026-09-25-client-foundation/final-fix-report.md`

Rulings:

- C1, C2, I1-I8 are all addressed. The critical/important production behaviour was already in the tree when the wave resumed; continuing the wave surfaced four real defects that the brief's own requirements exposed.
- Real defect: `_OptionCard` wrapped the card in a `Stack`, and `StackFit.loose` loosened the grid's tight width so the card collapsed to 68.3dp inside a 245.3dp cell. The `InkWell` covered only the left quarter of the card, so tapping the visible centre missed. Five existing tests failed. Fixed by filling the cell explicitly; `StackFit.expand` rejected because the grid's max height is unbounded.
- Real defect: `ContentRepository` read the catalog through `CachingAssetBundle.loadString`, which memoises the returned `Future<String>` — so a failed read was cached permanently and the new C2 "Try again" action could never recover. `rootBundle` is a `CachingAssetBundle`, so this affected the real app. Fixed with `cache: false`.
- Real defect: `LearningContentState` calls `unawaited(controller.retryInitialize())` and `_initialize` rethrows, leaking an unhandled `AppFailure` into the zone. `retryInitialize` now awaits through `_swallowFailure`; `initialize()` keeps throwing for programmatic callers.
- Real defect: `ProgressSummary` filled stars proportionally to the completion fraction while its semantic label reported stars earned, so 1 of 3 activities drew 3 filled stars and announced "1 stars earned". The row now fills one star per finished activity and the label is singular/plural correct.
- Test-only gaps closed: no mid-game partial-score test, no wrong-answer accessibility assertion, no Home star-summary test, no haptics coverage at all, and no language-contract tests. 35 tests added (124 -> 159 passing).
- The shipped catalog is 83,480 bytes, so `AssetBundle.loadString` decodes it on a background isolate; that cannot complete under `testWidgets` fake async. The retry widget test uses a small repaired catalog fixture instead of the shipped file.

Task final-fix wave: complete (verification green: `dart format --set-exit-if-changed lib test` 0 changed, `flutter analyze` clean, 159 tests pass, `flutter build apk --debug` produced a fresh 210,695,795-byte APK on the final tree; filesystem-only fallback, no Git commit because workspace has no repository)

## Repository and hardening wave

Report: `.superpowers/sdd/2026-09-25-client-foundation/hardening-report.md`

Rulings:

- Git initialised in `School/` and `smart_kid_learns/`, both pushed to public repositories `DinkarPatil/school_learning_app` and `DinkarPatil/smart_kid_learns`. `smart_kid_learns/.env` holds a real `OPENAI_API_KEY`; it is gitignored and a pre-push scan of both staged trees and both public trees found no key material.
- Real defect: `AppTheme.toolbarHeight` clamped the text scale at 2.0, so past 2x the app bar stopped growing while its title kept scaling and was clipped. Measured 144dp bar against a 192dp title at 2x and a 384dp title at 3x. The clamp is removed; the toolbar now scales with the real text scale.
- Real defect: every home card measured 1400dp wide on a 1440dp surface. Added `ContentWidthLimiter` (640dp, centred) applied above `kWideSurfaceThreshold = 900`. The threshold matters: capping unconditionally changed text wrapping on the 800dp test surface and broke nine tests. Phones and small tablets are unchanged.
- Real defect: the reward action bar measured 305dp against a 191dp body at 2x. Task 6 left it alone because a second `Scrollable` broke a test helper that required exactly one match; that helper was over-constrained and now targets the first scrollable. The bar is capped at 40% of the screen and scrolls internally when it overflows.
- Real defect: `_settle` swallowed `TimeoutException`, so a stalled quiz or game save told the child nothing. Both screens now report a shared child-safe `kSaveTimeoutMessage` via an app-level SnackBar, plus inline state where the screen survives.
- Real defect: `HomeScreen` accepted `onContinue`, `onOpenSubjects`, `onOpenGames`, and `onTeacher`; no caller in `lib/` or `test/` ever passed them. Removed.
- Partial defect: the drawing pad exposed no state and only an always-enabled clear. It now reports a semantic `value` (nothing drawn / N lines drawn), offers "Undo last line", and disables both actions until a stroke exists. Pointer drawing itself is unchanged because the practice step is completable without it.
- Dismissed with evidence: the Ahem-font ceiling is a test-harness limit. The Ahem glyph is about 1.1 em wide, so no layout on a 320-360dp surface can fit the fit oracle at 2x. Fixing it literally needs a real font in test assets, which is outside Phase 1. Documented rather than worked around.
- One pre-existing test asserted the always-enabled clear action; updated to the corrected disabled state.

Task hardening wave: complete (verification green: `dart format --set-exit-if-changed lib test` 0 changed, `flutter analyze` clean, 167 tests pass, `flutter build apk --debug` produced a 210,698,297-byte APK on the hardened tree; committed and pushed)

## Phase 2 milestone 1 — backend foundation and auth core

Plan: `docs/superpowers/plans/2026-10-04-phase-2-accounts-and-profiles.md`

- The spec mandates a FastAPI service for this phase; Phase 1 deliberately shipped none. Python 3.13 and uv 0.9.18 were available, so the service was built rather than deferred.
- Backend lives at `backend/` with the package layout from spec §6. Provider-neutral async SQLAlchemy: SQLite for tests through a static pool, PostgreSQL via `DATABASE_URL`, and a `UtcDateTime` type decorator so timezone handling does not depend on the backend dialect.
- Argon2id for passwords and PINs, short-lived HS256 access tokens, and refresh tokens that rotate within a stable family. Presenting an already-rotated token revokes the whole family, which is the standard reuse-detection response.
- Passwords are never returned by any endpoint, and an unknown account still performs a real Argon2 verification so response time does not disclose whether an email is registered.
- Real defect found and fixed during the build: refresh-token rows were keyed by a fresh random id rather than the token `jti`, so every rotation and logout lookup missed and silently returned `invalid_token`.
- Real defect found and fixed during the build: the parent-safe message lookup matched error codes against enum values instead of member names, so every error degraded to a generic message.
- Tooling note: this FastAPI version's `solve_dependencies` does not short-circuit on a `Response` returned from a dependency, so the first rate-limit design silently did nothing. Rate limiting is now an explicit `enforce_rate_limit` call that raises and is handled centrally.
- Secrets remain environment-only. `.env.example` documents names with empty values. `.gitignore` excludes `backend/.venv`, `backend/.env`, and local SQLite files.
- The Flutter client is untouched and its 167 tests still pass. `ProgressStore(profileId:)` already namespaces progress per profile, so Phase 2 needs no local data migration.

Task phase-2-milestone-1: complete (verification green: `ruff format --check` clean, `ruff check` clean, `mypy --strict app tests` clean, 22 backend tests pass; Flutter format/analyze/167 tests unchanged)

Task 1: fix round 1/5 (2 addressed, 0 open; filesystem-only fallback)
Task 1: complete (review clean; no Git commit because workspace has no repository)
Task 2: fix round 1/5 (3 addressed, 0 open; filesystem-only fallback)
Task 2: complete (review clean; no Git commit because workspace has no repository)
Task 3: fix round 1/5 (4 addressed, 0 open; filesystem-only fallback)
Task 3: complete (review clean; no Git commit because workspace has no repository)
Task 4: fix round 1/5 (7 addressed, 0 open; filesystem-only fallback)
Task 4: complete (review clean; no Git commit because workspace has no repository)
Task 5: fix round 1/5 (6 addressed, 0 open; filesystem-only fallback)
Task 5: complete (review clean; no Git commit because workspace has no repository)
Task 6: fix round 1/4 (4 addressed, 0 open; filesystem-only fallback)
Task 6: fix round 2/4 (1 addressed, 0 open; filesystem-only fallback)
Task 6: complete (verification green: format 0 changed, analyze clean, 131 tests pass, debug APK built; filesystem-only fallback, no Git commit because workspace has no repository)
