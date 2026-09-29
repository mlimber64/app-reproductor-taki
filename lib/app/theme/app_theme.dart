import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/taki_typography.dart';

/// Tema oscuro Material 3 de Taki.
///
/// Sora para títulos (display/headline/title) y DM Sans para el resto. Ambas
/// van empaquetadas en la app (ver `fonts:` en pubspec.yaml). Las familias
/// salen de [TakiTypography]; tamaños y colores aún son los del tema
/// anterior (la migración a los tokens Taki* es una fase posterior).
abstract final class AppTheme {
  static const String _titleFontFamily = TakiTypography.titleFontFamily;
  static const String _bodyFontFamily = TakiTypography.bodyFontFamily;

  /// Área táctil mínima recomendada (Material / accesibilidad).
  static const double minTouchTarget = 48;

  static ThemeData dark({Color accent = AppColors.accent}) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: Brightness.dark,
    ).copyWith(
      primary: accent,
      onPrimary: AppColors.onAccent,
      secondary: accent,
      onSecondary: AppColors.onAccent,
      surface: AppColors.surface,
      onSurface: AppColors.textPrimary,
      onSurfaceVariant: AppColors.textSecondary,
      surfaceContainerLowest: AppColors.background,
      surfaceContainerLow: AppColors.surface,
      surfaceContainer: AppColors.surface,
      surfaceContainerHigh: AppColors.surfaceElevated,
      surfaceContainerHighest: AppColors.surfaceElevated,
      outline: AppColors.border,
      outlineVariant: AppColors.border,
    );

    final textTheme = _textTheme();

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.background,
      canvasColor: AppColors.background,
      dividerColor: AppColors.border,
      textTheme: textTheme,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      visualDensity: VisualDensity.standard,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: accent.withValues(alpha: 0.18),
        height: 72,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => textTheme.labelMedium?.copyWith(
            color: states.contains(WidgetState.selected)
                ? AppColors.textPrimary
                : AppColors.textSecondary,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? accent
                : AppColors.textSecondary,
          ),
        ),
      ),
      cardTheme: const CardThemeData(
        color: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
          side: BorderSide(color: AppColors.border),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
      ),
      listTileTheme: const ListTileThemeData(
        minTileHeight: minTouchTarget,
        iconColor: AppColors.textSecondary,
        textColor: AppColors.textPrimary,
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size.square(minTouchTarget),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, minTouchTarget),
          backgroundColor: accent,
          foregroundColor: AppColors.onAccent,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(64, minTouchTarget),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, minTouchTarget),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(64, minTouchTarget),
          foregroundColor: accent,
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surfaceElevated,
        surfaceTintColor: Colors.transparent,
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: AppColors.surfaceElevated,
        surfaceTintColor: Colors.transparent,
      ),
    );
  }

  static TextTheme _textTheme() {
    final base = ThemeData(brightness: Brightness.dark).textTheme.apply(
          fontFamily: _bodyFontFamily,
          bodyColor: AppColors.textPrimary,
          displayColor: AppColors.textPrimary,
        );

    TextStyle? sora(TextStyle? style) =>
        style?.copyWith(fontFamily: _titleFontFamily);

    return base.copyWith(
      displayLarge: sora(base.displayLarge),
      displayMedium: sora(base.displayMedium),
      displaySmall: sora(base.displaySmall),
      headlineLarge: sora(base.headlineLarge),
      headlineMedium: sora(base.headlineMedium),
      headlineSmall: sora(base.headlineSmall),
      titleLarge: sora(base.titleLarge),
      titleMedium: sora(base.titleMedium),
      titleSmall: sora(base.titleSmall),
    );
  }
}
