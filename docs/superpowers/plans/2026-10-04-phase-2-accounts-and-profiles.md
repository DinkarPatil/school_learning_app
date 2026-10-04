# Phase 2 Plan — Accounts and Profiles

Spec: `docs/superpowers/specs/2026-09-25-all-kids-ai-learning-app-design.md`
Phase definition (spec §2.1): *"Accounts and profiles: FastAPI auth, email
verification, parent PIN, child profiles, profile-scoped progress, and sync."*

Status: in progress. Milestone 1 complete; Milestones 2-4 pending.

## Why a backend is required

Phase 1 deliberately shipped no backend, so all progress is local and
profile-scoped only in the sense that `ProgressStore` namespaces its keys by
`profileId`. There is no account, no cross-device sync, and no server-side
ownership check. Everything in this phase that cannot be done on-device is
listed in the spec and is out of scope for the Flutter client alone.

## Fixed decisions (taken from the spec, not open questions)

| Decision | Value | Spec |
|---|---|---|
| Location | `backend/` beside the Flutter app | §6 |
| DB, tests | isolated SQLite, fresh per test scope | §6 |
| DB, production | Neon PostgreSQL via `DATABASE_URL` | §6 |
| DB layer | async, provider-neutral repository boundary | §6 |
| API prefix | `/api/v1` | §6.1 |
| Password + PIN hash | Argon2id | §6.2, §9 |
| Tokens | short-lived access, rotated and revocable refresh | §6.2, §9 |
| Ownership | every profile/progress query scoped to the parent account | §6.3, §9 |
| Sync | local-first, monotonic merge of set-like completions and best scores | §8 |
| Secrets | env or secret manager only; never in assets, source, or requests | §9 |
| Errors | stable codes and child-safe messages, separate from diagnostics | §6.1 |
| Logging | never log tokens, passwords, raw child questions, raw AI responses | §6.1, §9 |
| Rate limits | login and password reset at minimum | §6.1, §9 |

## Milestones

### Milestone 1 — backend foundation and auth core (done)

Package skeleton per spec §6, environment configuration, async database layer that
runs on both SQLite and PostgreSQL, schema for parent accounts, child profiles,
refresh tokens and email-verification records, Argon2id hashing, JWT access tokens
with rotating refresh tokens, and `signup` / `login` / `refresh` / `logout`.

### Milestone 2 — email verification, password reset, parent PIN

`verify-email`, `request-password-reset`, `confirm-password-reset`,
`PUT /parent/pin`, `POST /parent/pin/verify`. Introduces a pluggable mailer whose
development transport writes to the log; no real email provider is wired in this
phase, and no provider credentials are added.

### Milestone 3 — child profiles and progress sync

`GET/POST /profiles`, `PATCH/DELETE /profiles/{id}`,
`GET/PUT /profiles/{id}/progress`, `POST /profiles/{id}/sync`. Ownership checks on
every route. Idempotent monotonic merge so a later offline session cannot erase
earlier progress. Account deletion, child deletion, and progress reset.

### Milestone 4 — client onboarding, profiles, and offline-aware sync

Flutter: parent language choice, signup/login, email verification notice, PIN
setup, child profile creation, a profile picker that gates entry to child mode, and
a `ProfileStore` that maps a server profile onto the existing per-profile
`ProgressStore`. Network states follow spec §11 (loading, success, offline,
authentication expired, rate limited). Local learning keeps working with no
account; only sync needs the network.

## Client groundwork already in place

- `ProgressStore(profileId:)` namespaces `learning_progress_v2:<profileId>`, so a
  child profile maps onto a profile id with no data migration.
- `ProgressSnapshot` is already a set of completed activity ids plus a map of quiz
  best scores, which is exactly the merge shape the spec asks for in §8.
- `AppStartupState` already distinguishes loading, ready, and failed, which is the
  seed of the network state model in §11.

## Constraints carried forward

- No OpenAI calls in this phase; the teacher endpoint is Phase 3.
- No billing; `FREE_MODE` and `BILLING_ENABLED` exist as explicit server flags only.
- No child full names, birth dates, or school records collected.
- Flutter tests must stay green throughout; the backend is additive.
- `.env.example` documents variable names only and contains no credentials.

## Verification per milestone

Backend: `ruff format --check`, `ruff check`, `mypy`, `pytest`.
Client: `dart format --set-exit-if-changed lib test`, `flutter analyze`,
`flutter test`, `flutter build apk --debug`.