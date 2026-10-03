import 'package:flutter_test/flutter_test.dart';
import 'package:school_learning_app/core/haptics/haptics_service.dart';

import '../support/fakes.dart';

void main() {
  test('selection and success cues reach the injected adapter', () async {
    final adapter = TestHapticFeedbackAdapter();
    final service = HapticsService(adapter: adapter);

    await service.selection();
    await service.success();

    expect(adapter.cues, <HapticCue>[
      HapticCue.selection,
      HapticCue.success,
    ]);
  });

  test('an adapter failure never reaches the child', () async {
    final service = HapticsService(adapter: TestFailingHapticFeedbackAdapter());

    await expectLater(service.selection(), completes);
    await expectLater(service.success(), completes);
  });

  test('the service defaults to the system adapter', () {
    expect(HapticsService(), isA<HapticsService>());
  });
}
