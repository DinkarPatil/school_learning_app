# Task 3 Report

## Status

DONE

## Files changed

- Created `lib/core/audio/audio_service.dart`
- Created `lib/core/speech/speech_service.dart`
- Created `test/core/audio_service_test.dart`
- Created `.superpowers/sdd/2026-09-25-client-foundation/task-3-report.md`

No packages were added. `pubspec.yaml` was not changed. `lib/main.dart` and `lib/little_player.dart` were not changed, so the active app bootstrap and legacy TTS singleton remain untouched as required.

## Implementation summary

### Audio service

- Added `AudioPlaybackState` with the explicit values `idle`, `loading`, and `playing`.
- Added the injectable `AudioPlayerAdapter` and `AudioPlayerFactory` contracts. The production adapter wraps `audioplayers` without exposing the plugin to tests.
- `AudioService.playAsset(String path)` returns `Future<void>`, starts in `loading`, and transitions to `playing` only after the adapter starts playback successfully.
- Playback factory, configuration, asset, stream, and player-operation failures are converted to `AppFailure.audioUnavailable` with the child-safe message. The underlying cause remains available only as the internal `AppFailure.cause`; no child content is logged.
- Every failure path resets the state to `idle`.
- Completion events transition the active service to `idle` and are forwarded to `onPlayerComplete`.
- Position, duration, and completion subscriptions are cancelled before a player is stopped, released, and disposed for replacement or explicit stop.
- `stop()` is safe when no player exists and clears the active player so repeated calls are harmless.
- Operations are serialized so rapid playback requests cannot leave an old player or state competing with a replacement.
- Optional state, position, duration, and completion streams are exposed for a later app controller without requiring platform plugins in tests.

### Speech service

- Added the injectable `SpeechEngine` and `SpeechEngineFactory` contracts with a production `FlutterTts` adapter.
- Preserved the existing gentle TTS configuration: speech rate `0.32`, pitch `1.15`, volume `1.0`, and completion waiting enabled.
- Added language mapping for `en-US`, `hi-IN`, and `mr-IN`, including short `en`, `hi`, and `mr` aliases and locale normalization.
- `SpeechService.speak(String text, {String language = 'en-US'})` returns `Future<void>` and converts plugin/configuration failures to a child-safe `AppFailure.audioUnavailable`.
- `stop()` is idempotent and does not repeatedly call the plugin after speech has completed or before speech has started.
- `speakOrFallback(primaryText, fallbackText)` always attempts the primary text, then attempts the fallback text if the primary speech attempt fails. If the fallback also fails, the service exposes the safe typed failure.
- No child text or question content is logged.

## Test coverage

`test/core/audio_service_test.dart` contains contract tests for:

- Initial idle state and safe repeated stop with no player.
- Successful asset playback and loading/playing state transitions.
- Completion transition back to idle and completion notification.
- Missing/failed asset conversion to `AppFailure.audioUnavailable` and idle-state reset.
- Player disposal before replacement and cancellation of all player subscriptions.
- Idempotent active-player stop and release.
- TTS configuration and all three supported language mappings.
- Primary speech success without fallback.
- Primary speech failure followed by fallback speech.
- Safe repeated speech stop behavior before and after speech.

## TDD and verification evidence

### RED

- Initial `flutter test test/core/audio_service_test.dart -r expanded`
  - Failed during test loading because the two requested service files and their contracts did not exist.
- A later regression test for repeated completed-speech stops failed with the pre-fix behavior (`3` plugin stop calls instead of the expected stable count), confirming the idempotence gap before the active-speech tracking fix.

### Final focused test

- `flutter test test/core/audio_service_test.dart -r expanded`
  - All 10 tests passed.

### Full Flutter suite

- `flutter test -r expanded`
  - All 39 tests passed, including the 10 new service tests and all existing content, progress, and widget tests.

### Analyzer

- `flutter analyze`
  - `No issues found!`

### Formatter

- `dart format lib/core/audio/audio_service.dart lib/core/speech/speech_service.dart test/core/audio_service_test.dart`
  - Formatted successfully.
- `dart format --output=none --set-exit-if-changed lib/core/audio/audio_service.dart lib/core/speech/speech_service.dart test/core/audio_service_test.dart`
  - `Formatted 3 files (0 changed)`.

## Concerns and integration notes

- The new services are intentionally not wired into the active app yet. `main.dart` still owns its existing player lifecycle, and `little_player.dart` still owns its legacy TTS singleton; later bootstrap/UI tasks can switch those consumers to the injectable contracts.
- The default adapters require the platform plugins on a real device, while all contract tests use in-memory fakes and do not initialize those plugins.
- Audio and speech failures preserve an internal cause for diagnostics, but the user-facing `AppFailure.message` and `toString()` remain generic and child-safe.
- Asset existence is currently discovered through the injected player/plugin failure path rather than a separate asset preflight. This keeps missing-asset behavior platform-independent and allows the later activity layer to use `speakOrFallback` for recovery.

