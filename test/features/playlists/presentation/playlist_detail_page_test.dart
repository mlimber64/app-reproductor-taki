import 'dart:async';
import 'package:taki/core/domain/entities/local_song.dart';
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
import 'package:taki/core/theme/taki_elevation.dart';
import 'package:taki/core/theme/taki_radius.dart';
import 'package:taki/core/theme/taki_typography.dart';
import 'package:taki/core/widgets/taki_artwork.dart';
import 'package:taki/core/widgets/taki_button.dart';
import 'package:taki/core/widgets/taki_empty_state.dart';
import 'package:taki/core/widgets/taki_error_state.dart';
import 'package:taki/core/widgets/taki_playing_indicator.dart';
import 'package:taki/core/widgets/taki_song_tile.dart';
import 'package:taki/features/player/domain/entities/playback_state.dart';
import 'package:taki/features/player/presentation/providers/player_providers.dart';
import 'package:taki/features/playlists/presentation/pages/playlist_detail_page.dart';
import 'package:taki/features/playlists/presentation/providers/playlists_providers.dart';
import 'package:taki/core/domain/entities/local_music_identity.dart';


import '../../../helpers/library_fakes.dart';
import '../../../helpers/player_fakes.dart';
import '../../../helpers/playlists_fakes.dart';
import '../../../helpers/artwork_image.dart';

