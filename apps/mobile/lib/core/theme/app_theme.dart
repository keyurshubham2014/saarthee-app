import 'package:flutter/material.dart';

import 'tokens.dart';

/// Material 3 theme built only from [AppColors] tokens (02 §2.1).
class AppTheme {
  const AppTheme._();

  static const TextTheme _text = TextTheme(
    // Display 28/34 Semibold
    headlineMedium: TextStyle(
      fontSize: 28,
      height: 34 / 28,
      fontWeight: FontWeight.w600,
      color: AppColors.ink,
    ),
    // Title 22/28 Semibold
    titleLarge: TextStyle(
      fontSize: 22,
      height: 28 / 22,
      fontWeight: FontWeight.w600,
      color: AppColors.ink,
    ),
    titleMedium: TextStyle(
      fontSize: 18,
      height: 26 / 18,
      fontWeight: FontWeight.w600,
      color: AppColors.ink,
    ),
    // Body large 18/26
    bodyLarge: TextStyle(
      fontSize: 18,
      height: 26 / 18,
      fontWeight: FontWeight.w400,
      color: AppColors.ink,
    ),
    // Body 16/24
    bodyMedium: TextStyle(
      fontSize: 16,
      height: 24 / 16,
      fontWeight: FontWeight.w400,
      color: AppColors.ink,
    ),
    // Label 16/20 Medium
    labelLarge: TextStyle(
      fontSize: 16,
      height: 20 / 16,
      fontWeight: FontWeight.w500,
      color: AppColors.ink,
    ),
    // Caption 14/20
    bodySmall: TextStyle(
      fontSize: 14,
      height: 20 / 14,
      fontWeight: FontWeight.w400,
      color: AppColors.inkMuted,
    ),
    labelMedium: TextStyle(
      fontSize: 14,
      height: 20 / 14,
      fontWeight: FontWeight.w500,
      color: AppColors.ink,
    ),
  );

  static ThemeData light() {
    const scheme = ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.indigo,
      onPrimary: AppColors.white,
      primaryContainer: AppColors.indigoTint,
      onPrimaryContainer: AppColors.ink,
      secondary: AppColors.marigold,
      onSecondary: AppColors.ink,
      secondaryContainer: AppColors.waitingTint,
      onSecondaryContainer: AppColors.ink,
      tertiary: AppColors.fixed,
      onTertiary: AppColors.white,
      error: AppColors.notFixed,
      onError: AppColors.white,
      errorContainer: AppColors.notFixedTint,
      onErrorContainer: AppColors.ink,
      surface: AppColors.surface,
      onSurface: AppColors.ink,
      onSurfaceVariant: AppColors.inkMuted,
      surfaceContainerLowest: AppColors.white,
      surfaceContainerLow: AppColors.white,
      surfaceContainer: AppColors.white,
      surfaceContainerHigh: AppColors.white,
      surfaceContainerHighest: AppColors.indigoTint,
      outline: AppColors.fieldBorder,
      outlineVariant: AppColors.divider,
      inverseSurface: AppColors.ink,
      onInverseSurface: AppColors.white,
      shadow: AppColors.ink,
      scrim: AppColors.scrim,
      surfaceTint: AppColors.transparent,
    );

    final inputBorder = OutlineInputBorder(
      borderRadius: AppRadii.controlRadius,
      borderSide: const BorderSide(color: AppColors.fieldBorder),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.surface,
      textTheme: _text,
      dividerTheme: const DividerThemeData(
        color: AppColors.divider,
        thickness: 1,
        space: 1,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 18,
          height: 26 / 18,
          fontWeight: FontWeight.w600,
          color: AppColors.ink,
        ),
      ),
      cardTheme: const CardThemeData(
        color: AppColors.white,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: AppRadii.cardRadius),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.white,
        border: inputBorder,
        enabledBorder: inputBorder,
        focusedBorder: inputBorder.copyWith(
          borderSide: const BorderSide(color: AppColors.indigo, width: 2),
        ),
        errorBorder: inputBorder.copyWith(
          borderSide: const BorderSide(color: AppColors.notFixed, width: 2),
        ),
        focusedErrorBorder: inputBorder.copyWith(
          borderSide: const BorderSide(color: AppColors.notFixed, width: 2),
        ),
        labelStyle: _text.bodyLarge?.copyWith(color: AppColors.inkMuted),
        hintStyle: _text.bodyLarge?.copyWith(color: AppColors.inkMuted),
        helperStyle: _text.bodySmall,
        errorStyle: _text.bodySmall?.copyWith(color: AppColors.notFixed),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.lg,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.indigo,
          foregroundColor: AppColors.white,
          disabledBackgroundColor: AppColors.indigoTint,
          disabledForegroundColor: AppColors.inkMuted,
          minimumSize: const Size.fromHeight(AppSpacing.primaryButtonHeight),
          shape: const RoundedRectangleBorder(
            borderRadius: AppRadii.controlRadius,
          ),
          textStyle: _text.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.indigo,
          backgroundColor: AppColors.white,
          minimumSize: const Size.fromHeight(AppSpacing.touchTarget + 4),
          side: const BorderSide(color: AppColors.fieldBorder),
          shape: const RoundedRectangleBorder(
            borderRadius: AppRadii.controlRadius,
          ),
          textStyle: _text.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.indigo,
          minimumSize: const Size(
            AppSpacing.touchTarget,
            AppSpacing.touchTarget,
          ),
          textStyle: _text.labelLarge,
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        side: const BorderSide(color: AppColors.fieldBorder, width: 2),
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.indigo
              : AppColors.white,
        ),
        checkColor: const WidgetStatePropertyAll(AppColors.white),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.indigo,
        linearTrackColor: AppColors.indigoTint,
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: AppColors.ink,
        contentTextStyle: TextStyle(color: AppColors.white, fontSize: 16),
        behavior: SnackBarBehavior.floating,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: FadeForwardsPageTransitionsBuilder(),
        },
      ),
    );
  }
}
