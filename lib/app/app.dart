import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:school_learning_app/app/app_controller.dart';
import 'package:school_learning_app/app/router.dart';
import 'package:school_learning_app/app/route_names.dart';
import 'package:school_learning_app/app/theme.dart';
import 'package:school_learning_app/core/audio/audio_service.dart';
import 'package:school_learning_app/core/errors/app_failure.dart';
import 'package:school_learning_app/core/haptics/haptics_service.dart';
import 'package:school_learning_app/core/speech/speech_service.dart';
import 'package:school_learning_app/data/content/content_repository.dart';
import 'package:school_learning_app/data/progress/progress_store.dart';

export 'package:school_learning_app/app/app_controller.dart';
export 'package:school_learning_app/app/router.dart';
export 'package:school_learning_app/app/route_names.dart';
export 'package:school_learning_app/app/theme.dart';
export 'package:school_learning_app/features/home/home_screen.dart';

class AppDependencies {
  static const String defaultProfileId = 'local-child';

  const AppDependencies({
    required this.controller,
    required this.content,
    required this.progress,
    required this.audio,
    required this.speech,
    this.haptics,
  });

  factory AppDependencies.production({
    AssetBundle? bundle,
    String profileId = defaultProfileId,
  }) {
    final content = ContentRepository(bundle: bundle ?? rootBundle);
    final progress = ProgressStore(profileId: profileId);
    final audio = AudioService();
    final speech = SpeechService();
    final haptics = HapticsService();
    final controller = AppController(
      content: content,
      progress: progress,
      audio: audio,
      speech: speech,
      haptics: haptics,
    );
    return AppDependencies(
      controller: controller,
      content: content,
      progress: progress,
      audio: audio,
      speech: speech,
      haptics: haptics,
    );
  }

  factory AppDependencies.fromParts({
    required ContentRepository content,
    required ProgressStore progress,
    required AudioService audio,
    required SpeechService speech,
    HapticsService? haptics,
  }) {
    final controller = AppController(
      content: content,
      progress: progress,
      audio: audio,
      speech: speech,
      haptics: haptics,
    );
    return AppDependencies(
      controller: controller,
      content: content,
      progress: progress,
      audio: audio,
      speech: speech,
      haptics: haptics,
    );
  }

  final AppController controller;
  final ContentRepository content;
  final ProgressStore progress;
  final AudioService audio;
  final SpeechService speech;
  final HapticsService? haptics;
}

class SchoolLearningApp extends StatefulWidget {
  const SchoolLearningApp({
    super.key,
    this.dependencies,
  });

  final AppDependencies? dependencies;

  @override
  State<SchoolLearningApp> createState() => _SchoolLearningAppState();
}

class _SchoolLearningAppState extends State<SchoolLearningApp> {
  late AppDependencies _dependencies;
  late AppController _controller;

  @override
  void initState() {
    super.initState();
    _setDependencies(widget.dependencies);
    unawaited(_initialize());
  }

  @override
  void didUpdateWidget(covariant SchoolLearningApp oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.dependencies != widget.dependencies) {
      _controller.dispose();
      _setDependencies(widget.dependencies);
      unawaited(_initialize());
    }
  }

  void _setDependencies(AppDependencies? dependencies) {
    _dependencies = dependencies ?? AppDependencies.production();
    _controller = _dependencies.controller;
  }

  Future<void> _initialize() async {
    try {
      await _controller.initialize();
    } on AppFailure {
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'School Learning',
      theme: AppTheme.light(),
      initialRoute: RouteNames.home,
      onGenerateRoute: (settings) => AppRouter.onGenerateRoute(
        settings,
        _controller,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
