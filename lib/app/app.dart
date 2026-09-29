import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/library/presentation/providers/favorites_providers.dart';
import 'router.dart';
import 'theme/app_theme.dart';

class TakiApp extends ConsumerWidget {
  const TakiApp({super.key});

  /// La app está en español; también los textos internos de Flutter
  /// (acciones de accesibilidad para reordenar, diálogos, etc.).
  static const Locale locale = Locale('es');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    // Mantiene vivos los favoritos resueltos: cada vez que la biblioteca se
    // carga o se refresca se reencuentran (y se corrigen) los ids, sin
    // esperar a que se abra la pestaña Favoritos.
    ref.listen(favoriteSongsProvider, (_, _) {});

    return MaterialApp.router(
      title: 'Taki',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.dark,
      locale: locale,
      supportedLocales: const [locale],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      routerConfig: router,
    );
  }
}
