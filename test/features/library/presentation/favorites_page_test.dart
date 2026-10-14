import 'dart:async';
import 'package:taki/core/domain/entities/local_song.dart';
import 'package:taki/core/domain/entities/artwork_reference.dart';
import '../../../helpers/artwork_reference_ext.dart';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:taki/app/theme/app_theme.dart';
import 'package:taki/app/widgets/song_actions_sheet.dart';
import 'package:taki/core/artwork/album_artwork_builder.dart';
import 'package:taki/core/artwork/artwork_providers.dart';
import 'package:taki/core/domain/entities/song.dart';
import 'package:taki/core/domain/ports/artwork_repository.dart';
import 'package:taki/core/theme/taki_colors.dart';
import 'package:taki/core/theme/taki_typography.dart';
import 'package:taki/core/widgets/song_actions.dart';
import 'package:taki/core/widgets/taki_artwork.dart';
import 'package:taki/core/widgets/taki_button.dart';
import 'package:taki/core/widgets/taki_empty_state.dart';
import 'package:taki/core/widgets/taki_error_state.dart';
import 'package:taki/core/widgets/taki_playing_indicator.dart';
import 'package:taki/core/widgets/taki_song_tile.dart';
import 'package:taki/features/library/domain/entities/favorite_entry.dart';
import 'package:taki/features/library/presentation/pages/favorites_page.dart';
import 'package:taki/features/library/presentation/providers/favorites_providers.dart';
import 'package:taki/features/player/domain/entities/playback_state.dart';
import 'package:taki/features/player/presentation/providers/player_providers.dart';
import 'package:taki/core/domain/entities/local_music_identity.dart';


import '../../../helpers/favorites_fakes.dart';
import '../../../helpers/library_fakes.dart';
import '../../../helpers/player_fakes.dart';
import '../../../helpers/artwork_image.dart';