## Fix round

### Findings addressed

1. **Silent or hanging production TTS failures**
   - Added `SpeechResult` status values for success, failure, and cancellation, including an explicit-stop marker.
   - Changed the `SpeechEngine` contract so configuration, speak, and stop operations report unsuccessful status results instead of discarding them.
   - Updated the `FlutterTts` adapter to inspect plugin return values, install completion/error/cancel handlers, settle speak operations on asynchronous events, and time out orphaned pending operations.
   - `SpeechService` converts unsuccessful speech results to `AppFailure.audioUnavailable`, preserves primary-to-fallback behavior for ordinary failures, and treats explicit cancellation as a clean completion.
   - Added fake coverage for immediate status failure, asynchronous error, asynchronous cancellation, adapter cancellation, and explicit-stop status races.

2. **Speech stop could not interrupt pending speech**
   - Replaced the tail-queued stop behavior with an immediate, serialized-safe stop path that calls the engine without waiting behind `speak()`.
   - Added per-operation cancellation and stop-outcome tracking so a successful stop settles the active speech future without fallback, while a failed stop returns a typed failure and leaves the active operation retryable.
   - Prevented failed interrupt attempts from silently swallowing the error when a new speech request is submitted.
   - Added in-flight stop, failed-stop, failed-interrupt, and stop/status-race tests.

3. **Audio stream failures did not fail the pending play operation**
   - Added a player-specific playback attempt object that owns the stream-failure completer.
   - Position, duration, and completion stream errors now mark the active attempt failed, reset state to idle, release the player, and reject the pending `playAsset()` future with `AppFailure.audioUnavailable`.
   - Added deterministic race tests for all three player streams.

4. **Disposed audio service returned a raw exception**
   - `playAsset()` after `dispose()` now returns `AppFailure.audioUnavailable` and leaves state idle.
   - Added a focused disposal contract test.

### Fix-round files changed

- Modified `lib/core/speech/speech_service.dart`
- Modified `lib/core/audio/audio_service.dart`
- Modified `test/core/audio_service_test.dart`
- Appended this fix-round section to `.superpowers/sdd/2026-09-25-client-foundation/task-3-report.md`

No packages, `pubspec.yaml`, `lib/main.dart`, or `lib/little_player.dart` changes were made.

### Fix-round RED evidence

- `flutter test test/core/audio_service_test.dart -r expanded`
  - Initial RED failed to compile because the expanded `SpeechResult`/`SpeechEngine` contract did not yet exist.
- `flutter test test/core/audio_service_test.dart -r expanded --plain-name "stream failure rejects a pending play and resets idle"`
  - Pre-fix RED failed with a pending `TimeoutException` instead of `AppFailure.audioUnavailable`.
- `flutter test test/core/audio_service_test.dart -r expanded --plain-name "play after disposal returns a typed audio failure"`
  - Pre-fix RED failed with raw `StateError: Audio service has been disposed.`
- `flutter test test/core/audio_service_test.dart -r expanded --plain-name "explicit stop wins a simultaneous speech failure result"`
  - RED reproduced an `AppFailure` escaping after an explicit stop/status race.
- `flutter test test/core/audio_service_test.dart -r expanded --plain-name "a failed stop does not settle a racing speech operation cleanly"`
  - RED showed the old implementation settling the speech operation as clean despite the stop failure.

### Fix-round exact verification commands and results

- `flutter test test/core/audio_service_test.dart -r expanded`
  - All 26 focused audio/speech/adapter tests passed.
- `flutter test -r expanded`
  - All 55 Flutter tests passed.
- `flutter analyze`
  - `No issues found!`
- `dart format lib/core/audio/audio_service.dart lib/core/speech/speech_service.dart test/core/audio_service_test.dart`
  - Formatted successfully.
- `dart format --output=none --set-exit-if-changed lib/core/audio/audio_service.dart lib/core/speech/speech_service.dart test/core/audio_service_test.dart`
  - `Formatted 3 files (0 changed)`.

### Remaining concerns

- The active app bootstrap and legacy TTS singleton remain intentionally unwired; later tasks must switch consumers to these injectable services.
- Default adapters still require the `audioplayers` and `flutter_tts` platform plugins on a device; tests use fakes and do not depend on those plugins.
- The adapter uses a 30-second completion timeout as a last-resort settlement guard; a platform integration test on each target OS is still needed to validate native callback timing.
- Typed failures retain internal causes for diagnostics, but no raw child speech text is logged and user-facing failure messages remain generic.

