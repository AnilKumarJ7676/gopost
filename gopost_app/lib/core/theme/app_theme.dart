import 'package:flutter/material.dart';
import 'package:gopost_app/core/theme/app_colors.dart';
import 'package:gopost_app/core/theme/app_typography.dart';

class AppTheme {
  AppTheme._();

  static ThemeData light() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: const ColorScheme.light(
        primary: AppColors.brandPrimary,
        primaryContainer: AppColors.brandPrimaryContainerLight,
        secondary: AppColors.brandSecondary,
        secondaryContainer: AppColors.brandSecondaryContainerLight,
        tertiary: AppColors.brandTertiary,
        tertiaryContainer: AppColors.brandTertiaryContainerLight,
        surface: AppColors.neutralSurfaceLight,
        error: AppColors.semanticError,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: AppColors.textPrimaryLight,
        onError: Colors.white,
        outline: AppColors.neutralOutlineLight,
      ),
      scaffoldBackgroundColor: AppColors.neutralBackgroundLight,
      textTheme: AppTypography.textTheme,
      fontFamily: 'Inter',
    );
  }

  static ThemeData dark() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.brandPrimaryDark,
        primaryContainer: AppColors.brandPrimaryContainerDark,
        secondary: AppColors.brandSecondaryDark,
        secondaryContainer: AppColors.brandSecondaryContainerDark,
        tertiary: AppColors.brandTertiaryDark,
        tertiaryContainer: AppColors.brandTertiaryContainerDark,
        surface: AppColors.neutralSurfaceDark,
        error: AppColors.semanticErrorDark,
        onPrimary: Colors.black,
        onSecondary: Colors.black,
        onSurface: AppColors.textPrimaryDark,
        onError: Colors.black,
        outline: AppColors.neutralOutlineDark,
      ),
      scaffoldBackgroundColor: AppColors.neutralBackgroundDark,
      textTheme: AppTypography.textTheme,
      fontFamily: 'Inter',
    );
  }
}
