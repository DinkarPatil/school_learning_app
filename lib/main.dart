import 'package:flutter/material.dart';
import 'package:school_learning_app/app/app.dart';

export 'package:school_learning_app/app/app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(SchoolLearningApp(dependencies: AppDependencies.production()));
}
