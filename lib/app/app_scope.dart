import 'package:flutter/widgets.dart';
import 'package:school_learning_app/app/app_controller.dart';

class AppScope extends StatefulWidget {
  const AppScope({
    super.key,
    required this.controller,
    required this.child,
  });

  final AppController controller;
  final Widget child;

  static AppController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<_AppScopeData>();
    if (scope == null) {
      throw FlutterError.fromParts(<DiagnosticsNode>[
        ErrorSummary('No AppScope found above this widget.'),
        ErrorDescription(
          'AppScope.of() was called with a context that does not have an '
          'AppScope ancestor.',
        ),
        context.describeElement('The context used was'),
      ]);
    }
    return scope.controller;
  }

  static AppController read(BuildContext context) {
    final element =
        context.getElementForInheritedWidgetOfExactType<_AppScopeData>();
    if (element == null) {
      throw FlutterError.fromParts(<DiagnosticsNode>[
        ErrorSummary('No AppScope found above this widget.'),
        ErrorDescription(
          'AppScope.read() was called with a context that does not have an '
          'AppScope ancestor.',
        ),
        context.describeElement('The context used was'),
      ]);
    }
    return (element.widget as _AppScopeData).controller;
  }

  @override
  State<AppScope> createState() => _AppScopeState();
}

class _AppScopeState extends State<AppScope> {
  AppController? _listening;
  int _revision = 0;

  @override
  void initState() {
    super.initState();
    _attach(widget.controller);
  }

  @override
  void didUpdateWidget(covariant AppScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      _attach(widget.controller);
    }
  }

  void _attach(AppController controller) {
    if (identical(_listening, controller)) {
      return;
    }
    _listening?.removeListener(_handleControllerChange);
    _listening = controller..addListener(_handleControllerChange);
    _revision++;
  }

  void _handleControllerChange() {
    if (!mounted) {
      return;
    }
    setState(() => _revision++);
  }

  @override
  void dispose() {
    _listening?.removeListener(_handleControllerChange);
    _listening = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _AppScopeData(
      controller: widget.controller,
      revision: _revision,
      child: widget.child,
    );
  }
}

class _AppScopeData extends InheritedWidget {
  const _AppScopeData({
    required this.controller,
    required this.revision,
    required super.child,
  });

  final AppController controller;
  final int revision;

  @override
  bool updateShouldNotify(_AppScopeData oldWidget) =>
      !identical(oldWidget.controller, controller) ||
      oldWidget.revision != revision;
}
