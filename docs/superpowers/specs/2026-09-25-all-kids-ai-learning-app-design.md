# All-Kids AI Learning App Design

**Date:** 2026-09-25  
**Status:** Approved design; ready for implementation planning  
**Scope:** Full Flutter client rewrite plus a new Python/FastAPI service

## 1. Purpose and approved decisions

The application is a child-first learning companion for all children, not an age-gated product. Children can use it independently, while grown-ups manage the account, safety, privacy, and future payments.

Approved product decisions:

- Use one shared home and one progressive learning path for all children.
- Use a full Flutter client rewrite rather than layering features onto the current monolithic shell.
- Keep the existing learning content and audio assets where they are valid, but move them behind clear content and data boundaries.
- Add a cloud AI teacher backed by an OpenAI model through a Python/FastAPI API.
- The AI is a teacher for the current lesson or activity only, not a general-purpose chatbot.
- Use voice-first interaction with a text fallback.
- Support English, Hindi, and Marathi.
- Store learning progress and minimal safety events; do not store raw AI conversations.
- Protect parent features with a parent PIN.
- Add parent email/password authentication and parent-managed child profiles.
- Start with free access to all classes.
- Design for future class-based payments with both one-time unlocks and subscriptions.
- Keep payments and billing behind a server-verified entitlement system.

## 2. Goals and non-goals

### Goals

- A child can open the app, choose an activity, learn, play, and ask for help without adult intervention.
- Every primary action is understandable through visual design, audio, or a short label.
- The child can move forward and backward without dead ends.
- Existing lessons, stories, flashcards, quizzes, drawing practice, letters, numbers, words, and games remain available through the new experience.
- A child profile has independent, durable progress.
- A parent can create an account, manage child profiles, and later manage class access.
- The AI gives short, lesson-grounded explanations and hints in the selected language.
- The OpenAI API key never ships in the mobile application.
- Learning and games continue offline; network-dependent features fail safely.
- The code has clear boundaries so content, UI, persistence, authentication, AI, and billing can be tested independently.

### Non-goals for the first release

- General web search or an open-ended chatbot.
- Child-facing payment collection or account recovery.
- Storing raw voice recordings or AI transcripts.
- A complete content-authoring system.
- A social feed, messaging between children, advertising, or public profiles.
- Pretending that local payment state is authoritative.

### 2.1 Delivery phases

This is a program-level design delivered in independently verifiable phases:

1. **Client foundation:** shared content format, app shell, child navigation, local progress migration, audio/speech service boundaries, responsive/accessibility foundations, and offline learning.
2. **Accounts and profiles:** FastAPI auth, email verification, parent PIN, child profiles, profile-scoped progress, and sync.
3. **AI teacher:** lesson-scoped OpenAI endpoint, voice/text interaction, safety rules, local fallback, and child-facing teacher UI.
4. **Billing:** provider adapter, one-time and subscription plans, verified webhooks, entitlements, parent checkout, and feature flags.

The first free release includes phases 1–3. Phase 4 remains disabled until provider credentials, legal copy, and sandbox webhooks are configured. Each phase must pass its own tests before the next phase is considered complete.

## 3. Users and primary journeys

### 3.1 First-run parent onboarding

1. Parent chooses the app language: English, Hindi, or Marathi.
2. Parent signs up with email and password or logs into an existing account.
3. Parent verifies the email address.
4. Parent creates a PIN for sensitive parent actions.
5. Parent creates one or more child profiles.
6. Each child profile has a display name, avatar, preferred language, and optional broad age band used only for content suggestions.
7. Parent enters child mode by selecting a profile.

Child profiles do not have email addresses, passwords, or payment controls.

### 3.2 Independent child mode

The child sees a simple Learning Home with:

- **Continue learning:** resumes the last activity or offers a first activity.
- **Choose a subject:** large visual subject cards.
- **Play and learn:** letters, numbers, words, matching, and finding games.
- **Ask your teacher:** a large voice-first AI help button available from every learning screen.
- **Progress:** a visual star or badge summary without requiring reading.

There is no age gate. The existing class and activity content is presented as a progression rather than as separate age-branded products.

