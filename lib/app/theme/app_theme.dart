import 'package:flutter/material.dart';

import '../../core/theme/taki_colors.dart';
import '../../core/theme/taki_elevation.dart';
import '../../core/theme/taki_icon_size.dart';
import '../../core/theme/taki_radius.dart';
import '../../core/theme/taki_spacing.dart';
import '../../core/theme/taki_typography.dart';

/// Tema oscuro Material 3 de Taki, construido con los tokens del Design
/// System (docs/DESIGN_SYSTEM.md).
///
/// Colores de [TakiColors], escala tipográfica de [TakiTypography] (Sora para
/// títulos y DM Sans para el resto, empaquetadas en la app), radios de
/// [TakiRadius]. Las superficies se distinguen por luminosidad, sin sombras.
abstract final class AppTheme {
  /// Área táctil mínima recomendada (Material / accesibilidad, §19).
  static const double minTouchTarget = 48;

  static ThemeData dark({Color accent = TakiColors.primary}) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: Brightness.dark,
    ).copyWith(
      primary: accent,
      onPrimary: TakiColors.onPrimary,
      primaryContainer: TakiColors.primaryContainer,
      onPrimaryContainer: TakiColors.onPrimaryContainer,
      secondary: accent,
      onSecondary: TakiColors.onPrimary,
      surface: TakiColors.surface,
      onSurface: TakiColors.textPrimary,
      onSurfaceVariant: TakiColors.textSecondary,
      surfaceContainerLowest: TakiColors.background,
      surfaceContainerLow: TakiColors.surface,
      surfaceContainer: TakiColors.surface,
      surfaceContainerHigh: TakiColors.surfaceElevated,
      surfaceContainerHighest: TakiColors.surfaceHighest,
      outline: TakiColors.outline,
      outlineVariant: TakiColors.divider,
      error: TakiColors.error,
      onError: TakiColors.onPrimary,
      errorContainer: TakiColors.errorContainer,
    );

    final textTheme = _textTheme();

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: TakiColors.background,
      canvasColor: TakiColors.background,
      dividerColor: TakiColors.divider,
      textTheme: textTheme,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      visualDensity: VisualDensity.standard,
      appBarTheme: AppBarTheme(
        backgroundColor: TakiColors.background,
        foregroundColor: TakiColors.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge,
      ),
      // §16: superficie nivel 1; la pestaña activa se distingue por el
      // indicador, el icono relleno en naranja y la etiqueta en 600.
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: TakiColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: 72,
        indicatorColor: TakiColors.primaryContainer,
        indicatorShape: TakiRadius.pill,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        overlayColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.pressed)
              ? TakiColors.pressedOverlay
              : null,
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? TakiTypography.labelSmall.copyWith(
                  fontWeight: FontWeight.w600,
                  color: TakiColors.textPrimary,
                )
              : TakiTypography.labelSmall
                  .copyWith(color: TakiColors.textSecondary),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: TakiIconSize.md.value,
            color: states.contains(WidgetState.selected)
                ? TakiColors.active
                : TakiColors.iconSecondary,
          ),
        ),
      ),
      cardTheme: const CardThemeData(
        color: TakiColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: TakiRadius.lgAll),
      ),
      dividerTheme: const DividerThemeData(
        color: TakiColors.divider,
        thickness: TakiElevation.borderWidth,
      ),
      listTileTheme: const ListTileThemeData(
        minTileHeight: minTouchTarget,
        iconColor: TakiColors.iconSecondary,
        textColor: TakiColors.textPrimary,
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size.square(minTouchTarget),
        ),
      ),
      // §9 primario: naranja; pulsado primaryPressed; deshabilitado al 12/38 %.
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(64, minTouchTarget)),
          shape: const WidgetStatePropertyAll(TakiRadius.pill),
          textStyle: const WidgetStatePropertyAll(TakiTypography.label),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return TakiColors.disabledContainer;
            }
            return states.contains(WidgetState.pressed)
                ? TakiColors.primaryPressed
                : accent;
          }),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.disabled)
                ? TakiColors.disabledContent
                : TakiColors.onPrimary,
          ),
          overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(64, minTouchTarget),
        ),
      ),
      // §9 secundario.
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, minTouchTarget),
          backgroundColor: TakiColors.surfaceElevated,
          foregroundColor: TakiColors.textPrimary,
          textStyle: TakiTypography.label,
          shape: TakiRadius.pill,
          side: const BorderSide(
            color: TakiColors.outline,
            width: TakiElevation.borderWidth,
          ),
        ).copyWith(overlayColor: _pressedOverlay),
      ),
      // §9 terciario.
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(64, minTouchTarget),
          foregroundColor: accent,
          textStyle: TakiTypography.label,
          shape: TakiRadius.pill,
        ).copyWith(overlayColor: _pressedOverlay),
      ),
      // §5 nivel 2 con scrim; §4 bordes superiores xl.
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: TakiColors.surfaceElevated,
        surfaceTintColor: Colors.transparent,
        modalBarrierColor: TakiColors.scrim,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(TakiRadius.xl),
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: TakiColors.surfaceElevated,
        surfaceTintColor: Colors.transparent,
        barrierColor: TakiColors.scrim,
        shape: const RoundedRectangleBorder(borderRadius: TakiRadius.xlAll),
        titleTextStyle: textTheme.titleLarge,
      ),
      popupMenuTheme: const PopupMenuThemeData(
        color: TakiColors.surfaceElevated,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: TakiRadius.lgAll),
      ),
      // §15: nivel 2, texto body, acción terciaria, a 8 sobre el mini player
      // o la navegación.
      snackBarTheme: SnackBarThemeData(
        backgroundColor: TakiColors.surfaceElevated,
        contentTextStyle: TakiTypography.body.copyWith(
          color: TakiColors.textPrimary,
        ),
        actionTextColor: accent,
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(borderRadius: TakiRadius.mdAll),
        insetPadding: const EdgeInsets.fromLTRB(
          TakiSpacing.pageGutter,
          0,
          TakiSpacing.pageGutter,
          TakiSpacing.sm,
        ),
        elevation: 0,
      ),
      // §1.2: tooltips sobre surfaceHighest; §4: radio sm.
      tooltipTheme: TooltipThemeData(
        decoration: const ShapeDecoration(
          color: TakiColors.surfaceHighest,
          shape: RoundedRectangleBorder(borderRadius: TakiRadius.smAll),
        ),
        textStyle: textTheme.bodySmall?.copyWith(
          color: TakiColors.textPrimary,
        ),
      ),
    );
  }

  static final WidgetStateProperty<Color?> _pressedOverlay =
      WidgetStateProperty.resolveWith(
    (states) =>
        states.contains(WidgetState.pressed) ? TakiColors.pressedOverlay : null,
  );

  /// Escala de Material con las familias Taki. Los estilos con equivalente
  /// directo en §2.2 usan el rol Taki; el resto conserva el tamaño de
  /// Material (sin rol definido todavía, ver §21).
  static TextTheme _textTheme() {
    final base = ThemeData(brightness: Brightness.dark).textTheme.apply(
          fontFamily: TakiTypography.bodyFontFamily,
          bodyColor: TakiColors.textPrimary,
          displayColor: TakiColors.textPrimary,
        );

    TextStyle? sora(TextStyle? style) =>
        style?.copyWith(fontFamily: TakiTypography.titleFontFamily);
    TextStyle role(TextStyle style) =>
        style.copyWith(color: TakiColors.textPrimary);

    return base.copyWith(
      displayLarge: sora(base.displayLarge),
      displayMedium: sora(base.displayMedium),
      displaySmall: sora(base.displaySmall),
      headlineLarge: sora(base.headlineLarge),
      headlineMedium: sora(base.headlineMedium),
      headlineSmall: role(TakiTypography.headline),
      titleLarge: role(TakiTypography.titleLarge),
      titleMedium: role(TakiTypography.titleMedium),
      titleSmall: sora(base.titleSmall),
      bodyLarge: role(TakiTypography.bodyLarge),
      bodyMedium: role(TakiTypography.body),
      labelLarge: role(TakiTypography.label),
    );
  }
}
