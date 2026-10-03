import 'dart:async';

import 'package:flutter/material.dart';
import 'package:school_learning_app/app/app_controller.dart';
import 'package:school_learning_app/app/app_scope.dart';
import 'package:school_learning_app/app/route_names.dart';
import 'package:school_learning_app/app/theme.dart';
import 'package:school_learning_app/core/haptics/haptics_service.dart';
import 'package:school_learning_app/data/content/content_models.dart';
import 'package:school_learning_app/features/learning/learning_shell.dart';

const String kGamesSubjectId = 'little';
const int kMinimumClassNumber = 1;
const double kClassTargetSize = 64;

class SubjectScreen extends StatefulWidget {
  const SubjectScreen({
    super.key,
    this.gamesOnly = false,
    this.onGoHome,
    this.onBack,
    this.onOpenActivity,
  });

  final bool gamesOnly;
  final VoidCallback? onGoHome;
  final VoidCallback? onBack;
  final void Function(String activityId)? onOpenActivity;

  @override
  State<SubjectScreen> createState() => _SubjectScreenState();
}

class _SubjectScreenState extends State<SubjectScreen> {
  String? _classId;
  String? _subjectId;

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final catalog = controller.catalog;
    if (catalog == null) {
      return LearningContentState(
        controller: controller,
        title: widget.gamesOnly ? 'Play and learn' : 'Choose a subject',
        onGoHome: () => _goHome(context, controller),
        onBack: () => _goBack(context, controller),
      );
    }