### 3.3 Learning activity

A lesson activity is divided into short, resumable steps:

1. Listen or read the story.
2. Explore flashcards.
3. Answer a small quiz.
4. Draw, trace, or practice.
5. Receive a visual and spoken completion reward.
6. Return home or ask the teacher for a hint.

A child can enter and leave activities at any point. Completion is based on meaningful activity state, not a no-op button.

### 3.4 Ask the teacher

1. Child taps the large microphone button.
2. The child speaks a question or chooses a suggested prompt such as “Give me a hint.”
3. The app transcribes the question using the device speech service.
4. The API receives the question, language, child profile, and current activity identifier.
5. FastAPI loads the authoritative activity context and asks the OpenAI model for a short teacher response.
6. The app displays the response and speaks it with local text-to-speech.
7. The child can replay, ask for a shorter explanation, or return to the activity.

The assistant does not accept unrelated general questions. It stays with the current lesson and suggests a next learning step.

### 3.5 Parent area

The parent area is reached through a small lock control and requires the parent PIN. It contains:

- Child profile management.
- Language and accessibility preferences.
- Progress summaries for each child.
- Account and session management.
- Class access and future billing controls.
- Safety and privacy information.
- Account deletion and progress reset controls.

### 3.6 Future payment journey

1. Parent opens class access from the parent area.
2. Parent selects a class and either a one-time unlock or a subscription.
3. The app opens a provider-hosted checkout session.
4. The provider verifies payment and sends a signed webhook to FastAPI.
5. FastAPI updates the parent account’s class entitlements.
6. The app refreshes access and shows the unlocked class to the selected child profiles according to the parent’s settings.

Payments are never initiated from child mode.

## 4. Child experience and accessibility rules

- Use high-contrast text and surfaces; do not place essential white text on low-contrast pastel backgrounds.
- Use large touch targets, with primary actions at least 64dp tall and no essential target smaller than 48dp.
- Pair every important icon with a short label or semantic label.
- Use spoken prompts and local text-to-speech for reading support.
- Use visual feedback, animation, and haptics in addition to sound.
- Never use shame, embarrassment, threats, or failure language.
- Wrong answers invite retry and provide a smaller hint before showing the answer.
- Avoid fixed layouts that assume a particular font scale or screen size.
- Respect larger system text while keeping primary actions visible and usable.
- Use responsive grids and wrapping layouts instead of cramped fixed rows.
- Give every route a visible, predictable back action and a Home action.
- Stop or pause audio when leaving a screen.
- Provide a friendly offline state rather than a technical error.
- Add semantic labels to icon buttons, custom tap targets, drawing controls, and microphone controls.
- Keep payment, account, PIN, and privacy controls out of the child’s primary navigation.

## 5. Flutter client architecture

The client will be rewritten into focused modules rather than one large `main.dart`.

Proposed structure:

```text
lib/
  app/
    app.dart
    router.dart
    theme.dart
    app_controller.dart
  core/
    auth/
    network/
    storage/
    speech/
    audio/
    errors/
    accessibility/
  data/
    content/
    models/
    repositories/
    services/
  features/
    onboarding/
    profiles/
    home/
    learning/
    games/
    teacher/
    parent/
    billing/
```

The exact file names may be adjusted to match implementation conventions, but each module must have one clear responsibility.

### 5.1 App state and dependencies

- Use a small application controller based on Flutter’s built-in `ChangeNotifier` unless implementation constraints justify a different existing-compatible approach.
- Keep network, storage, speech, audio, and repositories behind interfaces so widgets can be tested without live services.
- Store the active parent session and child profile in a session controller.
- Keep local progress in a profile-scoped repository.
- Keep server synchronization separate from local writes.
- Inject services through constructors or a small composition root rather than creating global clients inside widgets.

### 5.2 Navigation

- Use named routes and a centralized route table built on Flutter navigation primitives.
- Keep a child-mode navigation stack separate from parent/onboarding routes.
- Preserve a Home route and predictable back behavior.
- Never use `maybePop()` as the only exit from a game or detail screen owned by a parent route.
- Stop speech and audio when a route is left.

