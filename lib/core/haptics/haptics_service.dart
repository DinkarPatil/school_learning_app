import 'dart:async';

import 'package:flutter/services.dart';

enum HapticCue { selection, success }

abstract interface class HapticFeedbackAdapter {
  Future<void> perform(HapticCue cue);
}

class SystemHapticFeedbackAdapter implements HapticFeedbackAdapter {
  const SystemHapticFeedbackAdapter();

  @override
  Future<void> perform(HapticCue cue) => switch (cue) {
        HapticCue.selection => HapticFeedback.selectionClick(),
        HapticCue.success => HapticFeedback.mediumImpact(),
      };
}

class HapticsService {
  HapticsService({HapticFeedbackAdapter? adapter})
      : _adapter = adapter ?? const SystemHapticFeedbackAdapter();

  final HapticFeedbackAdapter _adapter;

  Future<void> selection() => _perform(HapticCue.selection);

  Future<void> success() => _perform(HapticCue.success);

  Future<void> _perform(HapticCue cue) async {
    try {
      await _adapter.perform(cue);
    } on Object {
      return;
    }
  }
}
