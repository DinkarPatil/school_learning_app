### Task 5: Implement resumable subjects, activities, and migrated games

**Files:**
- Create: `lib/features/learning/subject_screen.dart`
- Create: `lib/features/learning/activity_screen.dart`
- Create: `lib/features/games/game_screen.dart`
- Test: `test/features/activity_screen_test.dart`
- Modify: `lib/app/router.dart`

**Interfaces:**
- `SubjectScreen` receives `AppController` through an inherited app scope.
- `ActivityScreen(activityId)` resolves content through `AppController`.
- `GameScreen(activityId)` adapts the existing letter, number, word, and matching content to the new route.
- Activity completion calls `AppController.completeActivity(activityId)` exactly once per completed activity.

- [ ] **Step 1: Write failing activity tests**

Cover subject selection, unknown activity, story step, quiz feedback, practice completion, audio fallback, and returning Home:

```dart
testWidgets('unknown activity shows a recoverable message', (tester) async {
  final dependencies = _testDependencies();
  await tester.pumpWidget(SchoolLearningApp(dependencies: dependencies));
  await tester.pumpAndSettle();

  dependencies.controller.openActivity('missing');
  await tester.pumpAndSettle();

  expect(find.text('Let us choose something else'), findsOneWidget);
  expect(find.text('Go home'), findsOneWidget);
});
```

- [ ] **Step 2: Run the focused test and verify it fails**

Run: `flutter test test/features/activity_screen_test.dart -r expanded`  
Expected: FAIL because the activity screens do not exist.

- [ ] **Step 3: Implement subject selection**

Render subject cards with unique icons, high-contrast labels, and activity progress. Use a responsive grid with wrapping constraints; do not use the old five-column number grid or fixed three-button game rows.

- [ ] **Step 4: Implement the resumable activity flow**

Render one step at a time: story/listen, flashcards, quiz, practice, and reward. Keep step state in the activity widget, save completion only after the final meaningful action, and provide a persistent Home action.

- [ ] **Step 5: Add visual quiz feedback**

Show a large success animation or a gentle retry state. Store quiz score through the controller’s serialized progress writer. Speak the result when speech is available.

- [ ] **Step 6: Adapt the existing games**

Render the migrated letter, number, word, find-letter, and match-case activities through `GameScreen`. Replace `Navigator.maybePop()` exits with an explicit route callback to the home/activity route.

- [ ] **Step 7: Run the focused test and verify it passes**

Run: `flutter test test/features/activity_screen_test.dart -r expanded`  
Expected: PASS.