### 5.3 Content model

Use stable IDs for all content:

- `classId`
- `subjectId`
- `chapterId`
- `activityId`
- `activityType`
- `language`

Content must support title, instructions, story, flashcards, quiz questions, practice prompts, audio references, and translations. The existing English, Hindi, and Marathi catalog data should be migrated into a shared, versionable content format rather than duplicated in widgets.

The content format should be readable by both the Flutter asset pipeline and FastAPI so the backend can validate the current activity without trusting arbitrary client-provided lesson text.

### 5.4 Audio and speech

- Create an audio service with play, pause, replay, stop, completion, and error streams.
- Validate an asset before playback; a missing asset must not leave a loading or playing state stuck.
- Fall back to local TTS when a lesson audio file is unavailable.
- Keep word highlighting approximate for the first release, but prevent it from blocking the activity.
- Add a speech-to-text adapter for the microphone flow, with a text input fallback.
- Use local TTS for the AI response after the API returns text.

## 6. FastAPI service architecture

Create a Python service under `backend/` with a clear package layout:

```text
backend/
  app/
    main.py
    config.py
    dependencies.py
    security/
    db/
    models/
    schemas/
    routers/
      auth.py
      profiles.py
      learning.py
      teacher.py
      billing.py
    services/
      auth_service.py
      content_service.py
      teacher_service.py
      billing_service.py
    prompts/
  tests/
  requirements.txt
  .env.example
```

Use an async database layer with a provider-neutral SQLAlchemy-style repository boundary. Automated tests use an isolated SQLite database. Production uses Neon PostgreSQL through the `DATABASE_URL` environment variable. The schema, migrations, queries, and repository contracts must work on both SQLite and PostgreSQL; production code must not depend on SQLite-only behavior. Test fixtures create and dispose a fresh database for each test scope.

The backend environment must provide separate test and production configuration. `.env.example` documents variable names but contains no real credentials. Required configuration includes `DATABASE_URL`, `TEST_DATABASE_URL`, `OPENAI_API_KEY`, `OPENAI_MODEL`, `JWT_SIGNING_SECRET`, `CORS_ORIGINS`, `FREE_MODE`, and `BILLING_ENABLED`; payment provider variables are added when billing is enabled. The Neon connection string, OpenAI key, payment secrets, and token-signing secrets are supplied only through local environment files or the deployment secret manager.

### 6.1 API conventions

- Prefix all application endpoints with `/api/v1`.
- Use JSON request and response schemas.
- Validate lengths, allowed language codes, activity IDs, and enum values.
- Return consistent error codes and child-safe user messages separately from internal diagnostic details.
- Require HTTPS in deployed environments.
- Apply request rate limits to auth, AI, and billing endpoints.
- Never log access tokens, passwords, raw child questions, or raw AI responses.

### 6.2 Authentication endpoints

Initial routes:

- `POST /api/v1/auth/signup`
- `POST /api/v1/auth/login`
- `POST /api/v1/auth/refresh`
- `POST /api/v1/auth/logout`
- `POST /api/v1/auth/verify-email`
- `POST /api/v1/auth/request-password-reset`
- `POST /api/v1/auth/confirm-password-reset`

Use a modern password hash such as Argon2id. Access tokens are short-lived. Refresh tokens are rotated, revocable, and stored securely on the device.

### 6.3 Profile and progress endpoints

Initial routes:

- `GET /api/v1/profiles`
- `POST /api/v1/profiles`
- `PATCH /api/v1/profiles/{profile_id}`
- `DELETE /api/v1/profiles/{profile_id}`
- `GET /api/v1/profiles/{profile_id}/progress`
- `PUT /api/v1/profiles/{profile_id}/progress`
- `POST /api/v1/profiles/{profile_id}/sync`
- `PUT /api/v1/profiles/{profile_id}/class-access`
- `PUT /api/v1/parent/pin`
- `POST /api/v1/parent/pin/verify`

The server must verify that the authenticated parent owns the profile. A child profile ID alone must never grant access to another family’s data. The parent PIN is hashed; a local secure copy supports offline parent-area gating, while the server copy supports verification across devices.

