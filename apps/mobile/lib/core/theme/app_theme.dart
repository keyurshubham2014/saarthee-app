import 'package:flutter/material.dart';

import 'motion.dart';
import 'tokens.dart';
import 'typography.dart';

/// Material 3 `ThemeData` built only from the Neem tokens (DS §2–§5).
class AppTheme {
  const AppTheme._();

  static ThemeData light() => build(SaartheeColors.light);
  static ThemeData dark() => build(SaartheeColors.dark);

  static ThemeData build(SaartheeColors c) {
    final text = AppTypography.textTheme(c);
    final scheme = ColorScheme(
      brightness: c.brightness,
      primary: c.primary,
      onPrimary: c.onPrimary,
      primaryContainer: c.primaryContainer,
      onPrimaryContainer: c.onPrimaryContainer,
      secondary: c.primary,
      onSecondary: c.onPrimary,
      tertiary: c.info,
      onTertiary: c.onPrimary,
      error: c.error,
      onError: c.surface,
      errorContainer: c.errorTint,
      onErrorContainer: c.error,
      surface: c.surface,
      onSurface: c.textPrimary,
      onSurfaceVariant: c.textSecondary,
      surfaceContainerLowest: c.surface,
      surfaceContainerLow: c.surface,
      surfaceContainer: c.surface,
      surfaceContainerHigh: c.surfaceAlt,
      surfaceContainerHighest: c.surfaceAlt,
      outline: c.borderStrong,
      outlineVariant: c.border,
      shadow: c.shadow,
      scrim: NeemFixed.scrim,
      inverseSurface: c.primaryDark,
      onInverseSurface: c.onToast,
      inversePrimary: c.primaryContainer,
      surfaceTint: NeemFixed.transparent,
    );
    const controlShape = RoundedRectangleBorder(
      borderRadius: AppRadii.controlRadius,
    );
    final buttonText = text.labelLarge!;
    OutlineInputBorder inputBorder(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: AppRadii.controlRadius,
          borderSide: BorderSide(color: color, width: width),
        );

    return ThemeData(
      useMaterial3: true,
      brightness: c.brightness,
      colorScheme: scheme,
      extensions: [c],
      textTheme: text,
      fontFamily: AppTypography.body,
      fontFamilyFallback: AppTypography.fallback,
      scaffoldBackgroundColor: c.background,
      canvasColor: c.background,
      dividerColor: c.border,
      focusColor: c.focusRing.withValues(alpha: 0.6),
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      splashFactory: InkSparkle.constantTurbulenceSeedSplashFactory,
      dividerTheme: DividerThemeData(color: c.border, thickness: 1, space: 1),
      iconTheme: IconThemeData(color: c.textPrimary, size: AppSpacing.iconSize),
      appBarTheme: AppBarTheme(
        backgroundColor: c.surface,
        foregroundColor: c.textPrimary,
        surfaceTintColor: NeemFixed.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleSpacing: AppSpacing.gutter,
        titleTextStyle: text.headlineSmall,
        iconTheme: IconThemeData(color: c.textPrimary),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: c.primary,
          foregroundColor: c.onPrimary,
          disabledBackgroundColor: c.surfaceAlt,
          disabledForegroundColor: c.textDisabled,
          minimumSize: const Size(
            AppSpacing.touchTarget,
            AppSpacing.buttonHeight,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s20,
            vertical: AppSpacing.s12,
          ),
          shape: controlShape,
          textStyle: buttonText,
          animationDuration: SaartheeMotion.instant.duration,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: c.primary,
          disabledForegroundColor: c.textDisabled,
          minimumSize: const Size(
            AppSpacing.touchTarget,
            AppSpacing.buttonHeight,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s20,
            vertical: AppSpacing.s12,
          ),
          side: BorderSide(
            color: c.borderStrong,
            width: AppSpacing.outlineWidth,
          ),
          shape: controlShape,
          textStyle: buttonText,
          animationDuration: SaartheeMotion.instant.duration,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: c.primary,
          minimumSize: const Size(
            AppSpacing.touchTarget,
            AppSpacing.touchTarget,
          ),
          shape: controlShape,
          textStyle: buttonText,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: c.textPrimary,
          minimumSize: const Size(
            AppSpacing.touchTarget,
            AppSpacing.touchTarget,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: c.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s16,
          vertical: AppSpacing.s14,
        ),
        border: inputBorder(c.borderStrong),
        enabledBorder: inputBorder(c.borderStrong),
        focusedBorder: inputBorder(c.primary, AppSpacing.focusWidth),
        errorBorder: inputBorder(c.error),
        focusedErrorBorder: inputBorder(c.error, AppSpacing.focusWidth),
        disabledBorder: inputBorder(c.border),
        hintStyle: text.bodyLarge!.copyWith(color: c.textSecondary),
        helperStyle: text.bodySmall,
        errorStyle: text.bodySmall!.copyWith(color: c.error),
        helperMaxLines: 3,
        errorMaxLines: 3,
      ),
      chipTheme: ChipThemeData(
        shape: AppRadii.pill,
        side: BorderSide(color: c.borderStrong),
        backgroundColor: c.surface,
        selectedColor: c.primaryContainer,
        labelStyle: text.labelMedium,
        checkmarkColor: c.onPrimaryContainer,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s8),
      ),
      cardTheme: CardThemeData(
        color: c.surface,
        surfaceTintColor: NeemFixed.transparent,
        elevation: 1,
        shadowColor: c.shadow.withValues(alpha: 0.05),
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadii.cardRadius,
          side: BorderSide(color: c.border),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: NeemFixed.transparent,
        elevation: AppElevation.overlay,
        showDragHandle: true,
        dragHandleColor: c.borderStrong,
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.sheetTop),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: NeemFixed.transparent,
        elevation: AppElevation.overlay,
        titleTextStyle: text.titleLarge,
        contentTextStyle: text.bodyLarge,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppRadii.sheet)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: c.primaryDark,
        contentTextStyle: text.bodyMedium!.copyWith(color: c.onToast),
        actionTextColor: c.onToast,
        behavior: SnackBarBehavior.floating,
        elevation: AppElevation.overlay,
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.cardRadius),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: NeemFixed.transparent,
        elevation: 0,
        height: 72,
        indicatorColor: NeemFixed.transparent,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => text.labelMedium!.copyWith(
            color: states.contains(WidgetState.selected)
                ? c.onPrimaryContainer
                : c.textSecondary,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: AppSpacing.iconSize,
            color: states.contains(WidgetState.selected)
                ? c.onPrimaryContainer
                : c.textSecondary,
          ),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: c.surface,
        indicatorColor: c.primaryContainer,
        selectedIconTheme: IconThemeData(color: c.onPrimaryContainer),
        unselectedIconTheme: IconThemeData(color: c.textSecondary),
        selectedLabelTextStyle: text.labelMedium!.copyWith(
          color: c.onPrimaryContainer,
        ),
        unselectedLabelTextStyle: text.labelMedium!.copyWith(
          color: c.textSecondary,
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: c.textSecondary,
        textColor: c.textPrimary,
        minVerticalPadding: AppSpacing.s8,
        titleTextStyle: text.titleMedium,
        subtitleTextStyle: text.bodySmall,
        shape: const RoundedRectangleBorder(
          borderRadius: AppRadii.controlRadius,
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? c.onPrimary : null,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? c.primary : null,
        ),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? c.primary : c.borderStrong,
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: c.primary,
        linearTrackColor: c.surfaceAlt,
        circularTrackColor: NeemFixed.transparent,
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: c.primary,
        selectionColor: c.primaryContainer,
        selectionHandleColor: c.primary,
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