    if (widget.gamesOnly) {
      return _buildGames(context, controller, catalog);
    }
    return _buildSubjects(context, controller, catalog);
  }

  Widget _buildSubjects(
    BuildContext context,
    AppController controller,
    ContentCatalog catalog,
  ) {
    final classId = _resolveClassId(controller, catalog);
    final classIds = numberedClassIds(catalog);
    final subjectId = _subjectId;
    return LearningScaffold(
      title: 'Choose a subject',
      onGoHome: () => _goHome(context, controller),
      onBack: () => _goBack(context, controller),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: <Widget>[
          Text(
            'Pick a subject',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 8),
          const Text('Choose one to see its activities.'),
          const SizedBox(height: 16),
          Semantics(
            container: true,
            label: 'Choose a class',
            child: ExcludeSemantics(
              child: Text(
                'Choose a class',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          ClassFilter(
            classIds: classIds,
            selectedClassId: classId,
            haptics: controller.haptics,
            onSelected: (value) => setState(() => _classId = value),
          ),
          const SizedBox(height: 20),
          if (subjectId == null)
            _buildSubjectGrid(context, controller, catalog, classId)
          else
            _buildActivityList(
              context,
              controller,
              catalog,
              classId: classId,
              subjectId: subjectId,
            ),
        ],
      ),
    );
  }

  Widget _buildSubjectGrid(
    BuildContext context,
    AppController controller,
    ContentCatalog catalog,
    String? classId,
  ) {
    final subjects = catalog.subjects
        .where((subject) => subject.id != kGamesSubjectId)
        .toList();
    if (subjects.isEmpty) {
      return const Text('Subjects are getting ready.');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        ResponsiveTileGrid(
          minItemWidth: 260,
          spacing: 16,
          maxColumns: 3,
          itemCount: subjects.length,
          itemBuilder: (context, index) {
            final subject = subjects[index];
            final total = activityCountFor(
              catalog,
              classId: classId,
              subjectId: subject.id,
            );
            final done = completedCountFor(
              controller,
              catalog,
              classId: classId,
              subjectId: subject.id,
            );
            return ChoiceCard(
              title: subject.title,
              subtitle: subject.subtitle.isEmpty
                  ? 'Choose to see its activities.'
                  : subject.subtitle,
              icon: subjectIcon(subject.id),
              done: total == 0 ? null : '$done of $total finished',
              onTap: () {
                controller.openSubject(subject.id);
                setState(() => _subjectId = subject.id);
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildActivityList(
    BuildContext context,
    AppController controller,
    ContentCatalog catalog, {
    required String? classId,
    required String subjectId,
  }) {
    final subject =
        catalog.subjects.where((item) => item.id == subjectId).firstOrNull;
    final activities = catalog.activities
        .where(
          (activity) =>
              activity.subjectId == subjectId &&
              _matchesClass(activity.classId, classId),
        )
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          subject?.title ?? 'Choose an activity',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          classId == null
              ? 'Choose an activity'
              : 'Choose an activity for ${classLabel(classId)}.',
        ),
        const SizedBox(height: 16),
        if (activities.isEmpty)
          const Text('No activities are available here yet.')
        else
          ResponsiveTileGrid(
            minItemWidth: 260,
            spacing: 16,
            maxColumns: 2,
            itemCount: activities.length,
            itemBuilder: (context, index) {
              final activity = activities[index];
              final done = controller.progress.completedActivityIds
                  .contains(activity.id);
              final best = controller.progress.quizBestScores[activity.id];
              return ChoiceCard(
                title: activity.title,
                subtitle: activity.story,
                icon: activityIcon(activity.activityType),
                done: _activityProgressLabel(
                  done: done,
                  best: best,
                  questions: activity.questions.length,
                ),
                onTap: () => _openActivity(context, controller, activity.id),
              );
            },
          ),
        const SizedBox(height: 16),
        OutlinedButton(
          onPressed: () {
            controller.resetSelection();
            setState(() => _subjectId = null);
          },
          child: const Text('Choose another subject'),
        ),
      ],
    );
  }

  Widget _buildGames(
    BuildContext context,
    AppController controller,
    ContentCatalog catalog,
  ) {
    final activities = catalog.activities
        .where((activity) => activity.subjectId == kGamesSubjectId)
        .toList();
    return LearningScaffold(
      title: 'Play and learn',
      onGoHome: () => _goHome(context, controller),
      onBack: () => _goBack(context, controller),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: <Widget>[
          Text(
            'Play and learn',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 8),
          const Text('Choose a gentle game to try.'),
          const SizedBox(height: 16),
          if (activities.isEmpty)
            const Text('Games are getting ready.')
          else
            ResponsiveTileGrid(
              minItemWidth: 240,
              spacing: 16,
              maxColumns: 3,
              itemCount: activities.length,
              itemBuilder: (context, index) {
                final activity = activities[index];
                final done = controller.progress.completedActivityIds
                    .contains(activity.id);
                return ChoiceCard(
                  title: activity.title,
                  subtitle: activity.story,
                  icon: activityIcon(activity.activityType),
                  done: done ? 'Finished' : 'Ready to play',
                  onTap: () => _openActivity(context, controller, activity.id),
                );
              },
            ),
        ],
      ),
    );
  }

  String _resolveClassId(AppController controller, ContentCatalog catalog) {
    final available = numberedClassIds(catalog);
    final current = _classId;
    if (current != null && available.contains(current)) {
      return current;
    }
    final active = controller.activeClassId;
    if (active != null && available.contains(active)) {
      return active;
    }
    final lastActivity = controller.activityById(
      controller.progress.lastActivityId ?? '',
    );
    final resumeClass = lastActivity?.classId;
    if (resumeClass != null && available.contains(resumeClass)) {
      return resumeClass;
    }
    return available.isEmpty ? '' : available.first;
  }

  void _openActivity(
    BuildContext context,
    AppController controller,
    String activityId,
  ) {
    if (!controller.openActivity(activityId)) {
      return;
    }
    final callback = widget.onOpenActivity;
    if (callback != null) {
      callback(activityId);
      return;
    }
    Navigator.pushNamed(context, RouteNames.activity, arguments: activityId);
  }

  void _goBack(BuildContext context, AppController controller) {
    if (_subjectId != null) {
      controller.resetSelection();
      setState(() => _subjectId = null);
      return;
    }
    final callback = widget.onBack;
    if (callback != null) {
      callback();
      return;
    }
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
      return;
    }
    _goHome(context, controller);
  }

  void _goHome(BuildContext context, AppController controller) {
    final callback = widget.onGoHome;
    if (callback != null) {
      callback();
      return;
    }
    Navigator.of(context)
        .pushNamedAndRemoveUntil(RouteNames.home, (_) => false);
  }
}

class ClassFilter extends StatelessWidget {
  const ClassFilter({
    super.key,
    required this.classIds,
    required this.selectedClassId,
    required this.onSelected,
    this.haptics,
  });

  final List<String> classIds;
  final String? selectedClassId;
  final ValueChanged<String> onSelected;
  final HapticsService? haptics;

  @override
  Widget build(BuildContext context) {
    if (classIds.isEmpty) {
      return const Text('Classes are getting ready.');
    }
    final service = haptics;
    void select(String classId) {
      if (service != null) {
        unawaited(service.selection());
      }
      onSelected(classId);
    }

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: <Widget>[
        for (final classId in classIds)
          Semantics(
            button: true,
            selected: classId == selectedClassId,
            label: classLabel(classId),
            hint: 'Show activities for ${classLabel(classId)}',
            onTap: () => select(classId),
            child: ExcludeSemantics(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minWidth: kClassTargetSize,
                  minHeight: kClassTargetSize,
                ),
                child: ChoiceChip(
                  label: Text(classLabel(classId)),
                  selected: classId == selectedClassId,
                  onSelected: (_) => select(classId),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class ChoiceCard extends StatelessWidget {
  const ChoiceCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.done,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final String? done;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = done;
    return Semantics(
      button: true,
      label: '$title. $subtitle${progress == null ? '' : '. $progress'}',
      onTap: onTap,
      child: ExcludeSemantics(
        child: Card(
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 88),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    if (useStackedCardLayout(context, constraints)) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          CardBadge(
                            icon: icon,
                            color: const Color(0xFFD8F3EF),
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
                          if (progress != null) ...<Widget>[
                            const SizedBox(height: 6),
                            Text(
                              progress,
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ],
                      );
                    }
                    return Row(
                      children: <Widget>[
                        CardBadge(
                          icon: icon,
                          color: const Color(0xFFD8F3EF),
                        ),
                        const SizedBox(width: 14),
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
                              if (progress != null) ...<Widget>[
                                const SizedBox(height: 6),
                                Text(
                                  progress,
                                  style: theme.textTheme.labelLarge?.copyWith(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right, size: 28),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

List<String> numberedClassIds(ContentCatalog catalog) {
  final result = <String>[];
  for (final classId in catalog.classIds) {
    final level = classLevel(classId);
    if (level != null && level >= kMinimumClassNumber) {
      result.add(classId);
    }
  }
  result.sort((first, second) {
    final firstLevel = classLevel(first) ?? 0;
    final secondLevel = classLevel(second) ?? 0;
    return firstLevel.compareTo(secondLevel);
  });
  return List<String>.unmodifiable(result);
}

int? classLevel(String classId) {
  final match = RegExp(r'^class-(\d+)$').firstMatch(classId.trim());
  if (match == null) {
    return null;
  }
  return int.tryParse(match.group(1)!);
}

String classLabel(String classId) {
  final level = classLevel(classId);
  if (level == null) {
    return classId;
  }
  return 'Class $level';
}

int activityCountFor(
  ContentCatalog catalog, {
  required String? classId,
  required String subjectId,
}) {
  var total = 0;
  for (final activity in catalog.activities) {
    if (activity.subjectId == subjectId &&
        _matchesClass(activity.classId, classId)) {
      total++;
    }
  }
  return total;
}

int completedCountFor(
  AppController controller,
  ContentCatalog catalog, {
  required String? classId,
  required String subjectId,
}) {
  var total = 0;
  for (final activity in catalog.activities) {
    if (activity.subjectId == subjectId &&
        _matchesClass(activity.classId, classId) &&
        controller.progress.completedActivityIds.contains(activity.id)) {
      total++;
    }
  }
  return total;
}

String _activityProgressLabel({
  required bool done,
  required int? best,
  required int questions,
}) {
  final quiz =
      best == null || questions == 0 ? null : 'Best quiz $best of $questions';
  final parts = <String>[
    if (done) 'Finished',
    if (quiz != null) quiz,
  ];
  if (parts.isEmpty) {
    return 'Ready to start';
  }
  return parts.join('. ');
}

bool _matchesClass(String activityClassId, String? classId) {
  if (classId == null || classId.isEmpty) {
    return true;
  }
  return activityClassId == classId;
}

IconData subjectIcon(String subjectId) {
  switch (subjectId) {
    case 'english':
      return Icons.menu_book_outlined;
    case 'english_grammar':
      return Icons.rule_outlined;
    case 'marathi':
      return Icons.translate_outlined;
    case 'hindi':
      return Icons.record_voice_over_outlined;
    case 'mathematics':
      return Icons.calculate_outlined;
    case 'evs':
      return Icons.eco_outlined;
    case 'computer':
      return Icons.devices_outlined;
    case 'gk':
      return Icons.public_outlined;
    case 'communication':
      return Icons.forum_outlined;
    default:
      return Icons.auto_stories_outlined;
  }
}

IconData activityIcon(ActivityType type) {
  switch (type) {
    case ActivityType.story:
      return Icons.auto_stories_outlined;
    case ActivityType.letter:
      return Icons.text_fields;
    case ActivityType.number:
      return Icons.pin_outlined;
    case ActivityType.word:
      return Icons.spellcheck_outlined;
    case ActivityType.game:
      return Icons.sports_esports_outlined;
  }
}
