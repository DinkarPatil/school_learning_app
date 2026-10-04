import 'dart:math' as math;

import 'package:flutter/material.dart';

abstract final class AppColors {
  static const Color ink = Color(0xFF17212B);
  static const Color surface = Color(0xFFFFFBF5);
  static const Color primary = Color(0xFF005B5A);
  static const Color success = Color(0xFF236B2C);
  static const Color warning = Color(0xFF7A4E00);
  static const Color error = Color(0xFFB3261E);
  static const Color onPrimary = Colors.white;
  static const Color onSurface = Color(0xFF17212B);
}

abstract final class AppTheme {
  static const double baseToolbarHeight = 72;
  static const double baseLeadingWidth = 72;

  static double toolbarHeight(BuildContext context) {
    return math.max(
      baseToolbarHeight,
      baseToolbarHeight * _textScale(context),
    );
  }

  static double leadingWidth(BuildContext context) {
    return math.max(baseLeadingWidth, toolbarHeight(context));
  }

  static double _textScale(BuildContext context) =>
      MediaQuery.textScalerOf(context).scale(16) / 16;

  static ThemeData light() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.light,
    ).copyWith(
      primary: AppColors.primary,
      onPrimary: AppColors.onPrimary,
      surface: AppColors.surface,
      onSurface: AppColors.onSurface,
      error: AppColors.error,
    );
    final baseTextTheme = Typography.material2021().black.apply(
          bodyColor: AppColors.ink,
          displayColor: AppColors.ink,
        );
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.surface,
      textTheme: baseTextTheme,
      visualDensity: VisualDensity.standard,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.ink,
        centerTitle: false,
        elevation: 0,
        toolbarHeight: baseToolbarHeight,
        leadingWidth: baseLeadingWidth,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll<Size>(Size(64, 64)),
          padding: const WidgetStatePropertyAll<EdgeInsetsGeometry>(
            EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          ),
          shape: WidgetStatePropertyAll<OutlinedBorder>(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
          overlayColor: WidgetStateProperty.resolveWith<Color?>((states) {
            if (states.contains(WidgetState.focused)) {
              return AppColors.primary.withValues(alpha: 0.2);
            }
            return null;
          }),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll<Size>(Size(64, 64)),
          padding: const WidgetStatePropertyAll<EdgeInsetsGeometry>(
            EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          ),
          shape: WidgetStatePropertyAll<OutlinedBorder>(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
          side: const WidgetStatePropertyAll<BorderSide>(
            BorderSide(color: AppColors.primary, width: 2),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll<Size>(Size(64, 64)),
          shape: WidgetStatePropertyAll<OutlinedBorder>(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 1,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: Color(0xFFD7E0DE)),
        ),
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: AppColors.ink,
        contentTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  static ThemeData get lightTheme => light();
}
