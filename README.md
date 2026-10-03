# School Learning App

Flutter learning app for Classes 1-5, with a Play and learn shelf of letters,
numbers, words, and gentle games. One shared home for every child, and every
learning step works offline.

## What is included today

- One all-kids home with Continue learning, Choose a subject, Play and learn,
  Ask your teacher, and a visual star summary of progress. There is no age gate
  and no age-branded home.
- Class selection for Classes 1-5, with a class chip filter.
- Nine class subjects: English, English Grammar, Marathi, Hindi, Mathematics,
  EVS, Computer, General Knowledge, and Communication.
- Play and learn shelf: capital letters, small letters, numbers 1-10, first
  words, a find-the-letter game, and a match-the-letter game.
- Five-step activity flow: listen to the story, explore flashcards, answer a
  small quiz, draw or write to practise, then a visual and spoken reward.
- Story, flashcard, and lesson audio packaged with the app, with a slow
  text-to-speech fallback (including Hindi and Marathi words) when an audio
  asset is unavailable.
- Local, profile-scoped progress: completed activities, best quiz scores,
  practice count, and the last activity and practice day.
- Safe recovery when saved progress cannot be read: the unreadable value is
  preserved, learning continues, and a grown-up can reset the saved stars from
  the lock notice.
- Accessibility: 64dp primary actions, high-contrast surfaces, merged semantic
  labels, live-region status text, large-text and narrow-screen layouts, and
  visual, animated, and haptic feedback.

## Not included yet

- Parent accounts, email/password sign-in, and child profiles (phase 2).
- The cloud AI teacher, voice questions, and lesson-grounded hints (phase 3).
- Class payments, subscriptions, and entitlements (phase 4, disabled in the
  free release).
- A parent dashboard. The lock control shows a grown-ups-only notice only.

## Stack

- Flutter / Dart, Material 3
- `shared_preferences` for local progress
- `audioplayers` for packaged lesson and flashcard audio
- `flutter_tts` for spoken prompts and the speech fallback

## Local checks

```text
dart format --set-exit-if-changed lib test
flutter analyze
flutter test
flutter build apk --debug
```
