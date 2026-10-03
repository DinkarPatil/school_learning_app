import 'package:flutter/material.dart';
import 'package:school_learning_app/app/app_controller.dart';
import 'package:school_learning_app/app/app_scope.dart';
import 'package:school_learning_app/app/route_names.dart';
import 'package:school_learning_app/features/games/game_screen.dart';
import 'package:school_learning_app/features/home/home_screen.dart';
import 'package:school_learning_app/features/learning/activity_screen.dart';
import 'package:school_learning_app/features/learning/subject_screen.dart';

class AppRouter {
  const AppRouter();

  static Route<dynamic> onGenerateRoute(
    RouteSettings settings,
    AppController controller,
  ) {
    switch (settings.name) {
      case RouteNames.home:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (context) => AppScope(
            controller: controller,
            child: HomeScreen(controller: controller),
          ),
        );
      case RouteNames.subjects:
        final gamesOnly = _isGamesRoute(settings.arguments);
        if (!gamesOnly) {
          controller.resetSelection();
        }
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (context) => AppScope(
            controller: controller,
            child: SubjectScreen(
              gamesOnly: gamesOnly,
              onGoHome: () => _goHome(context),
              onBack: () => _popOrHome(context),
            ),
          ),
        );
      case RouteNames.activity:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (context) => AppScope(
            controller: controller,
            child: ActivityRouteEntry(
              activityId: settings.arguments is String
                  ? settings.arguments as String
                  : null,
              onGoHome: () => _goHome(context),
              onBack: () => _popOrHome(context),
            ),
          ),
        );
      default:
        return MaterialPageRoute<void>(
          settings: const RouteSettings(name: RouteNames.home),
          builder: (context) => AppScope(
            controller: controller,
            child: HomeScreen(controller: controller),
          ),
        );
    }
  }

  static void _goHome(BuildContext context) {
    Navigator.of(context)
        .pushNamedAndRemoveUntil(RouteNames.home, (_) => false);
  }

  static void _popOrHome(BuildContext context) {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
      return;
    }
    _goHome(context);
  }

  static bool _isGamesRoute(Object? arguments) =>
      arguments is bool && arguments;
}

class ActivityRouteEntry extends StatelessWidget {
  const ActivityRouteEntry({
    super.key,
    this.activityId,
    this.onGoHome,
    this.onBack,
  });

  final String? activityId;
  final VoidCallback? onGoHome;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final id = activityId ?? controller.activeActivityId;
    final activity = id == null ? null : controller.activityById(id);
    if (isGameActivity(activity)) {
      return GameScreen(
        activityId: activity!.id,
        onGoHome: onGoHome,
        onBack: onBack,
      );
    }
    return ActivityScreen(
      activityId: id,
      onGoHome: onGoHome,
      onBack: onBack,
    );
  }
}