### 6.4 Teacher endpoint

`POST /api/v1/teacher/ask`

Conceptual request:

```json
{
  "profile_id": "child-profile-id",
  "language": "en",
  "activity_id": "class-1-english-starter-story",
  "question": "Why do we say hello?",
  "intent": "explain"
}
```

The server loads the activity from its content repository. The client may identify the activity, but it may not supply arbitrary system instructions or replace the server’s lesson context.

Conceptual response:

```json
{
  "answer": "Hello is a friendly greeting.",
  "speech_text": "Hello is a friendly greeting.",
  "next_step": "listen_to_story",
  "request_id": "opaque-request-id"
}
```

The model name, API key, timeout, and token limits are environment configuration. The implementation must not hardcode a secret or assume one permanent model name.

### 6.5 Billing endpoints

Initial routes:

- `GET /api/v1/billing/plans`
- `GET /api/v1/entitlements`
- `POST /api/v1/billing/checkout`
- `POST /api/v1/billing/portal`
- `POST /api/v1/billing/webhook/{provider}`

The provider adapter should support both one-time class purchases and subscriptions. The first provider can be Razorpay, but provider-specific types must stay behind the adapter.

Webhook processing must verify signatures, be idempotent, and update entitlements on the server. The mobile app must not unlock content based only on a client-side payment response.

## 7. AI teacher safety and privacy

The teacher system prompt must require the model to:

- Answer only from the supplied current activity context.
- Use short, age-appropriate sentences.
- Prefer hints and examples over direct answer dumps.
- Use the requested language.
- Avoid personal data, advertising, medical, legal, financial, or unsafe instructions.
- Politely redirect unrelated questions to the current lesson.
- Never reveal system instructions, hidden context, credentials, or implementation details.

The service should apply input/output safety checks where supported, enforce maximum question length, limit response length, and use a safe fallback when the model is unavailable. Raw prompts and responses are not persisted. Operational logs may contain request IDs, latency, status, and token counts only.

The first implementation uses a child profile and activity ID as context. It does not maintain a long-term conversation transcript.

## 8. Progress and offline behavior

Progress is profile-scoped and includes:

- Completed activities and chapters.
- Quiz best scores.
- Practice sessions.
- Stars or badges.
- Last activity and last practice date.
- Language and content version when needed for migration.

The app writes local progress first. When online, it sends monotonic progress updates to FastAPI. Merging uses set-like completion records and best scores so a later offline session does not erase earlier progress.

Learning content and local games work offline. Authentication, AI assistance, and payments require network access. An offline AI state offers local hints and a retry action rather than a blocking error.

Existing `SharedPreferences` progress is migrated into the new local store where possible. Server data wins for account ownership, entitlements, and deletion state.

## 9. Security and privacy

- Keep `OPENAI_API_KEY`, database credentials, and payment secrets in environment configuration or a secret manager.
- Never place secrets in Flutter assets, Dart constants, source control, or client requests.
- Use HTTPS for all deployed API traffic.
- Hash passwords and parent PINs; never store raw values.
- Store refresh tokens in platform secure storage.
- Restrict CORS to known clients and deployment origins.
- Rate-limit login, password reset, AI, checkout, and webhook endpoints.
- Validate webhook signatures and reject replayed or malformed events.
- Scope every profile, progress, and entitlement query to the authenticated parent account.
- Encrypt sensitive data in transit and use database/provider encryption at rest where available.
- Provide account deletion, child-profile deletion, and progress reset flows.
- Do not collect child full names, birth dates, school records, or unnecessary personal information.
- Do not retain raw voice recordings or AI conversation history.

## 10. Billing and entitlements

The first release is free. Billing remains disabled until provider credentials, plans, webhooks, legal copy, and parent-facing flows are configured. The backend and client must expose explicit `FREE_MODE` and `BILLING_ENABLED` configuration flags; neither flag may be inferred from a client-side preference.

A future entitlement contains at least:

- Parent account ID.
- Class ID.
- Access type: one-time or subscription.
- Provider and provider reference.
- Status: pending, active, cancelled, expired, or refunded.
- Start and expiry timestamps where applicable.
- Created and updated timestamps.

