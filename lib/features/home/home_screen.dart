import 'dart:async';

import 'package:flutter/material.dart';
import 'package:school_learning_app/app/app_controller.dart';
import 'package:school_learning_app/app/route_names.dart';
import 'package:school_learning_app/app/theme.dart';
import 'package:school_learning_app/data/progress/progress_models.dart';
import 'package:school_learning_app/features/learning/learning_shell.dart';

const int kProgressSummaryStarCount = 10;

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.controller,
    this.onParentLock,
  });

  final AppController controller;
  final VoidCallback? onParentLock;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final lockAction = onParentLock ?? () => _showParentNotice(context);
        return Scaffold(
          appBar: AppBar(
            toolbarHeight: AppTheme.toolbarHeight(context),
            leadingWidth: AppTheme.leadingWidth(context),
            title: const Text('School Learning'),
            actions: [
              SizedBox(
                width: 64,
                height: 64,
                child: Semantics(
                  button: true,
                  label: 'Grown-ups only',
                  onTap: lockAction,
                  child: ExcludeSemantics(
                    child: IconButton(
                      tooltip: 'Grown-ups only',
                      onPressed: lockAction,
                      icon: const Icon(Icons.lock_outline),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: SafeArea(
            child: controller.hasContentFailure
                ? LearningContentState(
                    controller: controller,
                    title: 'School Learning',
                    onGoHome: () {},
                    onBack: () {},
                  )
                : ContentWidthLimiter(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                      children: <Widget>[
                        if (controller.hasUnreadableProgress) ...<Widget>[
                          const LearningStuckNotice(),
                          const SizedBox(height: 12),
                        ],
                        Text(
                          'What would you like to do?',
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 16),
                        if (controller.catalog != null) ...<Widget>[
                          ProgressSummary(
                            key: const Key('home-progress-summary'),
                            progress: controller.progress,
                            totalActivities:
                                controller.catalog?.activities.length ?? 0,
                          ),
                          const SizedBox(height: 12),
                        ],
                        _LearningChoice(
                          title: 'Continue learning',
                          subtitle: _continueSubtitle(),
                          icon: Icons.play_circle_outline,
                          color: const Color(0xFFD8F3EF),
                          onTap: () => _continue(context),
                        ),
                        const SizedBox(height: 12),
                        _LearningChoice(
                          title: 'Choose a subject',
                          subtitle: 'Pick something you want to explore.',
                          icon: Icons.menu_book_outlined,
                          color: const Color(0xFFFFE7C2),
                          onTap: () => _openSubjects(context),
                        ),
                        const SizedBox(height: 12),
                        _LearningChoice(
                          title: 'Play and learn',
                          subtitle:
                              'Letters, numbers, words, and gentle games.',
                          icon: Icons.sports_esports_outlined,
                          color: const Color(0xFFE5E0FF),
                          onTap: () => _openGames(context),
                        ),
                        const SizedBox(height: 12),
                        _LearningChoice(
                          title: 'Ask your teacher',
                          subtitle: 'Get a helpful hint when you need one.',
                          icon: Icons.record_voice_over_outlined,
                          color: const Color(0xFFFFDAD6),
                          onTap: () => _showTeacherNotice(context),
                        ),
                      ],
                    ),
                  ),
          ),
        );
      },
    );
  }

  String _continueSubtitle() {
    final activityId = controller.progress.lastActivityId;
    if (activityId == null || activityId.trim().isEmpty) {
      return 'Start your first activity.';
    }
    return 'Pick up where you left off.';
  }

  void _continue(BuildContext context) {
    final activityId = controller.progress.lastActivityId;
    if (activityId != null && controller.openActivity(activityId)) {
      Navigator.pushNamed(context, RouteNames.activity, arguments: activityId);
      return;
    }
    _openSubjects(context);
  }

  void _openSubjects(BuildContext context) {
    controller.resetSelection();
    Navigator.pushNamed(context, RouteNames.subjects);
  }

  void _openGames(BuildContext context) {
    Navigator.pushNamed(context, RouteNames.subjects, arguments: true);
  }

  void _showTeacherNotice(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Your teacher is coming next.')),
    );
  }

  void _showParentNotice(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Grown-ups only'),
        content: Text(
          controller.hasUnreadableProgress
              ? 'Please ask a grown-up for help. A grown-up can also reset the '
                  'saved stars so learning can save again.'
              : 'Please ask a grown-up for help.',
        ),
        actions: [
          if (controller.hasUnreadableProgress)
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                unawaited(_resetSavedStars());
              },
              child: const Text('Reset saved stars'),
            ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _resetSavedStars() async {
    try {
      await controller.resetUnreadableProgress();
    } on Object {
      return;
    }
  }
}

class ProgressSummary extends StatelessWidget {
  const ProgressSummary({
    super.key,
    required this.progress,
    required this.totalActivities,
  });

  final ProgressSnapshot progress;
  final int totalActivities;

  @override
  Widget build(BuildContext context) {
    final finished = progress.completedActivityIds.length;
    final total = totalActivities <= 0 ? finished : totalActivities;
    final earned = finished.clamp(0, kProgressSummaryStarCount);
    return Semantics(
      container: true,
      label: 'Your stars. $finished of $total activities finished. '
          '$earned ${earned == 1 ? 'star' : 'stars'} earned.',
      child: ExcludeSemantics(
        child: Card(
          color: const Color(0xFFFFF6C3),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 88),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final heading = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Text(
                        'Your stars',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text('$finished of $total finished'),
                    ],
                  );
                  final starRow = Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    alignment: WrapAlignment.center,
                    children: <Widget>[
                      for (var index = 0;
                          index < kProgressSummaryStarCount;
                          index++)
                        Icon(
                          index < earned
                              ? Icons.star_rounded
                              : Icons.star_border_rounded,
                          color: index < earned
                              ? AppColors.warning
                              : AppColors.ink,
                          size: 26,
                        ),
                    ],
                  );
                  if (useStackedCardLayout(context, constraints)) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        heading,
                        const SizedBox(height: 12),
                        starRow,
                      ],
                    );
                  }
                  return Row(
                    children: <Widget>[
                      Expanded(child: heading),
                      const SizedBox(width: 16),
                      starRow,
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LearningChoice extends StatelessWidget {
  const _LearningChoice({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      label: '$title. $subtitle',
      onTap: onTap,
      child: ExcludeSemantics(
        child: Card(
          color: color,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 88),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      if (useStackedCardLayout(context, constraints)) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            CardBadge(
                              icon: icon,
                              color: Colors.white.withValues(alpha: 0.75),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              title,
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(subtitle),
                          ],
                        );
                      }
                      return Row(
                        children: <Widget>[
                          CardBadge(
                            icon: icon,
                            color: Colors.white.withValues(alpha: 0.75),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: <Widget>[
                                Text(
                                  title,
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(subtitle),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right, size: 30),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
