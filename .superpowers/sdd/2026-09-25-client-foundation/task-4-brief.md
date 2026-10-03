### Task 4: Build the app controller, theme, router, and all-kids home

**Files:**
- Create: `lib/app/app_controller.dart`
- Create: `lib/app/theme.dart`
- Create: `lib/app/router.dart`
- Create: `lib/app/app.dart`
- Create: `lib/features/home/home_screen.dart`
- Modify: `lib/main.dart`
- Test: `test/app/app_controller_test.dart`
- Test: `test/features/home_screen_test.dart`
- Modify: `test/widget_test.dart`

**Interfaces:**
- `AppController.initialize()` loads content and progress once.
- `AppController` exposes `catalog`, `progress`, `activeClassId`, `activeSubjectId`, and `activeActivityId`.
- `AppController.openSubject(String subjectId)`, `openActivity(String activityId)`, and `completeActivity(String activityId)` update state and notify listeners.
- `AppDependencies` exposes an `AppController` plus `content`, `progress`, `audio`, and `speech` service interfaces; tests provide fakes for each service.
- `SchoolLearningApp` accepts an optional `AppDependencies` object for tests and uses production defaults otherwise.
- `AppRouter` owns route names `/`, `/subjects`, and `/activity`; the parent lock control shows a grown-ups-only notice until the account phase.

- [ ] **Step 1: Write failing controller and home tests**

Verify initialization, Continue learning, subject selection, activity selection, and the visible “Ask your teacher” affordance without requiring a network service:

```dart
testWidgets('home offers learning choices for every child', (tester) async {
  await tester.pumpWidget(SchoolLearningApp(dependencies: _testDependencies()));
  await tester.pumpAndSettle();

  expect(find.text('Continue learning'), findsOneWidget);
  expect(find.text('Choose a subject'), findsOneWidget);
  expect(find.text('Play and learn'), findsOneWidget);
  expect(find.text('Ask your teacher'), findsOneWidget);
});
```

- [ ] **Step 2: Run the focused tests and verify they fail**

Run: `flutter test test/app/app_controller_test.dart test/features/home_screen_test.dart -r expanded`  
Expected: FAIL because the new app shell does not exist.

- [ ] **Step 3: Implement the controller and dependency container**

Load content and progress concurrently during initialization. Expose typed `AppFailure` values for invalid content and corrupt progress. Serialize completion writes so rapid taps cannot overwrite newer progress.

- [ ] **Step 4: Implement the accessible theme**

Define ink, surface, primary, success, warning, and error tokens with readable contrast. Set minimum button sizes, rounded shapes, visible focus states, and a text theme that does not use fixed line heights for scaled content.

- [ ] **Step 5: Implement named routes and the home screen**

Create one scrollable home with large cards for Continue, Subjects, Games, and Teacher. Add a visible lock control for the parent route. Use `Semantics` labels and ensure every card has a minimum 64dp action height.

- [ ] **Step 6: Reduce `main.dart` to bootstrap**

Initialize bindings, create production dependencies, and run `SchoolLearningApp`. Remove the old manual `AppScreen` switch from the entry path.

- [ ] **Step 7: Run the focused tests and verify they pass**

Run: `flutter test test/app/app_controller_test.dart test/features/home_screen_test.dart test/widget_test.dart -r expanded`  
Expected: PASS.
