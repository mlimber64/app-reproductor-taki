import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:taki/app/theme/app_theme.dart';
import 'package:taki/app/widgets/song_actions_sheet.dart';
import 'package:taki/core/artwork/artwork_providers.dart';
import 'package:taki/core/domain/entities/song.dart';
import 'package:taki/core/domain/ports/artwork_repository.dart';
import 'package:taki/core/theme/taki_colors.dart';
import 'package:taki/core/theme/taki_typography.dart';
import 'package:taki/core/widgets/taki_artwork.dart';
import 'package:taki/core/widgets/taki_button.dart';
import 'package:taki/core/widgets/taki_empty_state.dart';
import 'package:taki/core/widgets/taki_error_state.dart';
import 'package:taki/core/widgets/taki_playing_indicator.dart';
import 'package:taki/core/widgets/taki_song_tile.dart';
import 'package:taki/features/library/presentation/pages/library_page.dart';
import 'package:taki/features/player/domain/entities/playback_state.dart';
import 'package:taki/features/player/presentation/providers/player_providers.dart';

import '../../../helpers/favorites_fakes.dart';
import '../../../helpers/library_fakes.dart';
import '../../../helpers/player_fakes.dart';
import '../../../helpers/playlists_fakes.dart';

void main() {
  late MockMediaPermission permission;
  late MockSongRepository songs;
  late FakeAudioPlayerPort player;
  late FakeNotificationPermission notifications;
  late MockPlaySongs playSongs;
  late MockPlayNext playNext;
  late MockAddToQueue addToQueue;
  late FakeFavoritesRepository favorites;
  late FakePlaylistsRepository playlists;

  setUpAll(() {
    registerFallbackValue(<Song>[]);
  });

  setUp(() {
    permission = MockMediaPermission();
    songs = MockSongRepository();
    player = FakeAudioPlayerPort();
    notifications = FakeNotificationPermission();
    playSongs = MockPlaySongs();
    when(() => playSongs(any(), any())).thenAnswer((_) async {});
    playNext = MockPlayNext();
    when(() => playNext(any())).thenAnswer((_) async {});
    favorites = FakeFavoritesRepository();
    playlists = FakePlaylistsRepository();
    addToQueue = MockAddToQueue();
    when(() => addToQueue(any())).thenAnswer((_) async {});
    when(permission.isGranted).thenAnswer((_) async => true);
    when(permission.isPermanentlyDenied).thenAnswer((_) async => false);
    when(songs.getSongs).thenAnswer((_) async => []);
  });

  Future<void> pumpPage(
    WidgetTester tester, {
    List<Override> overrides = const [],
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
            songs: songs,
            player: player,
            notifications: notifications,
            favorites: favorites,
            playlists: playlists,
          ),
          playSongsProvider.overrideWithValue(playSongs),
          playNextProvider.overrideWithValue(playNext),
          addToQueueProvider.overrideWithValue(addToQueue),
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
          home: const LibraryPage(onSongActions: showSongActions),
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

  group('sin permiso', () {
    setUp(() => when(permission.isGranted).thenAnswer((_) async => false));

    testWidgets('muestra el mensaje y "Permitir acceso"', (tester) async {
      when(permission.request).thenAnswer((_) async => false);

      await pumpPage(tester);

      expect(find.text('Taki necesita acceso a tu música'), findsOneWidget);
      await tester.tap(find.text('Permitir acceso'));
      await tester.pumpAndSettle();

      verify(permission.request).called(1);
      verifyNever(songs.getSongs);
    });

    testWidgets('si se concede, carga las canciones', (tester) async {
      when(permission.request).thenAnswer((_) async {
        when(permission.isGranted).thenAnswer((_) async => true);
        return true;
      });
      when(songs.getSongs).thenAnswer((_) async => [buildSong(title: 'Hola')]);

      await pumpPage(tester);
      await tester.tap(find.text('Permitir acceso'));
      await tester.pumpAndSettle();

      expect(find.text('Hola'), findsOneWidget);
    });

    testWidgets('denegado permanentemente: el botón abre los ajustes',
        (tester) async {
      when(permission.isPermanentlyDenied).thenAnswer((_) async => true);
      when(permission.openSettings).thenAnswer((_) async => true);

      await pumpPage(tester);
      await tester.tap(find.text('Abrir ajustes'));
      await tester.pumpAndSettle();

      verify(permission.openSettings).called(1);
      verifyNever(permission.request);
    });
  });

  testWidgets('vacío: muestra el mensaje y "Reintentar"', (tester) async {
    await pumpPage(tester);

    expect(find.text('No encontramos canciones'), findsOneWidget);
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();

    verify(songs.getSongs).called(2);
  });

  testWidgets('error: muestra el mensaje y "Reintentar"', (tester) async {
    when(songs.getSongs).thenThrow(Exception('MediaStore no disponible'));

    await pumpPage(tester);

    expect(find.text('No pudimos leer tu música'), findsOneWidget);
    expect(find.text('Reintentar'), findsOneWidget);
  });

  testWidgets('con datos: encabezado, filas ordenadas y duraciones',
      (tester) async {
    when(songs.getSongs).thenAnswer(
      (_) async => [
        buildSong(id: 1, title: 'zeta', artist: null, durationMs: 125000),
        buildSong(id: 2, title: 'Alfa', durationMs: 185000),
        buildSong(id: 3, title: 'Tono', durationMs: 4000), // Se descarta.
      ],
    );

    await pumpPage(tester);

    expect(find.text('Tu música'), findsOneWidget);
    expect(find.text('2 canciones · 5 min'), findsOneWidget);
    expect(find.text('Tono'), findsNothing);
    expect(find.text('Artista desconocido'), findsOneWidget);
    expect(find.text('3:05'), findsOneWidget);
    expect(find.text('2:05'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Alfa')).dy,
      lessThan(tester.getTopLeft(find.text('zeta')).dy),
    );
    // Sin carátula se ve el ícono de nota.
    expect(find.byIcon(Icons.music_note_rounded), findsNWidgets(2));
  });

  testWidgets('pull-to-refresh vuelve a escanear', (tester) async {
    when(songs.getSongs).thenAnswer((_) async => [buildSong(title: 'Una')]);

    await pumpPage(tester);
    await tester.fling(find.text('Una'), const Offset(0, 400), 1000);
    await tester.pumpAndSettle();

    verify(songs.getSongs).called(2);
  });

  group('reproducción', () {
    final unsorted = [
      buildSong(id: 1, title: 'zeta'),
      buildSong(id: 2, title: 'Alfa'),
      buildSong(id: 3, title: 'medio'),
    ];

    testWidgets(
        'tocar una canción llama a PlaySongs con la lista visible y su índice',
        (tester) async {
      when(songs.getSongs).thenAnswer((_) async => unsorted);

      await pumpPage(tester);
      await tester.tap(find.text('medio'));
      await tester.pumpAndSettle();

      final captured =
          verify(() => playSongs(captureAny(), captureAny())).captured;
      final queue = captured[0] as List<Song>;
      expect(queue.map((s) => s.title), ['Alfa', 'medio', 'zeta']);
      expect(captured[1], 1);
      expect(notifications.requests, 1);
    });

    testWidgets('la canción actual se marca con el color de acento',
        (tester) async {
      when(songs.getSongs).thenAnswer((_) async => unsorted);

      await pumpPage(tester);
      final sorted = [unsorted[1], unsorted[2], unsorted[0]];
      player.emitState(PlaybackState(queue: sorted, currentIndex: 2));
      await tester.pumpAndSettle();

      Color? titleColor(String title) =>
          tester.widget<Text>(find.text(title)).style?.color;
      final accent = Theme.of(tester.element(find.text('zeta')))
          .colorScheme
          .primary;

      expect(titleColor('zeta'), accent);
      expect(titleColor('Alfa'), isNot(accent));
    });
  });

  group('mantener pulsada una canción', () {
    final songsList = [
      buildSong(id: 1, title: 'Alfa'),
      buildSong(id: 2, title: 'Beta'),
    ];

    Future<void> openSheetFor(WidgetTester tester, String title) async {
      when(songs.getSongs).thenAnswer((_) async => songsList);
      await pumpPage(tester);
      await tester.longPress(find.text(title));
      await tester.pumpAndSettle();
    }

    testWidgets('ofrece las dos opciones', (tester) async {
      await openSheetFor(tester, 'Beta');

      expect(find.text('Reproducir a continuación'), findsOneWidget);
      expect(find.text('Añadir a la cola'), findsOneWidget);
    });

    testWidgets('"Reproducir a continuación" llama a PlayNext con la canción',
        (tester) async {
      player.emitState(
        PlaybackState(queue: [songsList.first], currentIndex: 0),
      );
      await openSheetFor(tester, 'Beta');

      await tester.tap(find.text('Reproducir a continuación'));
      await tester.pumpAndSettle();

      verify(() => playNext([songsList[1]])).called(1);
      verifyNever(() => addToQueue(any()));
      expect(find.text('Sonará a continuación'), findsOneWidget);
    });

    testWidgets('"Añadir a la cola" llama a AddToQueue con la canción',
        (tester) async {
      player.emitState(
        PlaybackState(queue: [songsList.first], currentIndex: 0),
      );
      await openSheetFor(tester, 'Beta');

      await tester.tap(find.text('Añadir a la cola'));
      await tester.pumpAndSettle();

      verify(() => addToQueue([songsList[1]])).called(1);
      verifyNever(() => playNext(any()));
      expect(find.text('Añadida a la cola'), findsOneWidget);
    });

    testWidgets('ofrece "Añadir a favoritos" y la marca', (tester) async {
      await openSheetFor(tester, 'Beta');

      await tester.tap(find.text('Añadir a favoritos'));
      await tester.pumpAndSettle();

      expect(favorites.entries.keys, [2]);
      expect(find.text('Añadida a favoritos'), findsOneWidget);
    });

    testWidgets('si ya es favorita ofrece "Quitar de favoritos"',
        (tester) async {
      favorites.seed(favorites.entryFor(songsList[1]));
      await openSheetFor(tester, 'Beta');

      expect(find.text('Quitar de favoritos'), findsOneWidget);
      expect(find.text('Añadir a favoritos'), findsNothing);

      await tester.tap(find.text('Quitar de favoritos'));
      await tester.pumpAndSettle();

      expect(favorites.entries, isEmpty);
      expect(find.text('Quitada de favoritos'), findsOneWidget);
    });

    testWidgets('"Añadir a una playlist" añade y avisa si ya estaba',
        (tester) async {
      final mix = playlists.seed('Mix');
      await openSheetFor(tester, 'Beta');

      await tester.tap(find.text('Añadir a una playlist'));
      await tester.pumpAndSettle();
      expect(find.text('Nueva playlist'), findsOneWidget);
      await tester.tap(find.text('Mix'));
      await tester.pumpAndSettle();

      expect(playlists.entriesOf(mix).map((e) => e.songId), [2]);
      expect(find.text('Añadida a «Mix»'), findsOneWidget);

      await tester.longPress(find.text('Beta'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Añadir a una playlist'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mix'));
      await tester.pumpAndSettle();

      expect(playlists.entriesOf(mix).map((e) => e.songId), [2, 2]);
      expect(
        find.text('Ya estaba en «Mix»; se añadió otra vez'),
        findsOneWidget,
      );
    });

    testWidgets('"Nueva playlist" desde el selector la crea con la canción',
        (tester) async {
      await openSheetFor(tester, 'Alfa');

      await tester.tap(find.text('Añadir a una playlist'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Nueva playlist'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Recién hecha');
      await tester.pump();
      await tester.tap(find.text('Crear'));
      await tester.pumpAndSettle();

      expect(playlists.namesInOrder(), ['Recién hecha']);
      expect(find.text('Añadida a «Recién hecha»'), findsOneWidget);
    });

    testWidgets('sin nada sonando, avisa que empieza a reproducir',
        (tester) async {
      await openSheetFor(tester, 'Alfa');

      await tester.tap(find.text('Añadir a la cola'));
      await tester.pumpAndSettle();

      verify(() => addToQueue([songsList[0]])).called(1);
      expect(find.text('Reproduciendo «Alfa»'), findsOneWidget);
      expect(notifications.requests, 1);
    });
  });

  group('Design System (Fase 1.7A)', () {
    final list = [
      buildSong(id: 1, title: 'Alfa', albumId: 11),
      buildSong(id: 2, title: 'Beta', albumId: 22),
      buildSong(id: 3, title: 'Gamma', albumId: null),
    ];

    TakiSongTile tileOf(WidgetTester tester, String title) =>
        tester.widget<TakiSongTile>(
          find.ancestor(of: find.text(title), matching: find.byType(TakiSongTile)),
        );

    testWidgets('cada canción es una TakiSongTile con duración, sin ⋯ ni '
        'favorito (como antes)', (tester) async {
      when(songs.getSongs).thenAnswer((_) async => list);
      await pumpPage(tester);

      expect(find.byType(TakiSongTile), findsNWidgets(3));
      for (final title in ['Alfa', 'Beta', 'Gamma']) {
        final tile = tileOf(tester, title);
        expect(tile.showDuration, isTrue, reason: title);
        expect(tile.onMore, isNull, reason: title);
        expect(tile.isFavorite, isFalse, reason: title);
        expect(tile.onTap, isNotNull, reason: title);
        expect(tile.onLongPress, isNotNull, reason: title);
      }
      expect(find.byTooltip('Más opciones'), findsNothing);
    });

    testWidgets('la actual: sonando con barras; en pausa, barras quietas',
        (tester) async {
      when(songs.getSongs).thenAnswer((_) async => list);
      await pumpPage(tester);

      player.emitState(
        PlaybackState(queue: list, currentIndex: 1, isPlaying: true),
      );
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(tileOf(tester, 'Beta').playback, TakiNowPlaying.playing);
      expect(tileOf(tester, 'Alfa').playback, TakiNowPlaying.none);
      expect(tileOf(tester, 'Gamma').playback, TakiNowPlaying.none);
      final bars = find.byType(TakiPlayingIndicator);
      expect(bars, findsOneWidget);
      expect(
        find.descendant(
          of: find.ancestor(
            of: find.text('Beta'),
            matching: find.byType(TakiSongTile),
          ),
          matching: bars,
        ),
        findsOneWidget,
      );
      expect(tester.widget<TakiPlayingIndicator>(bars).animate, isTrue);

      player.emitState(PlaybackState(queue: list, currentIndex: 1));
      await tester.pumpAndSettle();
      expect(tileOf(tester, 'Beta').playback, TakiNowPlaying.paused);
      expect(
        tester.widget<TakiPlayingIndicator>(find.byType(TakiPlayingIndicator))
            .animate,
        isFalse,
      );
    });

    testWidgets('semántica: título, artista, duración y estado',
        (tester) async {
      final handle = tester.ensureSemantics();
      when(songs.getSongs).thenAnswer((_) async => list);
      await pumpPage(tester);
      player.emitState(PlaybackState(queue: list, currentIndex: 0));
      await tester.pumpAndSettle();

      final alfa = find.ancestor(
        of: find.text('Alfa'),
        matching: find.byType(TakiSongTile),
      );
      expect(
        tester.getSemantics(alfa),
        isSemantics(
          label: 'Alfa, Artista, 3:00',
          value: TakiSongTile.pausedLabel,
          isButton: true,
          hasTapAction: true,
          hasLongPressAction: true,
        ),
      );
      expect(
        tester.getSemantics(find.bySemanticsLabel('Tu música')),
        isSemantics(isHeader: true),
      );
      handle.dispose();
    });

    testWidgets('carátulas desde ArtworkCache (bytes → MemoryImage) a 48',
        (tester) async {
      final artwork = _BytesArtworkRepository();
      when(songs.getSongs).thenAnswer((_) async => list);
      await pumpPage(
        tester,
        overrides: [artworkRepositoryProvider.overrideWithValue(artwork)],
      );

      TakiArtwork artOf(String title) => tester.widget<TakiArtwork>(
            find.descendant(
              of: find.ancestor(
                of: find.text(title),
                matching: find.byType(TakiSongTile),
              ),
              matching: find.byType(TakiArtwork),
            ),
          );

      expect(artOf('Alfa').size, TakiSongTile.artworkSize);
      expect((artOf('Alfa').image! as MemoryImage).bytes.first, 11);
      expect((artOf('Beta').image! as MemoryImage).bytes.first, 22);
      // Sin álbum: placeholder y ninguna petición.
      expect(artOf('Gamma').image, isNull);
      expect(artwork.requests.map((r) => r.$1).toSet(), {11, 22});
    });

    testWidgets('las carátulas no se vuelven a pedir al cambiar de canción',
        (tester) async {
      final artwork = _BytesArtworkRepository();
      when(songs.getSongs).thenAnswer((_) async => list);
      await pumpPage(
        tester,
        overrides: [artworkRepositoryProvider.overrideWithValue(artwork)],
      );
      final before = artwork.requests.length;

      for (final index in [0, 1, 0]) {
        player.emitState(PlaybackState(queue: list, currentIndex: index));
        await tester.pumpAndSettle();
      }
      player.emitPosition(const Duration(seconds: 30));
      await tester.pumpAndSettle();

      expect(artwork.requests.length, before);
    });

    testWidgets('cabecera: "Tu música" en headline y resumen en trackSubtitle',
        (tester) async {
      when(songs.getSongs).thenAnswer((_) async => list);
      await pumpPage(tester);

      final title = tester.widget<Text>(find.text('Tu música')).style!;
      expect(title.fontFamily, TakiTypography.headline.fontFamily);
      expect(title.fontSize, TakiTypography.headline.fontSize);
      expect(title.color, TakiColors.textPrimary);
      final summary =
          tester.widget<Text>(find.text('3 canciones · 9 min')).style!;
      expect(summary.fontSize, TakiTypography.trackSubtitle.fontSize);
      expect(summary.color, TakiColors.textSecondary);
    });

    testWidgets('sin permiso: TakiErrorState de permiso', (tester) async {
      when(permission.isGranted).thenAnswer((_) async => false);
      await pumpPage(tester);

      final state = tester.widget<TakiErrorState>(find.byType(TakiErrorState));
      expect(state.kind, TakiErrorStateKind.permission);
      expect(state.action!.label, 'Permitir acceso');
      expect(find.byType(RefreshIndicator), findsNothing);
      expect(
        tester.getSize(find.widgetWithText(TakiButton, 'Permitir acceso')).height,
        greaterThanOrEqualTo(48),
      );
    });

    testWidgets('vacío: TakiEmptyState de primer uso; pull-to-refresh',
        (tester) async {
      await pumpPage(tester);

      final state = tester.widget<TakiEmptyState>(find.byType(TakiEmptyState));
      expect(state.kind, TakiEmptyStateKind.firstUse);
      expect(state.icon, Icons.music_off_rounded);
      expect(find.textContaining('Los audios de menos de'), findsOneWidget);

      await tester.fling(
        find.text('No encontramos canciones'),
        const Offset(0, 400),
        1000,
      );
      await tester.pumpAndSettle();
      verify(songs.getSongs).called(2);
    });

    testWidgets('error: TakiErrorState de error; Reintentar vuelve a cargar',
        (tester) async {
      when(songs.getSongs).thenThrow(Exception('MediaStore no disponible'));
      await pumpPage(tester);

      final state = tester.widget<TakiErrorState>(find.byType(TakiErrorState));
      expect(state.kind, TakiErrorStateKind.error);

      when(songs.getSongs).thenAnswer((_) async => list);
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();
      expect(find.text('Alfa'), findsOneWidget);
    });

    testWidgets('error: pull-to-refresh vuelve a escanear', (tester) async {
      when(songs.getSongs).thenThrow(Exception('MediaStore no disponible'));
      await pumpPage(tester);

      await tester.fling(
        find.text('No pudimos leer tu música'),
        const Offset(0, 400),
        1000,
      );
      await tester.pumpAndSettle();
      verify(songs.getSongs).called(2);
    });

    testWidgets('con miles de canciones solo construye las visibles',
        (tester) async {
      final many = [
        for (var i = 0; i < 5000; i++)
          buildSong(id: i, title: 'S${i.toString().padLeft(4, '0')}'),
      ];
      when(songs.getSongs).thenAnswer((_) async => many);
      await pumpPage(tester);

      expect(find.text('S0000'), findsOneWidget);
      expect(find.text('S4999'), findsNothing);
      expect(find.byType(TakiSongTile).evaluate().length, lessThan(30));
    });

    group('pantallas', () {
      final long = [
        buildSong(
          id: 1,
          title: 'Un título larguísimo que de ninguna manera cabe en la fila',
          artist: 'Un artista con un nombre también extraordinariamente largo',
          durationMs: 3725000,
        ),
        ...list.skip(1),
      ];

      for (final (name, size, scale) in [
        ('360x800', const Size(360, 800), 1.0),
        ('412x915', const Size(412, 915), 1.0),
        ('360x800 con texto al 150 %', const Size(360, 800), 1.5),
      ]) {
        testWidgets('$name: sin desbordes y filas de al menos 64',
            (tester) async {
          when(songs.getSongs).thenAnswer((_) async => long);
          await pumpPage(tester, size: size, textScale: scale);

          expect(tester.takeException(), isNull);
          final row = find.ancestor(
            of: find.text('Beta'),
            matching: find.byType(TakiSongTile),
          );
          final rect = tester.getRect(row);
          expect(rect.height, greaterThanOrEqualTo(TakiSongTile.minHeight));
          // El texto crece dentro de la fila, no se sale de ella.
          expect(tester.getRect(find.text('Beta')).bottom,
              lessThanOrEqualTo(rect.bottom));
        });
      }

      // A escala 1: con la fuente de pruebas (cada letra tan ancha como alta)
      // el texto de TakiButton no cabe al 150 % (gap de core documentado).
      testWidgets('estado de permiso a 360x800 sin desbordes', (tester) async {
        when(permission.isGranted).thenAnswer((_) async => false);
        await pumpPage(tester, size: const Size(360, 800));
        expect(tester.takeException(), isNull);
      });
    });
  });
}

/// Carátulas de prueba: bytes con el álbum pedido; cuenta las peticiones.
class _BytesArtworkRepository implements ArtworkRepository {
  final requests = <(int, int)>[];

  @override
  Future<Uint8List?> getAlbumArtwork(int albumId, {required int size}) async {
    requests.add((albumId, size));
    return Uint8List.fromList([albumId, size]);
  }
}
