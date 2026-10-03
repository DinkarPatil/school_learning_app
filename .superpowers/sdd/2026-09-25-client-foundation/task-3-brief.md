### Task 3: Isolate audio and speech behind recoverable services

**Files:**
- Create: `lib/core/audio/audio_service.dart`
- Create: `lib/core/speech/speech_service.dart`
- Test: `test/core/audio_service_test.dart`

**Interfaces:**
- `AudioService.playAsset(String path)` returns `Future<void>` and throws `AppFailure.audioUnavailable` on failure.
- `AudioService.stop()` is idempotent.
- `SpeechService.speak(String text, {String language = 'en-US'})` returns `Future<void>`.
- `SpeechService.stop()` is idempotent.
- Both services are injectable into the app controller.

- [ ] **Step 1: Write failing audio tests**

Use fake player and speech implementations to verify stop, completion, missing asset, and error reset:

```dart
test('failed playback leaves the service stopped', () async {
  final service = AudioService(playerFactory: _FailingPlayerFactory());

  await expectLater(
    service.playAsset('audio/missing.wav'),
    throwsA(isA<AppFailure>()),
  );
  expect(service.state, AudioPlaybackState.idle);
});
```

- [ ] **Step 2: Run the focused test and verify it fails**

Run: `flutter test test/core/audio_service_test.dart -r expanded`  
Expected: FAIL because the service contracts do not exist.

- [ ] **Step 3: Implement the audio state machine**

Wrap every `audioplayers` call in error handling. Set state to idle before and after failed playback, cancel subscriptions before replacing the player, and expose no raw plugin exception to child UI.

- [ ] **Step 4: Implement the TTS adapter and fallback helper**

Move the current TTS configuration into `SpeechService`, keep English/Hindi/Marathi language mapping, and provide `speakOrFallback(primaryText, fallbackText)` for missing lesson audio.

- [ ] **Step 5: Run the focused test and verify it passes**

Run: `flutter test test/core/audio_service_test.dart -r expanded`  
Expected: PASS.
