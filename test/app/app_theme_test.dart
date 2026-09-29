import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taki/app/app.dart';
import 'package:taki/app/theme/app_theme.dart';
import 'package:taki/core/theme/app_colors.dart';
import 'package:taki/core/theme/taki_colors.dart';
import 'package:taki/core/theme/taki_radius.dart';
import 'package:taki/core/theme/taki_typography.dart';

import '../helpers/library_fakes.dart';

void main() {
  final theme = AppTheme.dark();

  test('AppColors es un alias de la paleta Taki (§22 paso 1)', () {
    expect(AppColors.background, TakiColors.background);
    expect(AppColors.surface, TakiColors.surface);
    expect(AppColors.surfaceElevated, TakiColors.surfaceElevated);
    expect(AppColors.border, TakiColors.outline);
    expect(AppColors.textPrimary, TakiColors.textPrimary);
    expect(AppColors.textSecondary, TakiColors.textSecondary);
    expect(AppColors.accent, TakiColors.primary);
    expect(AppColors.onAccent, TakiColors.onPrimary);
    expect(AppColors.onTextPrimary, TakiColors.onTextPrimary);
    expect(AppColors.miniProgressTrack, TakiColors.divider);
    expect(AppColors.seekTrack, TakiColors.divider);
  });

  group('superficies (§5)', () {
    test('fondo nivel 0; contenedores por luminosidad', () {
      expect(theme.scaffoldBackgroundColor, TakiColors.background);
      expect(theme.appBarTheme.backgroundColor, TakiColors.background);
      expect(theme.colorScheme.surfaceContainerLowest, TakiColors.background);
      expect(theme.colorScheme.surface, TakiColors.surface);
      expect(theme.colorScheme.surfaceContainerHigh, TakiColors.surfaceElevated);
      expect(theme.colorScheme.surfaceContainerHighest, TakiColors.surfaceHighest);
    });

    test('sheets, diálogos y SnackBars en nivel 2, con scrim en los modales',
        () {
      expect(theme.bottomSheetTheme.backgroundColor, TakiColors.surfaceElevated);
      expect(theme.bottomSheetTheme.modalBarrierColor, TakiColors.scrim);
      expect(theme.dialogTheme.backgroundColor, TakiColors.surfaceElevated);
      expect(theme.dialogTheme.barrierColor, TakiColors.scrim);
      expect(theme.snackBarTheme.backgroundColor, TakiColors.surfaceElevated);
      expect(theme.snackBarTheme.behavior, SnackBarBehavior.floating);
    });

    test('sin sombras decorativas en las superficies del shell', () {
      expect(theme.navigationBarTheme.elevation, 0);
      expect(theme.appBarTheme.elevation, 0);
      expect(theme.cardTheme.elevation, 0);
      expect(theme.snackBarTheme.elevation, 0);
    });
  });

  test('el naranja es acento, no fondo', () {
    expect(theme.colorScheme.primary, TakiColors.primary);
    for (final background in [
      theme.scaffoldBackgroundColor,
      theme.navigationBarTheme.backgroundColor,
      theme.appBarTheme.backgroundColor,
      theme.bottomSheetTheme.backgroundColor,
      theme.dialogTheme.backgroundColor,
      theme.snackBarTheme.backgroundColor,
    ]) {
      expect(background, isNot(TakiColors.primary));
    }
  });

  group('navegación inferior (§16)', () {
    final nav = theme.navigationBarTheme;
    const selected = {WidgetState.selected};
    const idle = <WidgetState>{};

    test('superficie, alto, indicador y etiquetas siempre visibles', () {
      expect(nav.backgroundColor, TakiColors.surface);
      expect(nav.height, 72);
      expect(nav.indicatorColor, TakiColors.primaryContainer);
      expect(nav.indicatorShape, TakiRadius.pill);
      expect(nav.labelBehavior, NavigationDestinationLabelBehavior.alwaysShow);
    });

    test('activa: icono naranja y etiqueta 600 en textPrimary', () {
      expect(nav.iconTheme!.resolve(selected)!.color, TakiColors.active);
      final label = nav.labelTextStyle!.resolve(selected)!;
      expect(label.color, TakiColors.textPrimary);
      expect(label.fontWeight, FontWeight.w600);
      expect(label.fontSize, TakiTypography.labelSmall.fontSize);
    });

    test('inactiva: icono y etiqueta en gris secundario', () {
      expect(nav.iconTheme!.resolve(idle)!.color, TakiColors.iconSecondary);
      final label = nav.labelTextStyle!.resolve(idle)!;
      expect(label.color, TakiColors.textSecondary);
      expect(label.fontWeight, TakiTypography.labelSmall.fontWeight);
    });
  });

  group('tipografía (§2.2)', () {
    final text = theme.textTheme;

    void expectRole(TextStyle? style, TextStyle role, String name) {
      expect(style!.fontFamily, role.fontFamily, reason: name);
      expect(style.fontSize, role.fontSize, reason: name);
      expect(style.fontWeight, role.fontWeight, reason: name);
      expect(style.height, role.height, reason: name);
      expect(style.letterSpacing, role.letterSpacing, reason: name);
    }

    test('los estilos con equivalente usan el rol Taki', () {
      expectRole(text.headlineSmall, TakiTypography.headline, 'headlineSmall');
      expectRole(text.titleLarge, TakiTypography.titleLarge, 'titleLarge');
      expectRole(text.titleMedium, TakiTypography.titleMedium, 'titleMedium');
      expectRole(text.bodyLarge, TakiTypography.bodyLarge, 'bodyLarge');
      expectRole(text.bodyMedium, TakiTypography.body, 'bodyMedium');
      expectRole(text.labelLarge, TakiTypography.label, 'labelLarge');
    });

    test('los que no tienen rol conservan Material con las familias Taki', () {
      expect(text.titleSmall!.fontFamily, TakiTypography.titleFontFamily);
      expect(text.displayLarge!.fontFamily, TakiTypography.titleFontFamily);
      expect(text.bodySmall!.fontFamily, TakiTypography.bodyFontFamily);
      expect(text.labelMedium!.fontFamily, TakiTypography.bodyFontFamily);
    });

    test('la barra superior y los diálogos usan titleLarge', () {
      expectRole(
        theme.appBarTheme.titleTextStyle,
        TakiTypography.titleLarge,
        'appBar',
      );
      expectRole(
        theme.dialogTheme.titleTextStyle,
        TakiTypography.titleLarge,
        'dialog',
      );
    });
  });

  testWidgets('el shell pinta la navegación con los tokens Taki',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: grantedEmptyLibraryOverrides(),
        child: const TakiApp(),
      ),
    );
    await tester.pumpAndSettle();

    Color? iconColor(IconData icon) => IconTheme.of(
          tester.element(find.byIcon(icon)),
        ).color;

    // Biblioteca es la pestaña activa al arrancar.
    expect(iconColor(Icons.library_music), TakiColors.active);
    expect(iconColor(Icons.queue_music_outlined), TakiColors.iconSecondary);
    expect(iconColor(Icons.favorite_outline), TakiColors.iconSecondary);
    expect(iconColor(Icons.settings_outlined), TakiColors.iconSecondary);

    final material = tester.widget<Material>(find.descendant(
      of: find.byType(NavigationBar),
      matching: find.byType(Material),
    ).first);
    expect(material.color, TakiColors.surface);
  });
}