Access rules:

- A free account can use all currently published content while free mode is enabled.
- A paid class is accessible when an active entitlement exists.
- A subscription grants access to its configured classes until expiry or cancellation.
- A parent can assign paid class access to one or more child profiles.
- Children see a friendly lock and an ask-a-grown-up message for locked content.
- Access checks happen on the server for protected content and on the client for immediate UX feedback.

## 11. Error handling and recovery

Every network-dependent feature has explicit states:

- Loading.
- Success.
- Offline.
- Authentication expired.
- Rate limited.
- Provider unavailable.
- Safe retry.
- Parent action required.

Examples:

- AI unavailable: show a local hint, a replay button, and “Ask again.”
- Payment pending: show pending status and do not grant access until a verified webhook succeeds.
- Payment failed: return to the parent area with a clear retry option.
- Expired session: return to parent login while preserving local learning progress.
- Corrupt local data: load a safe empty snapshot and offer a repair/reset path.
- Missing audio: use TTS or show a friendly unavailable message.
- Child exits a game: return to the activity or Home route, never a blank or stuck screen.

## 12. Testing strategy

### Flutter tests

- App bootstrap and onboarding navigation.
- Parent signup/login state and secure session handling.
- Child profile creation and profile isolation.
- PIN gate behavior.
- Child-mode navigation and guaranteed exits.
- Progress migration, local save, and monotonic sync merge.
- Lesson completion, quiz feedback, and practice completion.
- Audio service success, missing asset, stop, and error states.
- Teacher client request mapping and all response states.
- Text-scale and narrow-screen widget smoke tests.
- Semantics labels for primary controls.

### FastAPI tests

- Signup, login, refresh rotation, logout, and password reset.
- Parent ownership checks for every profile and progress route.
- Content lookup and invalid activity IDs.
- Teacher endpoint language selection and lesson-only context.
- OpenAI success, timeout, refusal, and unavailable states.
- Input limits and rate limiting.
- Checkout creation, webhook signature validation, idempotency, and entitlement updates.
- No secrets or raw conversations in logs.
- Database repositories and migrations pass against isolated SQLite test databases.
- A Neon/PostgreSQL compatibility check runs against a non-production Neon test database when credentials are available.

### Manual acceptance

- Fresh install and first-run onboarding.
- Independent child use on a small Android device.
- English, Hindi, and Marathi playback.
- Offline lesson and game completion.
- AI help for correct, incorrect, and unrelated questions.
- Large system text and accessibility labels.
- Parent PIN, profile switching, logout, and account deletion.
- Disabled billing state in the free release.

## 13. Definition of done

The implementation is complete when:

- The Flutter client no longer depends on the current monolithic navigation shell.
- All approved existing learning content is reachable from the new child journey.
- Children can navigate, learn, play, and exit activities without adult help.
- Parent email/password authentication works through FastAPI.
- Parent-managed child profiles have isolated progress.
- The AI teacher is voice-first, multilingual, lesson-scoped, and protected by a server-side OpenAI key.
- Raw AI conversations are not retained.
- Parent features are PIN-protected.
- The app remains useful offline for local learning and games.
- Future one-time and subscription billing is represented by server-side entitlements and verified webhooks, while remaining inactive in the free release.
- Flutter formatting, analysis, and tests pass.
- Backend tests and static checks pass.
- No secrets are committed or shipped in the client.

## 14. Rollout and migration

1. Create the new client modules and shared content format.
2. Build the FastAPI service and local development configuration.
3. Add authentication, profiles, progress sync, and parent PIN flows.
4. Migrate and verify existing content and audio paths.
5. Implement the child shell and learning activities.
6. Add the teacher endpoint and voice/text interaction.
7. Add offline/error/accessibility hardening and comprehensive tests.
8. Add billing behind disabled feature flags and provider sandbox configuration.
9. Test a free production-like release before enabling any paid plan.

The current app’s local progress should be read during migration and written into the new profile-scoped store without requiring a parent account until the child is linked to an account.
