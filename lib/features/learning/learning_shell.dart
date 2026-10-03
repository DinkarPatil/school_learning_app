import 'dart:async';

import 'package:flutter/material.dart';
import 'package:school_learning_app/app/app_controller.dart';
import 'package:school_learning_app/app/theme.dart';
import 'package:school_learning_app/features/learning/lesson_audio.dart';

const double kPrimaryActionHeight = 64;
const double kPrimaryActionWidth = 64;

const String kContentFailedTitle = 'We cannot open the learning shelf yet';
const String kContentFailedBody =
    'Something is resting on the shelf. Please try again.';
const String kContentRetryLabel = 'Try again';
const String kProgressHiddenTitle = 'Some saved stars are hiding';
const String kProgressHiddenBody =
    'Learning still works. A grown-up can bring the old stars back.';

class LearningScaffold extends StatelessWidget {
  const LearningScaffold({
    super.key,
    required this.title,
    required this.onGoHome,
    required this.onBack,
    required this.body,
  });

  final String title;
  final VoidCallback onGoHome;
  final VoidCallback onBack;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: AppTheme.toolbarHeight(context),
        leadingWidth: AppTheme.leadingWidth(context),
        leading: LearningBackButton(onPressed: onBack),
        title: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis),
        actions: <Widget>[
          LearningHomeButton(onPressed: onGoHome),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(child: body),
    );
  }
}

class LearningBackButton extends StatelessWidget {
  const LearningBackButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: kPrimaryActionWidth,
      height: kPrimaryActionHeight,
      child: Semantics(
        button: true,
        label: 'Back',
        onTap: onPressed,
        child: ExcludeSemantics(
          child: IconButton(
            tooltip: 'Back',
            onPressed: onPressed,
            icon: const Icon(Icons.arrow_back),
          ),
        ),
      ),
    );
  }
}

class LearningHomeButton extends StatelessWidget {
  const LearningHomeButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: kPrimaryActionWidth,
      height: kPrimaryActionHeight,
      child: TextButton(
        onPressed: onPressed,
        child: const Text('Home'),
      ),
    );
  }
}

class StepHeader extends StatelessWidget {
  const StepHeader({
    super.key,
    required this.index,
    required this.total,
    required this.label,
  });

  final int index;
  final int total;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      container: true,
      label: 'Step $index of $total. $label',
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Step $index of $total',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PrimaryActions extends StatelessWidget {
  const PrimaryActions({super.key, required this.actions});

  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: actions,
      ),
    );
  }
}

const double kStackedCardWidth = 320;
const double kStackedCardTextScale = 1.15;

bool useStackedCardLayout(
  BuildContext context,
  BoxConstraints constraints,
) {
  if (constraints.maxWidth < kStackedCardWidth) {
    return true;
  }
  return MediaQuery.textScalerOf(context).scale(16) / 16 >
      kStackedCardTextScale;
}

class CardBadge extends StatelessWidget {
  const CardBadge({super.key, required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: 30, color: AppColors.primary),
    );
  }
}

class LearningActionBar extends StatelessWidget {
  const LearningActionBar({super.key, required this.actions});

  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFD7E0DE))),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: actions,
      ),
    );
  }
}

class LearningStepBody extends StatefulWidget {
  const LearningStepBody({
    super.key,
    required this.children,
    required this.actions,
  });

  final List<Widget> children;
  final List<Widget> actions;

  @override
  State<LearningStepBody> createState() => _LearningStepBodyState();
}

class _LearningStepBodyState extends State<LearningStepBody> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Expanded(
          child: ListView(
            controller: _scrollController,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            children: widget.children,
          ),
        ),
        LearningActionBar(actions: widget.actions),
      ],
    );
  }
}

class LearningMessage extends StatelessWidget {
  const LearningMessage({
    super.key,
    required this.icon,
    required this.title,
    this.body,
    this.actions = const <Widget>[],
  });

  final IconData icon;
  final String title;
  final String? body;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 56, color: AppColors.primary),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            if (body != null) ...<Widget>[
              const SizedBox(height: 8),
              Text(body!, textAlign: TextAlign.center),
            ],
            if (actions.isNotEmpty) ...<Widget>[
              const SizedBox(height: 20),
              PrimaryActions(actions: actions),
            ],
          ],
        ),
      ),
    );
  }
}

class LessonAudioBar extends StatelessWidget {
  const LessonAudioBar({
    super.key,
    required this.controller,
    required this.audioAsset,
    required this.speechText,
    this.language = 'en-US',
  });