void main() {
  late MockMediaPermission permission;
  late MockSongRepository library;
  late _GatedFavoritesRepository favorites;
  late MockPlaySongs playSongs;
  late MockPlaySongsShuffled playShuffled;
  late FakeAudioPlayerPort player;
  late FakeNotificationPermission notifications;

  final alfa = buildSong(id: 1, title: 'Alfa', durationMs: 3600000);
  final beta = buildSong(id: 2, title: 'Beta', durationMs: 300000);
  final gamma = buildSong(id: 3, title: 'Gamma');

  setUpAll(() {
    registerFallbackValue(<Song>[]);
  });

  setUp(() {
    permission = MockMediaPermission();
    when(permission.isGranted).thenAnswer((_) async => true);
    when(permission.isPermanentlyDenied).thenAnswer((_) async => false);
    library = MockSongRepository();
    when(library.getSongs).thenAnswer((_) async => [alfa, beta, gamma]);
    favorites = _GatedFavoritesRepository();
    playSongs = MockPlaySongs();
    when(() => playSongs(any(), any())).thenAnswer((_) async {});
    playShuffled = MockPlaySongsShuffled();
    when(() => playShuffled(any())).thenAnswer((_) async {});
    player = FakeAudioPlayerPort();
    notifications = FakeNotificationPermission();
  });

  Future<void> pumpFavorites(
    WidgetTester tester, {
    List<Override> overrides = const [],
    ShowSongActions onSongActions = showSongActions,
    Size? size,
    double textScale = 1,
    bool settle = true,
  }) async {
    if (size != null) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
    }
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...libraryOverrides(
            permission: permission,
            songs: library,
            player: player,
            notifications: notifications,
            favorites: favorites,
          ),
          playSongsProvider.overrideWithValue(playSongs),
          playSongsShuffledProvider.overrideWithValue(playShuffled),
          ...overrides,
        ],
        child: MaterialApp(
          theme: AppTheme.dark(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(textScale),
            ),
            child: child!,
          ),
          home: FavoritesPage(onSongActions: onSongActions),
        ),
      ),
    );
    // Con una canción sonando las barras se animan sin fin.
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
    }
  }

  /// Alfa se marcó primero y Beta después: Beta es la más reciente.
  void markAlfaThenBeta() {
    favorites
      ..seed(favorites.entryFor(alfa))
      ..seed(favorites.entryFor(beta));
  }

  testWidgets('la actual se identifica por identidad, no por Song.id',
      (tester) async {
    // Ambas tienen id 0: solo la identidad las distingue.
    final uno = buildSong(id: 31, title: 'Foráneo 1');
    final dos = buildSong(id: 32, title: 'Foráneo 2');
    when(library.getSongs).thenAnswer((_) async => [uno, dos]);
    favorites
      ..seed(favorites.entryFor(uno))
      ..seed(favorites.entryFor(dos));
    await pumpFavorites(tester);

    player.emitState(
      PlaybackState(queue: [uno, dos], currentIndex: 1, isPlaying: true),
    );
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    TakiNowPlaying stateOf(String title) => tester
        .widget<TakiSongTile>(
          find.ancestor(of: find.text(title), matching: find.byType(TakiSongTile)),
        )
        .playback;
    expect(stateOf('Foráneo 2'), TakiNowPlaying.playing);
    expect(stateOf('Foráneo 1'), TakiNowPlaying.none);
  });

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

    expect(favorites.entries.keys, [localMusicIdentity(2)]);
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

  group('Design System (Fase 1.7B)', () {
    final uno = buildSong(id: 1, title: 'Uno', albumId: 11, durationMs: 125000);
    final dos = buildSong(id: 2, title: 'Dos', albumId: 22, durationMs: 185000);
    final tres = buildSong(id: 3, title: 'Tres', albumId: null);

    /// Marcadas en orden Uno, Dos, Tres: se ven Tres, Dos, Uno.
    void markAll() {
      when(library.getSongs).thenAnswer((_) async => [uno, dos, tres]);
      favorites
        ..seed(favorites.entryFor(uno))
        ..seed(favorites.entryFor(dos))
        ..seed(favorites.entryFor(tres));
    }

    Finder tileFinder(String title) =>
        find.ancestor(of: find.text(title), matching: find.byType(TakiSongTile));

    TakiSongTile tileOf(WidgetTester tester, String title) =>
        tester.widget<TakiSongTile>(tileFinder(title));

    ProviderContainer containerOf(WidgetTester tester) =>
        ProviderScope.containerOf(tester.element(find.byType(FavoritesPage)));

    /// Solo el spinner de carga (el de pull-to-refresh es una subclase).
    Finder loadingSpinner() => find.byWidgetPredicate(
          (w) => w.runtimeType == CircularProgressIndicator,
        );

    group('lista', () {
      testWidgets('las filas son TakiSongTile con duración, sin ⋯ ni corazón',
          (tester) async {
        markAll();
        await pumpFavorites(tester);

        expect(find.byType(TakiSongTile), findsNWidgets(3));
        for (final title in ['Uno', 'Dos', 'Tres']) {
          final tile = tileOf(tester, title);
          expect(tile.showDuration, isTrue, reason: title);
          expect(tile.onMore, isNull, reason: title);
          expect(tile.isFavorite, isFalse, reason: title);
          expect(tile.available, isTrue, reason: title);
          expect(tile.onTap, isNotNull, reason: title);
          expect(tile.onLongPress, isNotNull, reason: title);
        }
        expect(find.text('2:05'), findsOneWidget);
        expect(find.text('3:05'), findsOneWidget);
        expect(find.text('3:00'), findsOneWidget);
        expect(find.byIcon(Icons.more_horiz_rounded), findsNothing);
        expect(find.byTooltip(TakiSongTile.moreLabel), findsNothing);
        expect(find.byIcon(Icons.favorite_rounded), findsNothing);
      });

      testWidgets('respeta el orden del provider: más reciente → más antiguo',
          (tester) async {
        markAll();
        await pumpFavorites(tester);

        final fromProvider =
            containerOf(tester).read(favoriteSongsProvider).requireValue;
        expect(fromProvider.map((s) => s.title), ['Tres', 'Dos', 'Uno']);

        final rendered = tester
            .widgetList<TakiSongTile>(find.byType(TakiSongTile))
            .map((t) => t.song.title)
            .toList();
        expect(rendered, ['Tres', 'Dos', 'Uno']);
        final y = [for (final t in rendered) tester.getTopLeft(find.text(t)).dy];
        expect(y[0], lessThan(y[1]));
        expect(y[1], lessThan(y[2]));
      });

      testWidgets('tocar una fila reproduce los favoritos desde su índice y '
          'pide el permiso de notificaciones', (tester) async {
        markAll();
        await pumpFavorites(tester);

        await tester.tap(find.text('Uno'));
        await tester.pumpAndSettle();

        verify(() => playSongs([tres, dos, uno], 2)).called(1);
        expect(notifications.requests, 1);
      });

      testWidgets('la pulsación larga llama al ShowSongActions recibido',
          (tester) async {
        markAll();
        final shown = <Song>[];
        await pumpFavorites(
          tester,
          onSongActions: (context, ref, song, {extraActions = const []}) async {
            shown.add(song);
          },
        );

        await tester.longPress(find.text('Dos'));
        await tester.pumpAndSettle();

        expect(shown, [dos]);
        verifyNever(() => playSongs(any(), any()));
      });

      testWidgets('el menú mantiene sus acciones', (tester) async {
        markAll();
        await pumpFavorites(tester);

        await tester.longPress(find.text('Dos'));
        await tester.pumpAndSettle();

        expect(find.text('Reproducir a continuación'), findsOneWidget);
        expect(find.text('Añadir a la cola'), findsOneWidget);
        expect(find.text('Quitar de favoritos'), findsOneWidget);
        expect(find.text('Añadir a una playlist'), findsOneWidget);
      });
    });

    group('canción actual', () {
      testWidgets('sonando: título en acento y barras animadas',
          (tester) async {
        markAll();
        await pumpFavorites(tester);

        player.emitState(PlaybackState(
          queue: [tres, dos, uno],
          currentIndex: 1,
          isPlaying: true,
        ));
        for (var i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 50));
        }

        expect(tileOf(tester, 'Dos').playback, TakiNowPlaying.playing);
        expect(tileOf(tester, 'Uno').playback, TakiNowPlaying.none);
        expect(tileOf(tester, 'Tres').playback, TakiNowPlaying.none);
        final bars = find.byType(TakiPlayingIndicator);
        expect(bars, findsOneWidget);
        expect(
          find.descendant(of: tileFinder('Dos'), matching: bars),
          findsOneWidget,
        );
        expect(tester.widget<TakiPlayingIndicator>(bars).animate, isTrue);
        expect(
          tester.widget<Text>(find.text('Dos')).style?.color,
          TakiColors.active,
        );
        expect(
          tester.widget<Text>(find.text('Uno')).style?.color,
          TakiColors.textPrimary,
        );
      });

      testWidgets('en pausa: barras quietas', (tester) async {
        markAll();
        await pumpFavorites(tester);

        player.emitState(
          PlaybackState(queue: [tres, dos, uno], currentIndex: 1),
        );
        await tester.pumpAndSettle();

        expect(tileOf(tester, 'Dos').playback, TakiNowPlaying.paused);
        expect(
          tester
              .widget<TakiPlayingIndicator>(find.byType(TakiPlayingIndicator))
              .animate,
          isFalse,
        );
      });

      testWidgets('semántica: título, artista, duración y estado',
          (tester) async {
        final handle = tester.ensureSemantics();
        markAll();
        await pumpFavorites(tester);

        player.emitState(PlaybackState(
          queue: [tres, dos, uno],
          currentIndex: 2,
          isPlaying: true,
        ));
        for (var i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 50));
        }
        expect(
          tester.getSemantics(tileFinder('Uno')),
          isSemantics(
            label: 'Uno, Artista, 2:05',
            value: TakiSongTile.playingLabel,
            isButton: true,
            hasTapAction: true,
            hasLongPressAction: true,
          ),
        );

        player.emitState(
          PlaybackState(queue: [tres, dos, uno], currentIndex: 2),
        );
        await tester.pumpAndSettle();
        expect(
          tester.getSemantics(tileFinder('Uno')),
          isSemantics(label: 'Uno, Artista, 2:05', value: 'En pausa'),
        );
        // Una fila que no suena no anuncia estado.
        expect(
          tester.getSemantics(tileFinder('Dos')),
          isSemantics(label: 'Dos, Artista, 3:05', value: ''),
        );
        handle.dispose();
      });
    });

    group('cabecera', () {
      testWidgets('"Favoritos" es encabezado; resumen en trackSubtitle',
          (tester) async {
        final handle = tester.ensureSemantics();
        markAll();
        await pumpFavorites(tester);

        expect(
          tester.getSemantics(find.text(FavoritesPage.title)),
          isSemantics(isHeader: true),
        );
        final summary = find.text('3 canciones · 8 min');
        expect(summary, findsOneWidget);
        final style = tester.widget<Text>(summary).style!;
        expect(style.fontSize, TakiTypography.trackSubtitle.fontSize);
        expect(style.color, TakiColors.textSecondary);
        handle.dispose();
      });

      testWidgets('Reproducir es TakiButton primario; Aleatorio, secundario; '
          'ambos de al menos 48', (tester) async {
        final handle = tester.ensureSemantics();
        markAll();
        await pumpFavorites(tester);

        final play = find.widgetWithText(TakiButton, 'Reproducir');
        final shuffle = find.widgetWithText(TakiButton, 'Aleatorio');
        expect(tester.widget<TakiButton>(play).variant,
            TakiButtonVariant.primary);
        expect(tester.widget<TakiButton>(shuffle).variant,
            TakiButtonVariant.secondary);
        for (final button in [play, shuffle]) {
          final size = tester.getSize(button);
          expect(size.height, greaterThanOrEqualTo(48));
          expect(size.width, greaterThanOrEqualTo(48));
        }
        expect(
          tester.getSemantics(play),
          isSemantics(label: 'Reproducir', isButton: true, hasTapAction: true),
        );
        expect(
          tester.getSemantics(shuffle),
          isSemantics(label: 'Aleatorio', isButton: true, hasTapAction: true),
        );
        handle.dispose();
      });

      testWidgets('Reproducir llama a PlaySongs desde el índice 0 y pide el '
          'permiso de notificaciones', (tester) async {
        markAll();
        await pumpFavorites(tester);

        await tester.tap(find.widgetWithText(TakiButton, 'Reproducir'));
        await tester.pumpAndSettle();

        verify(() => playSongs([tres, dos, uno], 0)).called(1);
        verifyNever(() => playShuffled(any()));
        expect(notifications.requests, 1);
      });

      testWidgets('Aleatorio llama a PlaySongsShuffled con los favoritos y '
          'pide el permiso de notificaciones', (tester) async {
        markAll();
        await pumpFavorites(tester);

        await tester.tap(find.widgetWithText(TakiButton, 'Aleatorio'));
        await tester.pumpAndSettle();

        verify(() => playShuffled([tres, dos, uno])).called(1);
        verifyNever(() => playSongs(any(), any()));
        expect(notifications.requests, 1);
      });
    });

    group('estados', () {
      testWidgets('vacío: TakiEmptyState de primer uso, sin acción',
          (tester) async {
        await pumpFavorites(tester);

        final state =
            tester.widget<TakiEmptyState>(find.byType(TakiEmptyState));
        expect(state.kind, TakiEmptyStateKind.firstUse);
        expect(state.icon, Icons.favorite_border_rounded);
        expect(state.title, 'Sin favoritos');
        expect(state.action, isNull);
        expect(state.secondaryAction, isNull);
        expect(find.byType(TakiButton), findsNothing);
      });

      testWidgets('vacío: pull-to-refresh vuelve a escanear', (tester) async {
        await pumpFavorites(tester);
        expect(find.byType(RefreshIndicator), findsOneWidget);

        await tester.fling(
          find.text('Sin favoritos'),
          const Offset(0, 400),
          1000,
        );
        await tester.pumpAndSettle();

        verify(library.getSongs).called(2);
      });

      testWidgets('sin permiso: TakiErrorState de permiso, sin '
          'pull-to-refresh', (tester) async {
        when(permission.isGranted).thenAnswer((_) async => false);
        await pumpFavorites(tester);

        final state =
            tester.widget<TakiErrorState>(find.byType(TakiErrorState));
        expect(state.kind, TakiErrorStateKind.permission);
        expect(state.title, 'Taki necesita acceso a tu música');
        expect(state.action!.label, 'Permitir acceso');
        expect(find.byType(RefreshIndicator), findsNothing);
        expect(
          tester
              .getSize(find.widgetWithText(TakiButton, 'Permitir acceso'))
              .height,
          greaterThanOrEqualTo(48),
        );
      });

      testWidgets('"Permitir acceso" pide el permiso; si queda denegado para '
          'siempre pasa a "Abrir ajustes"', (tester) async {
        when(permission.isGranted).thenAnswer((_) async => false);
        when(permission.request).thenAnswer((_) async {
          when(permission.isPermanentlyDenied).thenAnswer((_) async => true);
          return false;
        });
        when(permission.openSettings).thenAnswer((_) async => true);
        await pumpFavorites(tester);

        await tester.tap(find.text('Permitir acceso'));
        await tester.pumpAndSettle();
        verify(permission.request).called(1);
        expect(find.text('Abrir ajustes'), findsOneWidget);
        expect(find.text('Permitir acceso'), findsNothing);

        await tester.tap(find.text('Abrir ajustes'));
        await tester.pumpAndSettle();
        verify(permission.openSettings).called(1);
        verifyNever(permission.request);
      });

      testWidgets('"Permitir acceso" concedido muestra los favoritos',
          (tester) async {
        markAll();
        when(permission.isGranted).thenAnswer((_) async => false);
        when(permission.request).thenAnswer((_) async {
          when(permission.isGranted).thenAnswer((_) async => true);
          return true;
        });
        await pumpFavorites(tester);

        await tester.tap(find.text('Permitir acceso'));
        await tester.pumpAndSettle();

        expect(find.text('Dos'), findsOneWidget);
      });

      testWidgets('error: TakiErrorState de error, sin pull-to-refresh; '
          'Reintentar usa retryFavorites', (tester) async {
        markAll();
        favorites.failing = true;
        await pumpFavorites(tester);

        final state =
            tester.widget<TakiErrorState>(find.byType(TakiErrorState));
        expect(state.kind, TakiErrorStateKind.error);
        expect(state.title, 'Favoritos no disponibles');
        expect(state.action!.label, 'Reintentar');
        expect(find.byType(RefreshIndicator), findsNothing);

        favorites.failing = false;
        await tester.tap(find.widgetWithText(TakiButton, 'Reintentar'));
        await tester.pumpAndSettle();
        expect(find.text('Dos'), findsOneWidget);
        // retryFavorites no vuelve a escanear si la biblioteca estaba bien.
        verify(library.getSongs).called(1);
      });

      testWidgets('error de la biblioteca: mismo estado; Reintentar vuelve a '
          'escanear', (tester) async {
        markAll();
        when(library.getSongs).thenThrow(Exception('MediaStore'));
        await pumpFavorites(tester);

        expect(find.text('Favoritos no disponibles'), findsOneWidget);
        expect(find.byType(RefreshIndicator), findsNothing);

        when(library.getSongs).thenAnswer((_) async => [uno, dos, tres]);
        await tester.tap(find.text('Reintentar'));
        await tester.pumpAndSettle();
        expect(find.text('Dos'), findsOneWidget);
      });

      testWidgets('carga: spinner hasta tener datos', (tester) async {
        markAll();
        final pending = Completer<List<LocalSong>>();
        when(library.getSongs).thenAnswer((_) => pending.future);
        await pumpFavorites(tester, settle: false);

        expect(loadingSpinner(), findsOneWidget);
        pending.complete([uno, dos, tres]);
        await tester.pumpAndSettle();
        expect(loadingSpinner(), findsNothing);
        expect(find.text('Dos'), findsOneWidget);
      });

      testWidgets('al recalcular con datos no muestra el spinner '
          '(skipLoadingOnReload)', (tester) async {
        markAll();
        await pumpFavorites(tester);

        final gate = favorites.gate = Completer<void>();
        // Cambian los ids favoritos: favoriteSongsProvider se recalcula.
        await favorites.remove(uno.musicIdentity);
        await tester.pump();
        await tester.pump();

        expect(containerOf(tester).read(favoriteSongsProvider).isLoading,
            isTrue);
        expect(loadingSpinner(), findsNothing);
        expect(find.text('Dos'), findsOneWidget);

        // La lista anterior sigue visible hasta que llega la nueva.
        expect(find.text('Uno'), findsOneWidget);

        gate.complete();
        await tester.pumpAndSettle();
        expect(containerOf(tester).read(favoriteSongsProvider).isLoading,
            isFalse);
        expect(find.text('Uno'), findsNothing);
        expect(loadingSpinner(), findsNothing);
      });
    });

    group('carátulas', () {
      testWidgets('ArtworkCache → bytes → MemoryImage a 48', (tester) async {
        final artwork = _BytesArtworkRepository();
        markAll();
        await pumpFavorites(
          tester,
          overrides: [artworkRepositoryProvider.overrideWithValue(artwork)],
        );

        TakiArtwork artOf(String title) => tester.widget<TakiArtwork>(
              find.descendant(
                of: tileFinder(title),
                matching: find.byType(TakiArtwork),
              ),
            );

        expect(artOf('Uno').size, TakiSongTile.artworkSize);
        expect(memoryImageOf(artOf('Uno').image!).bytes.first, 11);
        expect(memoryImageOf(artOf('Dos').image!).bytes.first, 22);
        // Sin álbum: placeholder y ninguna petición.
        expect(artOf('Tres').image, isNull);
        expect(artwork.requests.map((r) => r.$1).toSet(), {11, 22});
      });

      testWidgets('no se vuelven a pedir con cambios de canción, posición ni '
          'al recalcular favoritos', (tester) async {
        final artwork = _BytesArtworkRepository();
        markAll();
        await pumpFavorites(
          tester,
          overrides: [artworkRepositoryProvider.overrideWithValue(artwork)],
        );
        final before = artwork.requests.length;
        expect(before, 2);

        for (final index in [0, 1, 0]) {
          player.emitState(
            PlaybackState(queue: [tres, dos, uno], currentIndex: index),
          );
          await tester.pumpAndSettle();
        }
        player.emitPosition(const Duration(seconds: 30));
        await tester.pumpAndSettle();
        // Recalcular: se quita una favorita y la lista se reconstruye.
        await favorites.remove(tres.musicIdentity);
        await tester.pumpAndSettle();
        expect(find.text('Tres'), findsNothing);

        expect(artwork.requests.length, before);
      });
    });

    testWidgets('con miles de favoritos solo construye las filas visibles',
        (tester) async {
      final many = [
        for (var i = 0; i < 3000; i++)
          buildSong(id: i, title: 'S${i.toString().padLeft(4, '0')}'),
      ];
      when(library.getSongs).thenAnswer((_) async => many);
      for (final song in many) {
        favorites.seed(favorites.entryFor(song));
      }
      await pumpFavorites(tester);

      // La más reciente arriba; la más antigua no se construye.
      expect(find.text('S2999'), findsOneWidget);
      expect(find.text('S0000'), findsNothing);
      expect(find.byType(TakiSongTile).evaluate().length, lessThan(30));
    });

    group('pantallas', () {
      final long = buildSong(
        id: 1,
        title: 'Un título larguísimo que de ninguna manera cabe en la fila',
        artist: 'Un artista con un nombre también extraordinariamente largo',
        albumId: 11,
        durationMs: 3725000,
      );

      for (final (name, size, scale) in [
        ('360x800', const Size(360, 800), 1.0),
        ('412x915', const Size(412, 915), 1.0),
        ('360x800 con texto al 150 %', const Size(360, 800), 1.5),
        ('412x915 con texto al 150 %', const Size(412, 915), 1.5),
      ]) {
        testWidgets('$name: sin desbordes, filas de al menos 64 y botones '
            'de 48', (tester) async {
          when(library.getSongs).thenAnswer((_) async => [long, dos, tres]);
          favorites
            ..seed(favorites.entryFor(long))
            ..seed(favorites.entryFor(dos))
            ..seed(favorites.entryFor(tres));
          await pumpFavorites(tester, size: size, textScale: scale);

          expect(tester.takeException(), isNull);
          final row = tester.getRect(tileFinder('Dos'));
          expect(row.height, greaterThanOrEqualTo(TakiSongTile.minHeight));
          // El texto crece dentro de la fila, no se sale de ella.
          expect(tester.getRect(find.text('Dos')).bottom,
              lessThanOrEqualTo(row.bottom));
          // Título y artista largos se recortan dentro de la pantalla.
          expect(tester.getRect(find.text(long.title)).right,
              lessThanOrEqualTo(size.width));
          for (final label in ['Reproducir', 'Aleatorio']) {
            final button =
                tester.getRect(find.widgetWithText(TakiButton, label));
            expect(button.height, greaterThanOrEqualTo(48), reason: label);
            expect(button.right, lessThanOrEqualTo(size.width), reason: label);
          }
        });
      }

      for (final scale in [1.0, 1.5]) {
        testWidgets('vacío a 360x800 (texto ×$scale) sin desbordes',
            (tester) async {
          await pumpFavorites(
            tester,
            size: const Size(360, 800),
            textScale: scale,
          );
          expect(tester.takeException(), isNull);
          expect(find.text('Sin favoritos'), findsOneWidget);
        });
      }

      // A escala 1: con la fuente de pruebas el texto de TakiButton no cabe
      // al 150 % (gap de core documentado en 1.7A).
      for (final size in [const Size(360, 800), const Size(412, 915)]) {
        testWidgets('permiso a ${size.width.toInt()} sin desbordes',
            (tester) async {
          when(permission.isGranted).thenAnswer((_) async => false);
          await pumpFavorites(tester, size: size);
          expect(find.text('Permitir acceso'), findsOneWidget);
          expect(tester.takeException(), isNull);
        });

        testWidgets('error a ${size.width.toInt()} sin desbordes',
            (tester) async {
          favorites.failing = true;
          await pumpFavorites(tester, size: size);
          expect(find.text('Favoritos no disponibles'), findsOneWidget);
          expect(tester.takeException(), isNull);
        });
      }
    });
  });

  // La resolución de carátulas la hace AlbumArtworkBuilder (core/artwork); la
  // imagen mostrada (MemoryImage a 48) y "sin peticiones al cambiar de
  // canción, posición ni al recalcular" ya los cubre el grupo anterior.
  group('Artwork compartido (Fase 1.8C)', () {
    // Marcadas en este orden, se ven al revés: Ed, Ec, Eb, Ea.
    final ea = buildSong(id: 21, title: 'Ea', albumId: 11);
    final eb = buildSong(id: 22, title: 'Eb', albumId: 22);
    final ec = buildSong(id: 23, title: 'Ec', albumId: 11);
    final ed = buildSong(id: 24, title: 'Ed', albumId: null);

    AlbumArtworkBuilder builderOf(WidgetTester tester, String title) =>
        tester.widget<AlbumArtworkBuilder>(
          find.ancestor(
            of: find.text(title),
            matching: find.byType(AlbumArtworkBuilder),
          ),
        );

    TakiArtwork artOf(WidgetTester tester, String title) =>
        tester.widget<TakiArtwork>(
          find.descendant(
            of: find.ancestor(
              of: find.text(title),
              matching: find.byType(TakiSongTile),
            ),
            matching: find.byType(TakiArtwork),
          ),
        );

    Future<_BytesArtworkRepository> pumpWith(
      WidgetTester tester, {
      void Function(_BytesArtworkRepository)? configure,
    }) async {
      final artwork = _BytesArtworkRepository();
      configure?.call(artwork);
      when(library.getSongs).thenAnswer((_) async => [ea, eb, ec, ed]);
      favorites
        ..seed(favorites.entryFor(ea))
        ..seed(favorites.entryFor(eb))
        ..seed(favorites.entryFor(ec))
        ..seed(favorites.entryFor(ed));
      await pumpFavorites(
        tester,
        overrides: [artworkRepositoryProvider.overrideWithValue(artwork)],
      );
      return artwork;
    }

    testWidgets('la fila usa song.artwork, no albumId', (tester) async {
      final remote = remoteArtworkSong(title: 'Remota');
      final none = buildSong(
        id: 71,
        title: 'Sin carátula',
        albumId: 88,
        artwork: const UnavailableArtworkReference(),
      );
      when(library.getSongs).thenAnswer((_) async => [remote, none]);
      favorites
        ..seed(favorites.entryFor(remote))
        ..seed(favorites.entryFor(none));
      final artwork = _BytesArtworkRepository();
      await pumpFavorites(
        tester,
        overrides: [artworkRepositoryProvider.overrideWithValue(artwork)],
      );

      expect(builderOf(tester, 'Remota').reference, remoteTestArtwork);
      expect(
        builderOf(tester, 'Sin carátula').reference,
        const UnavailableArtworkReference(),
      );
      expect(artwork.requests, isEmpty);
    });

    testWidgets('cada fila usa AlbumArtworkBuilder con su albumId y el '
        'tamaño de TakiSongTile (48, el que usaba Favoritos)', (tester) async {
      final artwork = await pumpWith(tester);

      expect(find.byType(AlbumArtworkBuilder), findsNWidgets(4));
      expect(
        [
          for (final title in ['Ed', 'Ec', 'Eb', 'Ea'])
            builderOf(tester, title).albumId,
        ],
        [null, 11, 22, 11],
      );
      for (final title in ['Ed', 'Ec', 'Eb', 'Ea']) {
        expect(builderOf(tester, title).size, 48, reason: title);
        expect(builderOf(tester, title).size, TakiSongTile.artworkSize);
      }
      final physical = (48 * tester.view.devicePixelRatio).round();
      expect(artwork.requests.map((r) => r.$2).toSet(), {physical});
    });

    testWidgets('un álbum compartido por varias canciones se pide una sola '
        'vez', (tester) async {
      final artwork = await pumpWith(tester);

      expect(artwork.requests.where((r) => r.$1 == 11), hasLength(1));
      expect(artwork.requests.where((r) => r.$1 == 22), hasLength(1));
      expect(artOf(tester, 'Ea').image, isNotNull);
      expect(artOf(tester, 'Ec').image, isNotNull);
    });

    testWidgets('álbum sin carátula: placeholder, sin romper la lista',
        (tester) async {
      await pumpWith(tester, configure: (r) => r.missing.add(22));

      expect(artOf(tester, 'Eb').image, isNull);
      expect(artOf(tester, 'Ea').image, isNotNull);
      expect(tester.takeException(), isNull);
    });

    testWidgets('error de lectura de una carátula: la fila y la lista '
        'siguen funcionando', (tester) async {
      await pumpWith(tester, configure: (r) => r.failing.add(11));

      expect(artOf(tester, 'Ea').image, isNull);
      expect(artOf(tester, 'Ec').image, isNull);
      expect(artOf(tester, 'Eb').image, isNotNull);
      expect(tester.takeException(), isNull);

      // Reproducir sigue funcionando desde una fila sin carátula.
      await tester.tap(find.text('Ea'));
      await tester.pumpAndSettle();
      verify(() => playSongs([ed, ec, eb, ea], 3)).called(1);
    });
  });
}

/// [FakeFavoritesRepository] cuya lectura puede quedar retenida con [gate],
/// para observar un recálculo en curso.
class _GatedFavoritesRepository extends FakeFavoritesRepository {
  Completer<void>? gate;

  @override
  Future<List<FavoriteEntry>> getFavorites() async {
    final gate = this.gate;
    if (gate != null) await gate.future;
    return super.getFavorites();
  }
}

/// Carátulas de prueba: bytes con el álbum pedido; cuenta las peticiones. Con
/// [missing] el álbum no tiene carátula; con [failing] la lectura falla.
class _BytesArtworkRepository implements ArtworkRepository {
  final requests = <(int, int)>[];
  final missing = <int>{};
  final failing = <int>{};

  @override
  Future<Uint8List?> getAlbumArtwork(int albumId, {required int size}) async {
    requests.add((albumId, size));
    if (failing.contains(albumId)) throw StateError('lectura fallida');
    if (missing.contains(albumId)) return null;
    return Uint8List.fromList([albumId, size]);
  }
}
