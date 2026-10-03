# Phase 1 Final Review Fix Brief

## Context

The Phase 1 client foundation is implemented and all six task reviews passed. The final whole-phase review found the following Critical/Important items. Fix them in one coordinated wave, then run the full verification suite. Do not commit and do not dispatch other agents.

## Critical findings

### C1 — Preserve unreadable versioned progress instead of silently discarding it

Files: `lib/data/progress/progress_store.dart`, `lib/data/progress/progress_models.dart`, `lib/app/app_controller.dart`, new/existing accessibility/UI tests.

Current behavior: a present but corrupt/future-schema v2 value decodes to an empty snapshot with no signal, and the next write overwrites it. This violates the spec’s safe-recovery requirement.

Required behavior:
- Distinguish absent from present-but-unreadable v2 data.
- Preserve the raw unreadable value under a recovery key or refuse destructive writes until it is handled.
- Surface a typed `AppFailure.corruptProgress` (or equivalent) through the controller so the UI can show a child-safe state.
- Add a safe parent/reset or recovery path that does not require the future account phase; at minimum provide a clear reset action in the existing grown-ups notice.
- Add tests for corrupt v2 preservation, controller failure state, and reset/recovery behavior.

### C2 — Content-load failure leaves a dead learning journey

Files: `lib/app/app.dart`, `lib/app/app_controller.dart`, `lib/features/home/home_screen.dart`, `lib/features/learning/subject_screen.dart`, tests.

Current behavior: app initialization swallows `AppFailure`; `catalog == null` renders “Learning content is getting ready.” forever, with no retry or diagnostic state.

Required behavior:
- Expose loading/ready/failed state from the controller.
- Render a child-safe failure state with a real “Try again” action that re-runs initialization safely.
- Distinguish genuine loading from failure.
- Add a widget test that injects a failing content bundle, verifies the failure state and retry action, then succeeds after a repaired bundle/controller.

## Important findings

### I1 — Persist partial round-game scores on mid-game exit

Files: `lib/features/games/game_screen.dart`, game/activity tests.

Mirror the activity quiz flow: persist a partial score on Back, Home, system back, and a guarded disposal fallback; use in-flight/duplicate guards; do not double-count. Add a test exiting after round 3 and verifying the best score is stored once.

### I2 — Wrong-answer state must not be color-only

Files: `lib/features/games/game_screen.dart`, accessibility tests.

Add a non-color indicator (icon, text, or semantic value) for a wrong option and assert it in the accessibility test. Preserve high contrast and merged semantics.

### I3 — Add a visual progress summary to Home

Files: `lib/features/home/home_screen.dart`, home/accessibility tests.

The approved spec requires a fifth all-kids home affordance: a visual star/badge progress summary. Add a non-text-dependent progress card/row built from `controller.progress`, update AppScope-driven tests, and keep large-text/64dp behavior.

### I4 — Add haptic feedback through an injectable boundary

Files: theme/app dependency or a small `core/haptics` service, quiz/game/home tests.

Spec requires visual, animation, and haptic feedback. Add a no-op-in-tests haptic abstraction and light selection feedback for options/chips plus completion feedback. Do not call platform channels directly from widgets.

### I5 — Make the multilingual content contract explicit and consumed

Files: `lib/data/content/content_models.dart`, `lib/data/content/content_repository.dart`, `assets/content/catalog.json`, game/activity UI, tests.

Current translations are non-empty but not a complete language contract and are not consumed by the UI. Without inventing translations, make the schema honest:
- Document/model the top-level content language/source and supplementary translations.
- Add an explicit language fallback/resolution helper used by activity/game UI.
- Validate the declared language metadata and ensure English/Hindi/Marathi data remains available through content or flashcard translations.
- Add tests for language resolution and shipped catalog coverage.
Do not remove Hindi/Marathi words or invent translations.

### I6 — Remove generated graphify artifacts from the source tree

Files: `.gitignore`, `lib/graphify-out/`, root `graphify-out/`, `.graphify_*` files.

These are analysis artifacts created during exploration, not product files. Add ignore entries and delete the generated artifact files/directories. Do not delete the approved spec/plan docs.

### I7 — Update user-facing documentation

Files: `README.md`, `pubspec.yaml`.

Remove the age-branded “Little Stars 4-6” framing and the nonexistent parent dashboard claim. Describe one all-kids home, offline learning, the actual subjects/content, and the later account/AI/billing phases as future work. Keep the description truthful.

### I8 — Re-run the APK build on the final tree

After all fixes, run `flutter build apk --debug` and record the fresh artifact timestamp/size. The previous APK predates the last production edit.

## Constraints

- Preserve the reviewed phase boundary: no FastAPI/auth/AI/payment implementation in this wave.
- Do not add packages, comments, secrets, or audio asset changes.
- Keep all existing tests passing; add focused tests for each new behavior.
- Keep primary actions at least 64dp and child-safe semantics.
- Use the existing `AppDependencies`/controller/service contracts; do not create a parallel state system.
- Write the full fix report to `.superpowers/sdd/2026-09-25-client-foundation/final-fix-report.md`, including files changed/deleted, findings addressed, exact commands/results, and remaining concerns.