void main() {
  late _GatedPlaylistsRepository playlists;
  late MockSongRepository library;
  late MockPlaySongs playSongs;
  late MockPlaySongsShuffled playShuffled;
  late MockMediaPermission permission;
  late FakeAudioPlayerPort player;
  late FakeNotificationPermission notifications;

  final a = buildSong(id: 1, title: 'A', durationMs: 60000);
  final b = buildSong(id: 2, title: 'B', durationMs: 120000);
  final c = buildSong(id: 3, title: 'C', durationMs: 180000);
  final d = buildSong(id: 4, title: 'D', durationMs: 240000);
  final missing = buildSong(id: 9, title: 'Borrada', durationMs: 1000);

  setUpAll(() {
    registerFallbackValue(<Song>[]);
  });

  setUp(() {
    playlists = _GatedPlaylistsRepository();
    library = MockSongRepository();
    when(library.getSongs).thenAnswer((_) async => [a, b, c, d]);
    playSongs = MockPlaySongs();
    when(() => playSongs(any(), any())).thenAnswer((_) async {});
    playShuffled = MockPlaySongsShuffled();
    when(() => playShuffled(any())).thenAnswer((_) async {});
    permission = MockMediaPermission();
    when(permission.isGranted).thenAnswer((_) async => true);
    when(permission.isPermanentlyDenied).thenAnswer((_) async => false);
    player = FakeAudioPlayerPort();
    notifications = FakeNotificationPermission();
  });

  /// Abre el detalle de [playlistId] sobre una página base.
  Future<void> openDetail(
    WidgetTester tester,
    int playlistId, {
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
            songs: library,
            player: player,
            notifications: notifications,
            playlists: playlists,
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
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => PlaylistDetailPage(
                      playlistId: playlistId,
                      onSongActions: showSongActions,
                    ),
                  ),
                ),
                child: const Text('Base'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Base'));
    // Con una canción sonando las barras se animan sin fin.
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
    }
  }

  Finder moreButtonOf(String title) => find.descendant(
        of: find.ancestor(of: find.text(title), matching: find.byType(Row))
            .first,
        matching: find.byTooltip('Más opciones'),
      );

  List<int> storedSongIds(int id) =>
      [for (final e in playlists.entriesOf(id)) int.parse(e.musicIdentity.externalId)];

  testWidgets('encabezado y canciones en orden; oculta las ausentes',
      (tester) async {
    final id = playlists.seed('Mi mix', songs: [c, missing, a]);
    await openDetail(tester, id);

    expect(find.text('PLAYLIST'), findsOneWidget);
    expect(find.text('Mi mix'), findsOneWidget);
    expect(find.text('2 canciones · 4 min · 1 no disponibles'), findsOneWidget);
    expect(find.text('Borrada'), findsNothing);
    expect(
      tester.getTopLeft(find.text('C')).dy,
      lessThan(tester.getTopLeft(find.text('A')).dy),
    );
    expect(storedSongIds(id), [3, 9, 1], reason: 'la ausente no se borra');
  });

  testWidgets('Reproducir y tocar una canción usan la lista visible',
      (tester) async {
    final id = playlists.seed('Mi mix', songs: [c, missing, a]);
    await openDetail(tester, id);

    await tester.tap(find.text('Reproducir'));
    await tester.pumpAndSettle();
    verify(() => playSongs([c, a], 0)).called(1);

    await tester.tap(find.text('A'));
    await tester.pumpAndSettle();
    verify(() => playSongs([c, a], 1)).called(1);
  });

  testWidgets('quitar y Deshacer', (tester) async {
    final id = playlists.seed('Mi mix', songs: [a, b, c]);
    await openDetail(tester, id);

    await tester.tap(moreButtonOf('B'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Quitar de la playlist'));
    await tester.pumpAndSettle();

    expect(storedSongIds(id), [1, 3]);
    expect(find.text('B'), findsNothing);
    expect(find.text('Quitada de la playlist'), findsOneWidget);

    await tester.tap(find.text('Deshacer'));
    await tester.pumpAndSettle();

    expect(storedSongIds(id), [1, 2, 3]);
    expect(find.text('B'), findsOneWidget);
  });

  testWidgets('reordenar traduce a las posiciones reales de la playlist',
      (tester) async {
    // Visible: A (pos 0), C (pos 2), D (pos 3); la borrada ocupa la pos 1.
    final id = playlists.seed('Mi mix', songs: [a, missing, c, d]);
    final move = MockMovePlaylistSong();
    when(() => move(any(), any(), any())).thenAnswer((_) async {});
    await openDetail(
      tester,
      id,
      overrides: [movePlaylistSongProvider.overrideWithValue(move)],
    );

    final list = tester.widget<ReorderableListView>(
      find.byType(ReorderableListView),
    );
    // A (fila 0) soltada después de C (fila 1): Flutter informa (0, 2).
    list.onReorder(0, 2);
    await tester.pump();
    verify(() => move(id, 0, 2)).called(1);

    // D (fila 2) soltada al principio: pasa a la posición de A.
    list.onReorder(2, 0);
    await tester.pump();
    verify(() => move(id, 3, 0)).called(1);
  });

  testWidgets('arrastrar el asa reordena la playlist guardada',
      (tester) async {
    final id = playlists.seed('Mi mix', songs: [a, b, c]);
    await openDetail(tester, id);

    final handle = find.descendant(
      of: find.ancestor(of: find.text('A'), matching: find.byType(Row)).first,
      matching: find.byIcon(Icons.drag_handle_rounded),
    );
    final gesture = await tester.startGesture(tester.getCenter(handle));
    await tester.pump(const Duration(milliseconds: 100));
    // Una fila (64 px) y un poco más: A queda después de B.
    for (var i = 0; i < 6; i++) {
      await gesture.moveBy(const Offset(0, 12));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await tester.pumpAndSettle();

    expect(storedSongIds(id), [2, 1, 3]);
  });

  testWidgets('añadir a otra playlist desde el menú de una canción',
      (tester) async {
    final id = playlists.seed('Mi mix', songs: [a]);
    playlists.seed('Otra', songs: [a]);
    final otra = id + 1;
    await openDetail(tester, id);

    await tester.tap(moreButtonOf('A'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Añadir a una playlist'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Otra'));
    await tester.pumpAndSettle();

    expect(storedSongIds(otra), [1, 1]);
    expect(
      find.text('Ya estaba en «Otra»; se añadió otra vez'),
      findsOneWidget,
    );
  });

  testWidgets('eliminar desde el menú del encabezado vuelve atrás',
      (tester) async {
    final id = playlists.seed('Mi mix', songs: [a]);
    await openDetail(tester, id);

    await tester.tap(find.byTooltip('Opciones de la playlist'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Eliminar playlist'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Eliminar'));
    await tester.pumpAndSettle();

    expect(playlists.namesInOrder(), isEmpty);
    expect(find.byType(PlaylistDetailPage), findsNothing);
    expect(find.text('Playlist eliminada'), findsOneWidget);
  });

  testWidgets('estado vacío', (tester) async {
    final id = playlists.seed('Nueva');
    await openDetail(tester, id);

    expect(
      find.text('Esta playlist está vacía. Añade canciones desde la '
          'Biblioteca.'),
      findsOneWidget,
    );
    // Adaptado de FilledButton (PlayShuffleButtons) a TakiButton.
    expect(
      tester.widget<TakiButton>(find.byType(TakiButton).first).onPressed,
      isNull,
    );
  });

  testWidgets('base no disponible: error y Reintentar', (tester) async {
    final id = playlists.seed('Mi mix', songs: [a]);
    playlists.failing = true;
    await openDetail(tester, id);

    expect(find.text('Playlist no disponible'), findsOneWidget);

    playlists.failing = false;
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(find.text('Mi mix'), findsOneWidget);
  });

  group('Design System (Fase 1.7C-2)', () {
    final s11 = buildSong(id: 11, title: 's11', albumId: 11, durationMs: 60000);
    final s22 = buildSong(id: 22, title: 's22', albumId: 22, durationMs: 60000);
    final s33 = buildSong(id: 33, title: 's33', albumId: 33, durationMs: 60000);
    final s44 = buildSong(id: 44, title: 's44', albumId: 44, durationMs: 60000);
    final noAlbum = buildSong(id: 50, title: 'sin álbum', albumId: null);
    final withArt = [s11, s22, s33, s44, noAlbum];

    Finder tileFinder(String title) => find
        .ancestor(of: find.text(title), matching: find.byType(TakiSongTile))
        .first;

    TakiSongTile tileOf(WidgetTester tester, String title) =>
        tester.widget<TakiSongTile>(tileFinder(title));

    List<String> visibleTitles(WidgetTester tester) => [
          for (final tile
              in tester.widgetList<TakiSongTile>(find.byType(TakiSongTile)))
            tile.song.title,
        ];

    TakiArtwork coverOf(WidgetTester tester) => tester.widget<TakiArtwork>(
          find.byWidgetPredicate(
            (w) => w is TakiArtwork && w.mosaic != null,
          ),
        );

    List<int?> coverBytes(WidgetTester tester) => [
          for (final image in coverOf(tester).mosaic!)
            firstByteOf(image),
        ];

    Finder loadingSpinner() => find.byWidgetPredicate(
          (w) => w.runtimeType == CircularProgressIndicator,
        );

    Future<void> pumpFrames(WidgetTester tester) async {
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    group('cabecera', () {
      testWidgets('portada TakiArtwork.mosaic de 128: 4 álbumes distintos',
          (tester) async {
        when(library.getSongs).thenAnswer((_) async => withArt);
        final id = playlists.seed('Mix', songs: [s11, s22, s33, s44]);
        await openDetail(
          tester,
          id,
          overrides: [
            artworkRepositoryProvider
                .overrideWithValue(_BytesArtworkRepository()),
          ],
        );

        final cover = coverOf(tester);
        expect(cover.size, 128);
        expect(cover.kind, TakiArtworkKind.playlist);
        expect(coverBytes(tester), [11, 22, 33, 44]);
      });

      testWidgets('portada con álbumes repetidos: distintos, en orden',
          (tester) async {
        when(library.getSongs).thenAnswer((_) async => withArt);
        final id = playlists.seed('Mix', songs: [s22, s11, s22, noAlbum]);
        await openDetail(
          tester,
          id,
          overrides: [
            artworkRepositoryProvider
                .overrideWithValue(_BytesArtworkRepository()),
          ],
        );

        // Menos de 4: TakiArtwork.mosaic muestra solo la primera (22), así que
        // solo esa se resuelve.
        expect(coverBytes(tester), [22]);
      });

      testWidgets('portada vacía: mosaico sin imágenes', (tester) async {
        final empty = playlists.seed('Vacía');
        await openDetail(tester, empty);
        expect(coverOf(tester).mosaic, isEmpty);
      });

      testWidgets('portada con canciones sin carátula: una pieza sin imagen',
          (tester) async {
        when(library.getSongs).thenAnswer((_) async => withArt);
        final noArt = playlists.seed('Sin arte', songs: [noAlbum]);
        await openDetail(tester, noArt);
        expect(coverOf(tester).mosaic, [null]);
      });

      testWidgets('tipografía: eyebrow, nombre en headline (encabezado) y '
          'resumen', (tester) async {
        final handle = tester.ensureSemantics();
        final id = playlists.seed('Mi mix', songs: [a, b]);
        await openDetail(tester, id);

        final eyebrow = tester.widget<Text>(find.text('PLAYLIST')).style!;
        expect(eyebrow.fontSize, TakiTypography.eyebrow.fontSize);
        expect(eyebrow.color, TakiColors.textMuted);
        final name = tester.widget<Text>(find.text('Mi mix'));
        expect(name.style!.fontSize, TakiTypography.headline.fontSize);
        expect(name.maxLines, 2);
        expect(
          tester.getSemantics(find.text('Mi mix')),
          isSemantics(isHeader: true),
        );
        final summary =
            tester.widget<Text>(find.text('2 canciones · 3 min')).style!;
        expect(summary.color, TakiColors.textSecondary);
        handle.dispose();
      });

      testWidgets('Reproducir primario y Aleatorio secundario, de 48, con '
          'semántica de botón', (tester) async {
        final handle = tester.ensureSemantics();
        final id = playlists.seed('Mi mix', songs: [a, b]);
        await openDetail(tester, id);

        final play = find.widgetWithText(TakiButton, 'Reproducir');
        final shuffle = find.widgetWithText(TakiButton, 'Aleatorio');
        expect(tester.widget<TakiButton>(play).variant,
            TakiButtonVariant.primary);
        expect(tester.widget<TakiButton>(shuffle).variant,
            TakiButtonVariant.secondary);
        for (final button in [play, shuffle]) {
          expect(tester.getSize(button).height, greaterThanOrEqualTo(48));
        }
        expect(
          tester.getSemantics(play),
          isSemantics(label: 'Reproducir', isButton: true, isEnabled: true),
        );
        expect(
          tester.getSemantics(shuffle),
          isSemantics(label: 'Aleatorio', isButton: true, isEnabled: true),
        );
        handle.dispose();
      });

      testWidgets('Aleatorio llama a PlaySongsShuffled con la lista visible '
          'y pide el permiso de notificaciones', (tester) async {
        final id = playlists.seed('Mi mix', songs: [c, missing, a]);
        await openDetail(tester, id);

        await tester.tap(find.widgetWithText(TakiButton, 'Aleatorio'));
        await tester.pumpAndSettle();

        verify(() => playShuffled([c, a])).called(1);
        verifyNever(() => playSongs(any(), any()));
        expect(notifications.requests, 1);
      });

      testWidgets('vacía: ambos botones deshabilitados', (tester) async {
        final handle = tester.ensureSemantics();
        final id = playlists.seed('Nueva');
        await openDetail(tester, id);

        for (final label in ['Reproducir', 'Aleatorio']) {
          final button = find.widgetWithText(TakiButton, label);
          expect(tester.widget<TakiButton>(button).onPressed, isNull);
          expect(
            tester.getSemantics(button),
            isSemantics(label: label, isButton: true, isEnabled: false),
          );
        }
        await tester.tap(find.text('Reproducir'));
        await tester.pumpAndSettle();
        verifyNever(() => playSongs(any(), any()));
        handle.dispose();
      });

      testWidgets('renombrar desde el menú del encabezado', (tester) async {
        final id = playlists.seed('Vieja', songs: [a]);
        await openDetail(tester, id);

        await tester.tap(find.byTooltip('Opciones de la playlist'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Renombrar'));
        await tester.pumpAndSettle();
        expect(
          tester.widget<TextField>(find.byType(TextField)).controller!.text,
          'Vieja',
        );
        await tester.enterText(find.byType(TextField), 'Nueva');
        await tester.tap(find.text('Guardar'));
        await tester.pumpAndSettle();

        expect(playlists.namesInOrder(), ['Nueva']);
        expect(find.text('Nueva'), findsOneWidget);
      });
    });

    group('filas', () {
      testWidgets('TakiSongTile con duración, ⋯ y asa; sin corazón',
          (tester) async {
        final id = playlists.seed('Mi mix', songs: [a, b]);
        await openDetail(tester, id);

        expect(find.byType(TakiSongTile), findsNWidgets(2));
        for (final title in ['A', 'B']) {
          final tile = tileOf(tester, title);
          expect(tile.showDuration, isTrue, reason: title);
          expect(tile.onMore, isNotNull, reason: title);
          expect(tile.onTap, isNotNull, reason: title);
          expect(tile.onLongPress, isNotNull, reason: title);
          expect(tile.isFavorite, isFalse, reason: title);
          expect(tile.available, isTrue, reason: title);
          expect(tile.trailing, isA<ReorderableDragStartListener>());
        }
        expect(find.text('1:00'), findsOneWidget);
        expect(find.text('2:00'), findsOneWidget);
      });

      testWidgets('cada fila lleva ValueKey(entry.id), también con '
          'duplicados', (tester) async {
        final id = playlists.seed('Mi mix', songs: [a, b, a]);
        await openDetail(tester, id);

        final entries = playlists.entriesOf(id);
        expect(entries.map((e) => e.musicIdentity), [1, 2, 1].map(localMusicIdentity));
        for (final entry in entries) {
          expect(find.byKey(ValueKey(entry.id)), findsOneWidget);
        }
        expect(visibleTitles(tester), ['A', 'B', 'A']);
      });

      testWidgets('duplicados: tocar la segunda aparición reproduce desde '
          'su índice', (tester) async {
        final id = playlists.seed('Mi mix', songs: [a, b, a]);
        await openDetail(tester, id);

        await tester.tap(find.text('A').last);
        await tester.pumpAndSettle();

        verify(() => playSongs([a, b, a], 2)).called(1);
        expect(notifications.requests, 1);
      });

      testWidgets('duplicados: quitar una aparición quita solo esa entrada',
          (tester) async {
        final id = playlists.seed('Mi mix', songs: [a, b, a]);
        await openDetail(tester, id);
        final last = playlists.entriesOf(id).last.id;

        await tester.longPress(find.text('A').last);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Quitar de la playlist'));
        await tester.pumpAndSettle();

        expect(storedSongIds(id), [1, 2]);
        expect(find.byKey(ValueKey(last)), findsNothing);
        expect(visibleTitles(tester), ['A', 'B']);
      });

      testWidgets('la pulsación larga abre las acciones con "Quitar de la '
          'playlist"', (tester) async {
        final id = playlists.seed('Mi mix', songs: [a, b]);
        await openDetail(tester, id);

        await tester.longPress(find.text('B'));
        await tester.pumpAndSettle();

        expect(find.text('Quitar de la playlist'), findsOneWidget);
        expect(find.text('Reproducir a continuación'), findsOneWidget);
        expect(find.text('Añadir a la cola'), findsOneWidget);
        verifyNever(() => playSongs(any(), any()));
      });

      testWidgets('la actual se identifica por identidad, no por Song.id',
          (tester) async {
        // Ambas tienen id 0: solo la identidad las distingue.
        final uno = buildSong(id: 31, title: 'Foráneo 1');
        final dos = buildSong(id: 32, title: 'Foráneo 2');
        when(library.getSongs).thenAnswer((_) async => [uno, dos]);
        final id = playlists.seed('Mix', songs: [uno, dos]);
        await openDetail(tester, id);

        player.emitState(
          PlaybackState(queue: [uno, dos], currentIndex: 1, isPlaying: true),
        );
        await pumpFrames(tester);

        expect(tileOf(tester, 'Foráneo 2').playback, TakiNowPlaying.playing);
        expect(tileOf(tester, 'Foráneo 1').playback, TakiNowPlaying.none);
      });

      testWidgets('canción actual sonando: barras animadas y título en '
          'acento; en pausa: barras quietas', (tester) async {
        final id = playlists.seed('Mi mix', songs: [a, b, c]);
        await openDetail(tester, id);

        player.emitState(
          PlaybackState(queue: [a, b, c], currentIndex: 1, isPlaying: true),
        );
        await pumpFrames(tester);
        expect(tileOf(tester, 'B').playback, TakiNowPlaying.playing);
        expect(tileOf(tester, 'A').playback, TakiNowPlaying.none);
        final bars = find.byType(TakiPlayingIndicator);
        expect(bars, findsOneWidget);
        expect(
          find.descendant(of: tileFinder('B'), matching: bars),
          findsOneWidget,
        );
        expect(tester.widget<TakiPlayingIndicator>(bars).animate, isTrue);
        expect(
          tester.widget<Text>(find.text('B')).style?.color,
          TakiColors.active,
        );

        player.emitState(PlaybackState(queue: [a, b, c], currentIndex: 1));
        await tester.pumpAndSettle();
        expect(tileOf(tester, 'B').playback, TakiNowPlaying.paused);
        expect(
          tester
              .widget<TakiPlayingIndicator>(find.byType(TakiPlayingIndicator))
              .animate,
          isFalse,
        );
      });

      testWidgets('canción actual duplicada: se marcan sus apariciones '
          '(como antes, por id de canción)', (tester) async {
        final id = playlists.seed('Mi mix', songs: [a, b, a]);
        await openDetail(tester, id);

        player.emitState(PlaybackState(queue: [a], currentIndex: 0));
        await tester.pumpAndSettle();

        final states = [
          for (final tile
              in tester.widgetList<TakiSongTile>(find.byType(TakiSongTile)))
            tile.playback,
        ];
        expect(states, [
          TakiNowPlaying.paused,
          TakiNowPlaying.none,
          TakiNowPlaying.paused,
        ]);
      });

      testWidgets('semántica de la fila, ⋯ y asa; áreas de 48',
          (tester) async {
        final handle = tester.ensureSemantics();
        final id = playlists.seed('Mi mix', songs: [a, b]);
        await openDetail(tester, id);
        player.emitState(
          PlaybackState(queue: [a, b], currentIndex: 0, isPlaying: true),
        );
        await pumpFrames(tester);

        expect(
          tester.getSemantics(tileFinder('A')),
          isSemantics(
            label: 'A, Artista, 1:00',
            value: TakiSongTile.playingLabel,
            isButton: true,
            hasTapAction: true,
            hasLongPressAction: true,
          ),
        );
        final more = moreButtonOf('A');
        expect(
          tester.getSemantics(more),
          isSemantics(
            label: TakiSongTile.moreLabel,
            isButton: true,
            hasTapAction: true,
          ),
        );
        expect(tester.getSize(more).height, greaterThanOrEqualTo(48));
        final dragHandle = find.descendant(
          of: tileFinder('A'),
          matching: find.byTooltip('Arrastrar para reordenar'),
        );
        expect(dragHandle, findsOneWidget);
        final handleSize = tester.getSize(dragHandle);
        expect(handleSize.width, greaterThanOrEqualTo(48));
        expect(handleSize.height, greaterThanOrEqualTo(48));
        expect(
          tester.getRect(dragHandle).left,
          greaterThanOrEqualTo(tester.getRect(more).right),
          reason: 'el asa no se solapa con ⋯',
        );
        handle.dispose();
      });

      testWidgets('las carátulas de las filas: bytes → MemoryImage a 48; no '
          'se vuelven a pedir al cambiar de canción; al reordenar solo se '
          'pide la portada del álbum que pasa a ser el primero',
          (tester) async {
        final artwork = _BytesArtworkRepository();
        when(library.getSongs).thenAnswer((_) async => withArt);
        final id = playlists.seed('Mix', songs: [s11, s22, noAlbum]);
        await openDetail(
          tester,
          id,
          overrides: [artworkRepositoryProvider.overrideWithValue(artwork)],
        );

        TakiArtwork rowArt(String title) => tester.widget<TakiArtwork>(
              find.descendant(
                of: tileFinder(title),
                matching: find.byType(TakiArtwork),
              ),
            );
        expect(rowArt('s11').size, TakiSongTile.artworkSize);
        expect(memoryImageOf(rowArt('s11').image!).bytes.first, 11);
        expect(rowArt('sin álbum').image, isNull);
        final before = artwork.requests.length;

        for (final index in [0, 1, 0]) {
          player.emitState(
            PlaybackState(queue: [s11, s22], currentIndex: index),
          );
          await tester.pumpAndSettle();
        }
        player.emitPosition(const Duration(seconds: 30));
        await tester.pumpAndSettle();
        tester
            .widget<ReorderableListView>(find.byType(ReorderableListView))
            .onReorder(0, 2);
        await tester.pumpAndSettle();

        expect(visibleTitles(tester), ['s22', 's11', 'sin álbum']);
        // La portada con menos de 4 álbumes muestra la primera: al pasar s22 a
        // primera se pide su carátula a 128 (una sola petición nueva). Las
        // filas (48) no se repiten.
        expect(artwork.requests.length, before + 1);
        expect(
          artwork.requests.last,
          (22, (128 * tester.view.devicePixelRatio).round()),
        );
        expect(coverBytes(tester), [22]);
      });
    });

    // La selección de álbumes es playlistCoverAlbumIds (con sus propios tests);
    // aquí se comprueba cómo la usa el detalle: las 4 primeras canciones
    // *visibles* (no `coverSongIds`) y qué se pide a la caché.
    group('portada: builders, fuente y tamaños (Fase 1.8G)', () {
      final s11b = buildSong(id: 12, title: 's11b', albumId: 11);
      // No están en la biblioteca: entradas guardadas ausentes.
      final ghost1 = buildSong(id: 91, title: 'ausente 1', albumId: 91);
      final ghost2 = buildSong(id: 92, title: 'ausente 2', albumId: 92);
      final allSongs = [...withArt, s11b];

      // Lado lógico de la portada y de cada tesela del 2×2, en píxeles.
      int full(WidgetTester tester) =>
          (128 * tester.view.devicePixelRatio).round();
      int tile(WidgetTester tester) =>
          (64 * tester.view.devicePixelRatio).round();

      /// Peticiones de la portada (128 y 64 lógicos); las filas piden a 48.
      List<(int, int)> coverRequests(
        _BytesArtworkRepository artwork,
        WidgetTester tester,
      ) =>
          [
            for (final r in artwork.requests)
              if (r.$2 == full(tester) || r.$2 == tile(tester)) r,
          ];

      /// Builders de la portada: los de 128 (las filas usan 48).
      List<AlbumArtworkBuilder> headerBuilders(WidgetTester tester) => [
            for (final b in tester
                .widgetList<AlbumArtworkBuilder>(
                    find.byType(AlbumArtworkBuilder)))
              if (b.size == 128) b,
          ];

      Future<_BytesArtworkRepository> open(
        WidgetTester tester,
        List<Song> songs, {
        void Function(_BytesArtworkRepository)? configure,
      }) async {
        final artwork = _BytesArtworkRepository();
        configure?.call(artwork);
        when(library.getSongs).thenAnswer((_) async => allSongs);
        final id = playlists.seed('Mix', songs: songs);
        await openDetail(
          tester,
          id,
          overrides: [artworkRepositoryProvider.overrideWithValue(artwork)],
        );
        return artwork;
      }

      testWidgets('cada fila usa AlbumArtworkBuilder con su albumId y el '
          'tamaño de TakiSongTile (48, el que usaba el detalle)',
          (tester) async {
        final artwork = await open(tester, [s11, s22, noAlbum]);

        final rows = [
          for (final b in tester.widgetList<AlbumArtworkBuilder>(
              find.byType(AlbumArtworkBuilder)))
            if (b.size != 128) b,
        ];
        expect(rows.map((b) => b.albumId), [11, 22, null]);
        for (final b in rows) {
          expect(b.size, 48);
          expect(b.size, TakiSongTile.artworkSize);
        }
        final physical = (48 * tester.view.devicePixelRatio).round();
        final rowRequests = [
          for (final r in artwork.requests)
            if (r.$2 == physical) r,
        ];
        expect(rowRequests, [(11, physical), (22, physical)]);
      });

      testWidgets('la fila y la portada usan song.artwork, no albumId',
          (tester) async {
        final remote = remoteArtworkSong();
        when(library.getSongs).thenAnswer((_) async => [remote]);
        final id = playlists.seed('Mix', songs: [remote]);
        final artwork = _BytesArtworkRepository();
        await openDetail(
          tester,
          id,
          overrides: [artworkRepositoryProvider.overrideWithValue(artwork)],
        );

        final builders = tester
            .widgetList<AlbumArtworkBuilder>(find.byType(AlbumArtworkBuilder))
            .toList();
        expect(builders, hasLength(2)); // portada del encabezado + fila
        expect(
          builders.map((b) => b.reference),
          everyElement(remoteTestArtwork),
        );
        // El albumId 77 nunca se pide a MediaStore.
        expect(artwork.requests, isEmpty);
      });

      testWidgets('0 canciones: placeholder con borde y ninguna petición',
          (tester) async {
        final artwork = await open(tester, const []);

        expect(coverOf(tester).mosaic, isEmpty);
        expect(find.byType(AlbumArtworkBuilder), findsNothing);
        expect(find.byType(AlbumArtworkMosaicBuilder), findsNothing);
        expect(artwork.requests, isEmpty);
      });

      testWidgets('1 álbum: imagen individual a 128', (tester) async {
        final artwork = await open(tester, [s11, s11b]);

        final header = headerBuilders(tester);
        expect(header, hasLength(1));
        expect(header.single.albumId, 11);
        expect(header.single.size, 128);
        expect(find.byType(AlbumArtworkMosaicBuilder), findsNothing);
        expect(coverBytes(tester), [11]);
        expect(coverRequests(artwork, tester), [(11, full(tester))]);
      });

      for (final (name, songs, first) in [
        ('2 álbumes', [s22, s11], 22),
        ('3 álbumes', [s33, s11, s22], 33),
      ]) {
        testWidgets('$name: solo la primera imagen, a tamaño completo',
            (tester) async {
          final artwork = await open(tester, songs);

          expect(headerBuilders(tester).single.albumId, first);
          expect(find.byType(AlbumArtworkMosaicBuilder), findsNothing);
          expect(coverBytes(tester), [first]);
          expect(coverRequests(artwork, tester), [(first, full(tester))]);
        });
      }

      testWidgets('4 álbumes: mosaico con cada tesela a la mitad del lado',
          (tester) async {
        final artwork = await open(tester, [s11, s22, s33, s44]);

        final mosaic = tester.widget<AlbumArtworkMosaicBuilder>(
          find.byType(AlbumArtworkMosaicBuilder),
        );
        expect(mosaic.albumIds, [11, 22, 33, 44]);
        expect(mosaic.size, 128);
        expect(headerBuilders(tester), isEmpty);
        expect(coverBytes(tester), [11, 22, 33, 44]);
        final requests = coverRequests(artwork, tester);
        expect(requests.map((r) => r.$2).toSet(), {tile(tester)});
        expect(requests.map((r) => r.$1).toSet(), {11, 22, 33, 44});
        expect(tile(tester), lessThan(full(tester)));
      });

      testWidgets('[A, A, B, C, D] da [A, B, C]: un álbum visible y el 4.º '
          'no se pide', (tester) async {
        final artwork = await open(tester, [s11, s11b, s22, s33, s44]);

        // Primeras 4 canciones: 11, 11, 22, 33 → [11, 22, 33] (<4).
        expect(coverBytes(tester), [11]);
        expect(coverRequests(artwork, tester), [(11, full(tester))]);
        expect(find.byType(AlbumArtworkMosaicBuilder), findsNothing);
      });

      testWidgets('solo cuentan las 4 primeras canciones visibles: la 5.ª no '
          'completa el mosaico', (tester) async {
        final artwork = await open(tester, [s11, s22, s33, noAlbum, s44]);

        // items.take(4) = 11, 22, 33, sin álbum → [11, 22, 33] → primera.
        expect(coverBytes(tester), [11]);
        expect(coverRequests(artwork, tester), [(11, full(tester))]);
        expect(find.byType(AlbumArtworkMosaicBuilder), findsNothing);
      });

      testWidgets('las ausentes de la biblioteca no cuentan: se usan las 4 '
          'primeras visibles (a diferencia de la lista)', (tester) async {
        await open(tester, [ghost1, s11, ghost2, s22, s33, s44]);

        // Visibles: 11, 22, 33, 44 → mosaico completo. La lista, con
        // coverSongIds (entradas guardadas), vería [null, 11, null, 22].
        expect(find.byType(AlbumArtworkMosaicBuilder), findsOneWidget);
        expect(coverBytes(tester), [11, 22, 33, 44]);
      });

      testWidgets('todas ausentes: no hay canciones visibles, portada vacía',
          (tester) async {
        final artwork = await open(tester, [ghost1, ghost2]);

        expect(find.text('Sin canciones'), findsOneWidget);
        expect(coverOf(tester).mosaic, isEmpty);
        expect(find.byType(AlbumArtworkBuilder), findsNothing);
        expect(artwork.requests, isEmpty);
      });

      testWidgets('canciones sin álbum: una pieza sin imagen y ninguna '
          'petición de portada', (tester) async {
        final artwork = await open(tester, [noAlbum]);

        expect(coverOf(tester).mosaic, [null]);
        final header = headerBuilders(tester);
        expect(header, hasLength(1));
        expect(header.single.albumId, isNull);
        expect(coverRequests(artwork, tester), isEmpty);
      });

      testWidgets('artwork ausente de un álbum: pieza sin imagen y la '
          'pantalla sigue', (tester) async {
        await open(tester, [s11], configure: (r) => r.missing.add(11));

        expect(coverOf(tester).mosaic, [null]);
        expect(find.text('s11'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('error de lectura en un mosaico: una pieza sin imagen y '
          'las filas siguen funcionando', (tester) async {
        await open(
          tester,
          [s11, s22, s33, s44],
          configure: (r) => r.failing.add(22),
        );

        expect(coverBytes(tester), [11, null, 33, 44]);
        expect(tester.takeException(), isNull);

        await tester.tap(find.text('s33'));
        await tester.pumpAndSettle();
        verify(() => playSongs([s11, s22, s33, s44], 2)).called(1);
      });

      testWidgets('quitar la primera canción actualiza la portada y Deshacer '
          'la restaura', (tester) async {
        await open(tester, [s11, s22]);
        expect(coverBytes(tester), [11]);

        await tester.tap(moreButtonOf('s11'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Quitar de la playlist'));
        await tester.pumpAndSettle();
        expect(coverBytes(tester), [22]);

        await tester.tap(find.text('Deshacer'));
        await tester.pumpAndSettle();
        expect(coverBytes(tester), [11]);
      });

      testWidgets('reordenar la primera canción cambia la portada',
          (tester) async {
        await open(tester, [s11, s22, s33]);
        expect(coverBytes(tester), [11]);

        tester
            .widget<ReorderableListView>(find.byType(ReorderableListView))
            .onReorder(0, 2);
        await tester.pumpAndSettle();

        expect(visibleTitles(tester), ['s22', 's11', 's33']);
        expect(coverBytes(tester), [22]);
      });
    });

    group('reordenar y quitar (optimista)', () {
      testWidgets('reordenar se ve al instante, antes de que la base '
          'termine; al emitir, manda la base', (tester) async {
        final id = playlists.seed('Mi mix', songs: [a, b, c]);
        await openDetail(tester, id);

        final gate = playlists.moveGate = Completer<void>();
        tester
            .widget<ReorderableListView>(find.byType(ReorderableListView))
            .onReorder(0, 2);
        await tester.pump();

        expect(visibleTitles(tester), ['B', 'A', 'C']);
        expect(storedSongIds(id), [1, 2, 3], reason: 'aún sin guardar');

        gate.complete();
        await tester.pumpAndSettle();
        expect(storedSongIds(id), [2, 1, 3]);
        expect(visibleTitles(tester), ['B', 'A', 'C']);

        // El estado optimista se limpió: un cambio posterior de la base se
        // ve tal cual.
        await playlists.addSongs(id, [d]);
        await tester.pumpAndSettle();
        expect(visibleTitles(tester), ['B', 'A', 'C', 'D']);
      });

      testWidgets('reordenar con ausentes: la fila visible va a la posición '
          'real', (tester) async {
        final id = playlists.seed('Mi mix', songs: [a, missing, c, d]);
        await openDetail(tester, id);

        // D (fila 2) al principio: toma la posición real de A (0).
        tester
            .widget<ReorderableListView>(find.byType(ReorderableListView))
            .onReorder(2, 0);
        await tester.pumpAndSettle();

        expect(storedSongIds(id), [4, 1, 9, 3]);
        expect(visibleTitles(tester), ['D', 'A', 'C']);
      });

      testWidgets('quitar oculta la fila al instante y Deshacer la devuelve '
          'a su posición', (tester) async {
        final id = playlists.seed('Mi mix', songs: [a, b, c]);
        await openDetail(tester, id);

        final gate = playlists.removeGate = Completer<void>();
        await tester.tap(moreButtonOf('B'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Quitar de la playlist'));
        await tester.pump();
        await tester.pump();

        expect(visibleTitles(tester), ['A', 'C']);
        expect(storedSongIds(id), [1, 2, 3], reason: 'aún sin guardar');

        gate.complete();
        await tester.pumpAndSettle();
        expect(storedSongIds(id), [1, 3]);
        expect(find.text('Quitada de la playlist'), findsOneWidget);

        await tester.tap(find.text('Deshacer'));
        await tester.pumpAndSettle();
        expect(storedSongIds(id), [1, 2, 3]);
        expect(visibleTitles(tester), ['A', 'B', 'C']);
      });

      testWidgets('la fila arrastrada flota: surfaceElevated con radio md, '
          'sin sombra', (tester) async {
        final id = playlists.seed('Mi mix', songs: [a, b, c]);
        await openDetail(tester, id);

        final handle = find.descendant(
          of: tileFinder('A'),
          matching: find.byIcon(Icons.drag_handle_rounded),
        );
        final gesture = await tester.startGesture(tester.getCenter(handle));
        await tester.pump(const Duration(milliseconds: 100));
        await gesture.moveBy(const Offset(0, 20));
        await tester.pump(const Duration(milliseconds: 16));

        final proxy = find.byWidgetPredicate(
          (w) =>
              w is Material &&
              w.color == TakiElevation.floating.surface &&
              w.borderRadius == TakiRadius.mdAll,
        );
        expect(proxy, findsOneWidget);
        expect(tester.widget<Material>(proxy).elevation, 0);

        await gesture.up();
        await tester.pumpAndSettle();
      });
    });

    group('estados', () {
      testWidgets('vacía: TakiEmptyState sin acción, bajo la cabecera; '
          'conserva pull-to-refresh', (tester) async {
        final id = playlists.seed('Nueva');
        await openDetail(tester, id);

        final state =
            tester.widget<TakiEmptyState>(find.byType(TakiEmptyState));
        expect(state.icon, Icons.playlist_add_rounded);
        expect(state.action, isNull);
        expect(state.secondaryAction, isNull);
        expect(find.byType(TakiButton), findsNWidgets(2),
            reason: 'solo Reproducir y Aleatorio');
        expect(
          tester.getTopLeft(find.byType(TakiEmptyState)).dy,
          greaterThan(tester.getTopLeft(find.text('Nueva')).dy),
        );
        expect(find.byType(RefreshIndicator), findsOneWidget);

        await tester.fling(
          find.text('Sin canciones'),
          const Offset(0, 400),
          1000,
        );
        await tester.pumpAndSettle();
        verify(library.getSongs).called(2);
      });

      testWidgets('con datos: pull-to-refresh vuelve a escanear',
          (tester) async {
        final id = playlists.seed('Mi mix', songs: [a, b]);
        await openDetail(tester, id);

        await tester.fling(find.text('Mi mix'), const Offset(0, 400), 1000);
        await tester.pumpAndSettle();
        verify(library.getSongs).called(2);
      });

      testWidgets('error: TakiErrorState, sin pull-to-refresh; Reintentar',
          (tester) async {
        final id = playlists.seed('Mi mix', songs: [a]);
        playlists.failing = true;
        await openDetail(tester, id);

        final state =
            tester.widget<TakiErrorState>(find.byType(TakiErrorState));
        expect(state.kind, TakiErrorStateKind.error);
        expect(state.title, 'Playlist no disponible');
        expect(state.message, 'No pudimos leer esta playlist.');
        expect(state.action!.label, 'Reintentar');
        expect(find.byType(RefreshIndicator), findsNothing);
        expect(
          tester.getSize(find.widgetWithText(TakiButton, 'Reintentar')).height,
          greaterThanOrEqualTo(48),
        );
      });

      testWidgets('error de la biblioteca: mismo estado; Reintentar vuelve '
          'a escanear', (tester) async {
        final id = playlists.seed('Mi mix', songs: [a]);
        when(library.getSongs).thenThrow(Exception('MediaStore'));
        await openDetail(tester, id);

        expect(find.text('Playlist no disponible'), findsOneWidget);

        when(library.getSongs).thenAnswer((_) async => [a]);
        await tester.tap(find.text('Reintentar'));
        await tester.pumpAndSettle();
        expect(find.text('A'), findsOneWidget);
      });

      testWidgets('sin permiso: TakiErrorState de permiso, sin '
          'pull-to-refresh; "Permitir acceso" lo pide', (tester) async {
        final handle = tester.ensureSemantics();
        when(permission.isGranted).thenAnswer((_) async => false);
        when(permission.request).thenAnswer((_) async => false);
        final id = playlists.seed('Mi mix', songs: [a]);
        await openDetail(tester, id);

        final state =
            tester.widget<TakiErrorState>(find.byType(TakiErrorState));
        expect(state.kind, TakiErrorStateKind.permission);
        expect(state.title, 'Taki necesita acceso a tu música');
        expect(
          state.message,
          'Las playlists se muestran a partir de las canciones de tu '
          'teléfono.',
        );
        expect(find.byType(RefreshIndicator), findsNothing);
        expect(
          tester.getSemantics(find.text('Taki necesita acceso a tu música')),
          isSemantics(isHeader: true),
        );

        await tester.tap(find.text('Permitir acceso'));
        await tester.pumpAndSettle();
        verify(permission.request).called(1);
        handle.dispose();
      });

      testWidgets('permiso denegado para siempre: "Abrir ajustes"',
          (tester) async {
        when(permission.isGranted).thenAnswer((_) async => false);
        when(permission.isPermanentlyDenied).thenAnswer((_) async => true);
        when(permission.openSettings).thenAnswer((_) async => true);
        final id = playlists.seed('Mi mix', songs: [a]);
        await openDetail(tester, id);

        await tester.tap(find.text('Abrir ajustes'));
        await tester.pumpAndSettle();
        verify(permission.openSettings).called(1);
        verifyNever(permission.request);
      });

      testWidgets('playlist inexistente: estado neutro sin acción ni '
          'pull-to-refresh', (tester) async {
        await openDetail(tester, 999);

        final state =
            tester.widget<TakiEmptyState>(find.byType(TakiEmptyState));
        expect(state.title, 'Esta playlist ya no existe');
        expect(state.description, 'Puede que se haya eliminado.');
        expect(state.icon, Icons.playlist_remove_rounded);
        expect(state.action, isNull);
        expect(find.byType(TakiButton), findsNothing);
        expect(find.byType(RefreshIndicator), findsNothing);
        expect(find.byTooltip('Opciones de la playlist'), findsNothing);
      });

      testWidgets('borrada desde otro lugar: vuelve atrás', (tester) async {
        final id = playlists.seed('Mi mix', songs: [a]);
        await openDetail(tester, id);

        await playlists.delete(id);
        await tester.pumpAndSettle();

        expect(find.byType(PlaylistDetailPage), findsNothing);
        expect(find.text('Base'), findsOneWidget);
      });

      testWidgets('carga: spinner hasta tener las canciones', (tester) async {
        final pending = Completer<List<LocalSong>>();
        when(library.getSongs).thenAnswer((_) => pending.future);
        final id = playlists.seed('Mi mix', songs: [a]);
        await openDetail(tester, id, settle: false);

        expect(loadingSpinner(), findsOneWidget);
        pending.complete([a]);
        await tester.pumpAndSettle();
        expect(loadingSpinner(), findsNothing);
        expect(find.text('A'), findsOneWidget);
      });
    });

    testWidgets('con cientos de canciones solo construye las filas visibles',
        (tester) async {
      final many = [
        for (var i = 0; i < 600; i++)
          buildSong(id: 1000 + i, title: 'S${i.toString().padLeft(3, '0')}'),
      ];
      when(library.getSongs).thenAnswer((_) async => many);
      final id = playlists.seed('Larga', songs: many);
      await openDetail(tester, id);

      expect(find.text('S000'), findsOneWidget);
      expect(find.text('S599'), findsNothing);
      expect(find.byType(TakiSongTile).evaluate().length, lessThan(30));
    });

    group('pantallas', () {
      const longName = 'Una playlist con un nombre larguísimo que de ninguna '
          'manera cabe en dos líneas de la cabecera';
      final longSong = buildSong(
        id: 70,
        title: 'Un título larguísimo que de ninguna manera cabe en la fila',
        artist: 'Un artista con un nombre también extraordinariamente largo',
        durationMs: 3725000,
      );

      for (final (name, size, scale) in [
        ('360x800', const Size(360, 800), 1.0),
        ('412x915', const Size(412, 915), 1.0),
        ('360x800 con texto al 150 %', const Size(360, 800), 1.5),
        ('412x915 con texto al 150 %', const Size(412, 915), 1.5),
      ]) {
        testWidgets('$name: sin desbordes; nombre, resumen y fila largos',
            (tester) async {
          final songs = [
            longSong,
            for (var i = 0; i < 120; i++)
              buildSong(id: 200 + i, title: 'L$i', durationMs: 3600000),
          ];
          when(library.getSongs).thenAnswer((_) async => songs);
          final id = playlists.seed(longName, songs: songs);
          await openDetail(tester, id, size: size, textScale: scale);

          expect(tester.takeException(), isNull);
          expect(
            tester.getRect(find.text(longName)).right,
            lessThanOrEqualTo(size.width),
          );
          for (final label in ['Reproducir', 'Aleatorio']) {
            final rect =
                tester.getRect(find.widgetWithText(TakiButton, label));
            expect(rect.right, lessThanOrEqualTo(size.width), reason: label);
            expect(rect.height, greaterThanOrEqualTo(48), reason: label);
          }
          final row = tester.getRect(tileFinder(longSong.title));
          expect(row.height, greaterThanOrEqualTo(TakiSongTile.minHeight));
          expect(tester.getRect(find.text(longSong.title)).bottom,
              lessThanOrEqualTo(row.bottom));
        });
      }

      for (final (name, size, scale) in [
        ('vacía a 360x800', const Size(360, 800), 1.0),
        ('vacía a 360x800 con texto al 150 %', const Size(360, 800), 1.5),
        ('vacía a 412x915', const Size(412, 915), 1.0),
      ]) {
        testWidgets('$name sin desbordes', (tester) async {
          final id = playlists.seed('Nueva');
          await openDetail(tester, id, size: size, textScale: scale);
          expect(tester.takeException(), isNull);
          expect(find.byType(TakiEmptyState), findsOneWidget);
        });
      }

      // A escala 1: con la fuente de pruebas el texto de TakiButton no cabe
      // al 150 % en los estados (gap de core documentado en 1.7A).
      for (final size in [const Size(360, 800), const Size(412, 915)]) {
        final width = size.width.toInt();

        testWidgets('permiso a $width sin desbordes', (tester) async {
          final id = playlists.seed('Mi mix', songs: [a]);
          when(permission.isGranted).thenAnswer((_) async => false);
          await openDetail(tester, id, size: size);
          expect(find.byType(TakiErrorState), findsOneWidget);
          expect(tester.takeException(), isNull);
        });

        testWidgets('error a $width sin desbordes', (tester) async {
          final id = playlists.seed('Mi mix', songs: [a]);
          playlists.failing = true;
          await openDetail(tester, id, size: size);
          expect(find.byType(TakiErrorState), findsOneWidget);
          expect(tester.takeException(), isNull);
        });

        testWidgets('inexistente a $width sin desbordes', (tester) async {
          await openDetail(tester, 999, size: size);
          expect(find.byType(TakiEmptyState), findsOneWidget);
          expect(tester.takeException(), isNull);
        });
      }
    });
  });
}

/// [FakePlaylistsRepository] cuyas escrituras de mover y quitar pueden
/// quedar retenidas, para observar el estado optimista.
class _GatedPlaylistsRepository extends FakePlaylistsRepository {
  Completer<void>? moveGate;
  Completer<void>? removeGate;

  @override
  Future<void> move(int playlistId, int oldIndex, int newIndex) async {
    final gate = moveGate;
    if (gate != null) await gate.future;
    return super.move(playlistId, oldIndex, newIndex);
  }

  @override
  Future<void> removeEntry(int entryId) async {
    final gate = removeGate;
    if (gate != null) await gate.future;
    return super.removeEntry(entryId);
  }
}

/// Carátulas de prueba: bytes con el álbum pedido; cuenta las peticiones.
class _BytesArtworkRepository implements ArtworkRepository {
  final requests = <(int, int)>[];

  /// Álbumes sin carátula y álbumes cuya lectura falla.
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