  final LessonAudioController controller;
  final String audioAsset;
  final String speechText;
  final String language;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) => Semantics(
        container: true,
        explicitChildNodes: true,
        liveRegion: true,
        label: 'Lesson audio',
        value: controller.statusLabel,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            ExcludeSemantics(child: Text(controller.statusLabel)),
            const SizedBox(height: 10),
            PrimaryActions(
              actions: <Widget>[
                _AudioAction(
                  label: 'Listen',
                  icon: Icons.play_arrow_rounded,
                  tooltip: 'Play lesson audio',
                  onPressed: controller.isBusy ? null : () => _play(controller),
                ),
                _AudioAction(
                  label: 'Play again',
                  icon: Icons.replay_rounded,
                  tooltip: 'Play the lesson again',
                  onPressed: controller.isBusy ? null : () => _play(controller),
                ),
                _AudioAction(
                  label: 'Stop audio',
                  icon: Icons.stop_rounded,
                  tooltip: 'Stop the lesson audio',
                  onPressed: controller.isBusy ? controller.stop : null,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _play(LessonAudioController controller) {
    controller.play(
      audioAsset: audioAsset,
      speechText: speechText,
      language: language,
    );
  }
}

class _AudioAction extends StatelessWidget {
  const _AudioAction({
    required this.label,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: '$label. $tooltip',
      onTap: onPressed,
      child: ExcludeSemantics(
        child: FilledButton.icon(
          onPressed: onPressed,
          icon: Icon(icon, size: 26),
          label: Text(label),
        ),
      ),
    );
  }
}

class LearningContentState extends StatelessWidget {
  const LearningContentState({
    super.key,
    required this.controller,
    required this.title,
    required this.onGoHome,
    required this.onBack,
  });

  final AppController controller;
  final String title;
  final VoidCallback onGoHome;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return LearningScaffold(
      title: title,
      onGoHome: onGoHome,
      onBack: onBack,
      body: switch (controller.startupState) {
        AppStartupState.ready => const SizedBox.shrink(),
        AppStartupState.loading => _loading(context),
        AppStartupState.failed => _failed(context),
      },
    );
  }

  Widget _loading(BuildContext context) {
    return const LearningMessage(
      icon: Icons.auto_stories_outlined,
      title: 'Learning content is getting ready.',
    );
  }

  Widget _failed(BuildContext context) {
    return LearningMessage(
      icon: Icons.cloud_off_rounded,
      title: kContentFailedTitle,
      body: kContentFailedBody,
      actions: <Widget>[
        FilledButton.icon(
          onPressed: () => unawaited(controller.retryInitialize()),
          icon: const Icon(Icons.refresh_rounded, size: 26),
          label: const Text(kContentRetryLabel),
        ),
        OutlinedButton(
          onPressed: onGoHome,
          child: const Text('Go home'),
        ),
      ],
    );
  }
}

class LearningStuckNotice extends StatelessWidget {
  const LearningStuckNotice({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: '$kProgressHiddenTitle. $kProgressHiddenBody',
      child: ExcludeSemantics(
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF6C3),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.warning, width: 2),
          ),
          child: Row(
            children: <Widget>[
              const Icon(
                Icons.star_outline_rounded,
                size: 30,
                color: AppColors.warning,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      kProgressHiddenTitle,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: AppColors.warning,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 4),
                    const Text(kProgressHiddenBody),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ResponsiveTileGrid extends StatelessWidget {
  const ResponsiveTileGrid({
    super.key,
    required this.minItemWidth,
    required this.spacing,
    required this.maxColumns,
    required this.itemCount,
    required this.itemBuilder,
  });

  final double minItemWidth;
  final double spacing;
  final int maxColumns;
  final int itemCount;
  final Widget Function(BuildContext context, int index) itemBuilder;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final available =
            constraints.maxWidth.isFinite ? constraints.maxWidth : minItemWidth;
        var columns =
            ((available + spacing) / (minItemWidth + spacing)).floor();
        if (columns < 1) {
          columns = 1;
        }
        if (columns > maxColumns) {
          columns = maxColumns;
        }
        final itemWidth = (available - (spacing * (columns - 1))) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: <Widget>[
            for (var index = 0; index < itemCount; index++)
              SizedBox(
                width: itemWidth,
                child: itemBuilder(context, index),
              ),
          ],
        );
      },
    );
  }
}
