import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mocktail/mocktail.dart';
import 'package:taki/app/theme/app_theme.dart';
import 'package:taki/app/widgets/song_actions_sheet.dart';
import 'package:taki/core/domain/entities/song.dart';
import 'package:taki/features/library/presentation/pages/favorites_page.dart';
import 'package:taki/features/player/presentation/providers/player_providers.dart';

import '../../../helpers/favorites_fakes.dart';
import '../../../helpers/library_fakes.dart';
import '../../../helpers/player_fakes.dart';

void main() {
  late MockMediaPermission permission;
  late MockSongRepository library;
  late FakeFavoritesRepository favorites;
  late MockPlaySongs playSongs;
  late MockPlaySongsShuffled playShuffled;

  final alfa = buildSong(id: 1, title: 'Alfa', durationMs: 3600000);
  final beta = buildSong(id: 2, title: 'Beta', durationMs: 300000);
  final gamma = buildSong(id: 3, title: 'Gamma');

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    registerFallbackValue(<Song>[]);
  });

  setUp(() {
    permission = MockMediaPermission();
    when(permission.isGranted).thenAnswer((_) async => true);
    library = MockSongRepository();
    when(library.getSongs).thenAnswer((_) async => [alfa, beta, gamma]);
    favorites = FakeFavoritesRepository();
    playSongs = MockPlaySongs();
    when(() => playSongs(any(), any())).thenAnswer((_) async {});
    playShuffled = MockPlaySongsShuffled();
    when(() => playShuffled(any())).thenAnswer((_) async {});
  });

  Future<void> pumpFavorites(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...libraryOverrides(
            permission: permission,
            songs: library,
            favorites: favorites,
          ),
          playSongsProvider.overrideWithValue(playSongs),
          playSongsShuffledProvider.overrideWithValue(playShuffled),
        ],
        child: MaterialApp(theme: AppTheme.dark(), home: const FavoritesPage(onSongActions: showSongActions)),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Alfa se marcó primero y Beta después: Beta es la más reciente.
  void markAlfaThenBeta() {
    favorites
      ..seed(favorites.entryFor(alfa))
      ..seed(favorites.entryFor(beta));
  }

  testWidgets('lista los favoritos, más recientes primero', (tester) async {
    markAlfaThenBeta();
    await pumpFavorites(tester);

    expect(find.text('2 canciones · 1 h 05 min'), findsOneWidget);
    expect(find.text('Gamma'), findsNothing);
    expect(
      tester.getTopLeft(find.text('Beta')).dy,
      lessThan(tester.getTopLeft(find.text('Alfa')).dy),
    );
  });

  testWidgets('Reproducir empieza por la primera', (tester) async {
    markAlfaThenBeta();
    await pumpFavorites(tester);

    await tester.tap(find.text('Reproducir'));
    await tester.pumpAndSettle();

    verify(() => playSongs([beta, alfa], 0)).called(1);
  });

  testWidgets('Aleatorio reproduce la lista mezclada', (tester) async {
    markAlfaThenBeta();
    await pumpFavorites(tester);

    await tester.tap(find.text('Aleatorio'));
    await tester.pumpAndSettle();

    verify(() => playShuffled([beta, alfa])).called(1);
    verifyNever(() => playSongs(any(), any()));
  });

  testWidgets('tocar una canción reproduce los favoritos desde ella',
      (tester) async {
    markAlfaThenBeta();
    await pumpFavorites(tester);

    await tester.tap(find.text('Alfa'));
    await tester.pumpAndSettle();

    verify(() => playSongs([beta, alfa], 1)).called(1);
  });

  testWidgets('pulsación larga ofrece "Quitar de favoritos" y la quita',
      (tester) async {
    markAlfaThenBeta();
    await pumpFavorites(tester);

    await tester.longPress(find.text('Alfa'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Quitar de favoritos'));
    await tester.pumpAndSettle();

    expect(favorites.entries.keys, [2]);
    expect(find.text('Quitada de favoritos'), findsOneWidget);
    expect(find.text('Alfa'), findsNothing);
  });

  testWidgets('estado vacío', (tester) async {
    await pumpFavorites(tester);

    expect(
      find.text('Aún no tienes favoritos. Toca el corazón en Reproduciendo '
          'o mantén pulsada una canción.'),
      findsOneWidget,
    );
  });

  testWidgets('base no disponible: error y Reintentar', (tester) async {
    favorites.failing = true;
    markAlfaThenBeta();
    await pumpFavorites(tester);

    expect(find.text('Favoritos no disponibles'), findsOneWidget);

    favorites.failing = false;
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();

    expect(find.text('Beta'), findsOneWidget);
  });

  testWidgets('se actualiza al marcar un favorito desde otro lugar',
      (tester) async {
    await pumpFavorites(tester);

    await favorites.add(gamma);
    await tester.pumpAndSettle();

    expect(find.text('Gamma'), findsOneWidget);
  });
}
