import 'dart:typed_data';

import '../../../helpers/artwork_reference_ext.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:taki/app/app.dart';
import 'package:taki/core/artwork/album_artwork_builder.dart';
import 'package:taki/core/artwork/artwork_providers.dart';
import 'package:taki/core/domain/ports/artwork_repository.dart';
import 'package:taki/core/theme/taki_colors.dart';
import 'package:taki/core/widgets/taki_artwork.dart';
import 'package:taki/core/widgets/taki_icon_button.dart';
import 'package:taki/core/widgets/taki_mini_player.dart';
import 'package:taki/features/player/domain/entities/playback_state.dart';
import 'package:taki/features/player/presentation/pages/now_playing_page.dart';
import 'package:taki/features/player/presentation/providers/player_providers.dart';
import 'package:taki/features/player/presentation/widgets/mini_player.dart';

import '../../../helpers/library_fakes.dart';
import '../../../helpers/player_fakes.dart';
import '../../../helpers/artwork_image.dart';

/// Carátulas de prueba: bytes con el álbum y el tamaño pedidos. Con [missing]
/// el álbum no tiene carátula; con [failing] la lectura falla.
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

void main() {
  late FakeAudioPlayerPort player;
  late MockTogglePlayPause togglePlayPause;

  final song = buildSong(
    title: 'Canción de prueba',
    artist: 'Artista de prueba',
    durationMs: 200000,
  );

  setUp(() {
    player = FakeAudioPlayerPort();
    togglePlayPause = MockTogglePlayPause();
    when(() => togglePlayPause()).thenAnswer((_) async {});
  });

  Future<void> pumpApp(
    WidgetTester tester, {
    List<Override> overrides = const [],
    bool mockToggle = true,
    Size? size,
  }) async {
    if (size != null) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
    }
    final permission = MockMediaPermission();
    when(permission.isGranted).thenAnswer((_) async => true);
    final songs = MockSongRepository();
    when(songs.getSongs).thenAnswer((_) async => []);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...libraryOverrides(
            permission: permission,
            songs: songs,
            player: player,
          ),
          if (mockToggle)
            togglePlayPauseProvider.overrideWithValue(togglePlayPause),
          ...overrides,
        ],
        child: const TakiApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> startSong(
    WidgetTester tester, {
    bool isPlaying = false,
    PlaybackState? state,
  }) async {
    player.emitState(
      state ??
          PlaybackState(queue: [song], currentIndex: 0, isPlaying: isPlaying),
    );
    await tester.pumpAndSettle();
  }

  TakiMiniPlayer miniPlayer(WidgetTester tester) =>
      tester.widget<TakiMiniPlayer>(find.byType(TakiMiniPlayer));

  testWidgets('sin canción actual no ocupa espacio', (tester) async {
    await pumpApp(tester);

    expect(tester.getSize(find.byType(MiniPlayer)).height, 0);
    expect(find.byType(TakiMiniPlayer), findsNothing);
    expect(find.text('Canción de prueba'), findsNothing);
  });

  testWidgets('con canción muestra título y artista', (tester) async {
    await pumpApp(tester);
    await startSong(tester);

    expect(find.text('Canción de prueba'), findsOneWidget);
    expect(find.text('Artista de prueba'), findsOneWidget);
    expect(tester.getSize(find.byType(MiniPlayer)).height, greaterThan(0));
  });

  testWidgets('desaparece si deja de haber canción', (tester) async {
    await pumpApp(tester);
    await startSong(tester);

    player.emitState(PlaybackState.empty);
    await tester.pumpAndSettle();

    expect(find.byType(TakiMiniPlayer), findsNothing);
    expect(tester.getSize(find.byType(MiniPlayer)).height, 0);
  });

  testWidgets('el botón llama a TogglePlayPause y refleja el estado',
      (tester) async {
    await pumpApp(tester);
    await startSong(tester);

    await tester.tap(find.byTooltip('Reproducir'));
    verify(() => togglePlayPause()).called(1);

    await startSong(tester, isPlaying: true);
    expect(find.byTooltip('Pausar'), findsOneWidget);
    expect(find.byIcon(Icons.pause_rounded), findsOneWidget);
  });

  testWidgets('play/pausa real: reproduce y pausa el reproductor',
      (tester) async {
    await pumpApp(tester, mockToggle: false);
    await startSong(tester);

    await tester.tap(find.byTooltip('Reproducir'));
    await tester.pumpAndSettle();
    expect(player.calls.last, 'play');
    expect(miniPlayer(tester).isPlaying, isTrue);

    await tester.tap(find.byTooltip('Pausar'));
    await tester.pumpAndSettle();
    expect(player.calls.last, 'pause');
    expect(miniPlayer(tester).isPlaying, isFalse);
  });

  testWidgets('el botón tiene un área táctil de al menos 48', (tester) async {
    await pumpApp(tester);
    await startSong(tester);

    final size = tester.getSize(
      find.ancestor(
        of: find.byTooltip('Reproducir'),
        matching: find.byType(TakiIconButton),
      ),
    );
    expect(size.width, greaterThanOrEqualTo(48));
    expect(size.height, greaterThanOrEqualTo(48));
  });

  testWidgets('la barra de progreso sigue la posición', (tester) async {
    await pumpApp(tester);
    await startSong(tester);

    player.emitPosition(const Duration(seconds: 50));
    await tester.pump();
    await tester.pump();

    expect(miniPlayer(tester).progress, closeTo(0.25, 0.001));
    final bar = tester.widget<FractionallySizedBox>(
      find.descendant(
        of: find.byType(MiniPlayer),
        matching: find.byType(FractionallySizedBox),
      ),
    );
    expect(bar.widthFactor, closeTo(0.25, 0.001));
  });

  testWidgets('progreso: sin duración, 0; pasada la duración, 1',
      (tester) async {
    await pumpApp(tester);
    await startSong(
      tester,
      state: PlaybackState(
        queue: [buildSong(durationMs: 0)],
        currentIndex: 0,
      ),
    );
    player.emitPosition(const Duration(seconds: 30));
    await tester.pump();
    await tester.pump();
    expect(miniPlayer(tester).progress, 0);

    await startSong(tester);
    player.emitPosition(const Duration(minutes: 9));
    await tester.pump();
    await tester.pump();
    expect(miniPlayer(tester).progress, 1);
  });

  testWidgets('la barra es decorativa: 2 px, sin seek', (tester) async {
    await pumpApp(tester);
    await startSong(tester);

    expect(
      find.descendant(
        of: find.byType(MiniPlayer),
        matching: find.byType(Slider),
      ),
      findsNothing,
    );
    final track = find.ancestor(
      of: find.descendant(
        of: find.byType(MiniPlayer),
        matching: find.byType(FractionallySizedBox),
      ),
      matching: find.byType(SizedBox),
    );
    expect(tester.getSize(track.first).height, TakiMiniPlayer.progressHeight);

    // Tocar el borde inferior abre Reproduciendo, no busca.
    final rect = tester.getRect(find.byType(TakiMiniPlayer));
    await tester.tapAt(Offset(rect.center.dx, rect.bottom - 1));
    await tester.pumpAndSettle();
    expect(player.calls.where((c) => c.startsWith('seek')), isEmpty);
  });

  testWidgets('tocar el cuerpo abre Reproduciendo', (tester) async {
    await pumpApp(tester);
    await startSong(tester);

    await tester.tap(find.text('Canción de prueba'));
    await tester.pumpAndSettle();

    expect(find.byType(NowPlayingPage), findsOneWidget);
    expect(find.text('REPRODUCIENDO DESDE'), findsOneWidget);
  });

  testWidgets('deslizar hacia arriba abre Reproduciendo', (tester) async {
    await pumpApp(tester);
    await startSong(tester);

    await tester.fling(
      find.text('Canción de prueba'),
      const Offset(0, -200),
      1000,
    );
    await tester.pumpAndSettle();

    expect(find.byType(NowPlayingPage), findsOneWidget);
  });

  testWidgets('al volver de Reproduciendo sigue ahí', (tester) async {
    await pumpApp(tester);
    await startSong(tester);

    await tester.tap(find.text('Canción de prueba'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Cerrar'));
    await tester.pumpAndSettle();

    expect(find.byType(NowPlayingPage), findsNothing);
    expect(find.byType(TakiMiniPlayer), findsOneWidget);
  });

  testWidgets('sigue visible al cambiar de pestaña', (tester) async {
    await pumpApp(tester);
    await startSong(tester);

    for (final tab in ['Playlists', 'Favoritos', 'Ajustes']) {
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text(tab),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Canción de prueba'), findsOneWidget, reason: tab);
    }
  });

  group('Design System (Fase 1.6E)', () {
    testWidgets('usa TakiMiniPlayer; sin siguiente ni favorito (como antes)',
        (tester) async {
      await pumpApp(tester, size: const Size(412, 915));
      await startSong(tester);

      final mini = miniPlayer(tester);
      expect(mini.song, song);
      expect(mini.onNext, isNull);
      expect(mini.onToggleFavorite, isNull);
      expect(find.byTooltip('Siguiente'), findsNothing);
      expect(
        find.descendant(
          of: find.byType(TakiMiniPlayer),
          matching: find.byIcon(Icons.favorite_border_rounded),
        ),
        findsNothing,
      );
    });

    testWidgets('play/pausa blanco (inverse), no naranja', (tester) async {
      await pumpApp(tester);
      await startSong(tester);

      final button = tester.widget<TakiIconButton>(
        find.ancestor(
          of: find.byTooltip('Reproducir'),
          matching: find.byType(TakiIconButton),
        ),
      );
      expect(button.variant, TakiIconButtonVariant.inverse);
    });

    testWidgets('carátula desde ArtworkCache (bytes → MemoryImage) a 48',
        (tester) async {
      final artwork = _BytesArtworkRepository();
      await pumpApp(
        tester,
        overrides: [artworkRepositoryProvider.overrideWithValue(artwork)],
      );
      await startSong(tester);

      final art = tester.widget<TakiArtwork>(
        find.descendant(
          of: find.byType(TakiMiniPlayer),
          matching: find.byType(TakiArtwork),
        ),
      );
      expect(art.size, TakiMiniPlayer.artworkSize);
      expect(memoryImageOf(art.image!).bytes.first, song.albumId);
      // 48 lógicos a la densidad de la pantalla.
      final pixels =
          (TakiMiniPlayer.artworkSize * tester.view.devicePixelRatio).round();
      expect(artwork.requests, [(song.albumId, pixels)]);
    });

    testWidgets('sin carátula: placeholder', (tester) async {
      await pumpApp(tester);
      await startSong(tester);

      expect(miniPlayer(tester).artwork, isNull);
    });

    testWidgets('la carátula no se vuelve a pedir con cada posición',
        (tester) async {
      final artwork = _BytesArtworkRepository();
      await pumpApp(
        tester,
        overrides: [artworkRepositoryProvider.overrideWithValue(artwork)],
      );
      await startSong(tester);
      final before = artwork.requests.length;

      for (var s = 1; s <= 5; s++) {
        player.emitPosition(Duration(seconds: s));
        await tester.pump();
      }
      expect(artwork.requests.length, before);
    });

    testWidgets('semántica: canción, estado y cómo abrir', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpApp(tester);
      await startSong(tester, isPlaying: true);

      expect(
        tester.getSemantics(find.byType(TakiMiniPlayer)),
        isSemantics(
          label: 'Canción de prueba, Artista de prueba',
          value: TakiMiniPlayer.playingLabel,
          isButton: true,
          hasTapAction: true,
        ),
      );
      expect(
        tester.getSemantics(find.bySemanticsLabel(TakiMiniPlayer.pauseLabel)),
        isSemantics(isButton: true, hasTapAction: true),
      );
      handle.dispose();
    });

    testWidgets('fondo surfaceElevated, márgenes de 8', (tester) async {
      await pumpApp(tester, size: const Size(412, 915));
      await startSong(tester);

      final rect = tester.getRect(find.byType(TakiMiniPlayer));
      expect(rect.left, 8);
      expect(rect.right, 412 - 8);
      expect(rect.height, TakiMiniPlayer.height);
      final navTop = tester.getRect(find.byType(NavigationBar)).top;
      expect(navTop - rect.bottom, 8);
      final box = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(TakiMiniPlayer),
              matching: find.byType(Container),
            )
            .first,
      );
      expect(box.color, TakiColors.surfaceElevated);
    });
  });

  group('pantallas', () {
    final long = buildSong(
      title: 'Un título larguísimo que de ninguna manera cabe en el mini player',
      artist: 'Un artista con un nombre también extraordinariamente largo',
    );

    for (final size in [const Size(360, 800), const Size(412, 915)]) {
      testWidgets('${size.width.toInt()}x${size.height.toInt()}: sin '
          'desbordes, sobre la navegación', (tester) async {
        await pumpApp(tester, size: size);
        await startSong(
          tester,
          state: PlaybackState(queue: [long], currentIndex: 0),
        );

        expect(tester.takeException(), isNull);
        final mini = tester.getRect(find.byType(TakiMiniPlayer));
        final nav = tester.getRect(find.byType(NavigationBar));
        expect(mini.bottom, lessThanOrEqualTo(nav.top));
        expect(mini.left, greaterThanOrEqualTo(0));
        expect(mini.right, lessThanOrEqualTo(size.width));
        final play = tester.getRect(find.byTooltip('Reproducir'));
        expect(mini.contains(play.center), isTrue);
      });
    }
  });

  // La resolución de carátulas la hace AlbumArtworkBuilder (core/artwork); la
  // imagen (MemoryImage a 48), la petición exacta, el placeholder y "sin
  // peticiones con cada posición" ya los cubre el grupo 1.6E.
  group('Artwork compartido (Fase 1.8C)', () {
    final other = buildSong(id: 2, title: 'Otra canción', albumId: 20);

    TakiArtwork artOf(WidgetTester tester) => tester.widget<TakiArtwork>(
          find.descendant(
            of: find.byType(TakiMiniPlayer),
            matching: find.byType(TakiArtwork),
          ),
        );

    testWidgets('usa song.artwork, no albumId', (tester) async {
      final remote = remoteArtworkSong();
      final artwork = _BytesArtworkRepository();
      await pumpApp(
        tester,
        overrides: [artworkRepositoryProvider.overrideWithValue(artwork)],
      );
      await startSong(
        tester,
        state: PlaybackState(queue: [remote], currentIndex: 0),
      );

      final builder =
          tester.widget<AlbumArtworkBuilder>(find.byType(AlbumArtworkBuilder));
      expect(builder.reference, remoteTestArtwork);
      expect(builder.albumId, isNull);
      expect(artwork.requests, isEmpty);
    });

    testWidgets('usa AlbumArtworkBuilder con el albumId de la canción y el '
        'tamaño del mini player (48, el que usaba antes)', (tester) async {
      final artwork = _BytesArtworkRepository();
      await pumpApp(
        tester,
        overrides: [artworkRepositoryProvider.overrideWithValue(artwork)],
      );
      await startSong(tester);

      final builder =
          tester.widget<AlbumArtworkBuilder>(find.byType(AlbumArtworkBuilder));
      expect(builder.albumId, song.albumId);
      expect(builder.size, 48);
      expect(builder.size, TakiMiniPlayer.artworkSize);
      final physical = (48 * tester.view.devicePixelRatio).round();
      expect(artwork.requests, [(song.albumId, physical)]);
    });

    testWidgets('error de lectura: sin carátula y el mini player sigue '
        'funcionando', (tester) async {
      final artwork = _BytesArtworkRepository()..failing.add(song.albumId!);
      await pumpApp(
        tester,
        overrides: [artworkRepositoryProvider.overrideWithValue(artwork)],
      );
      await startSong(tester);

      expect(miniPlayer(tester).artwork, isNull);
      expect(find.text('Canción de prueba'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.byTooltip('Reproducir'));
      verify(() => togglePlayPause()).called(1);
    });

    testWidgets('carátula ausente: placeholder y el título sigue', (tester) async {
      final artwork = _BytesArtworkRepository()..missing.add(song.albumId!);
      await pumpApp(
        tester,
        overrides: [artworkRepositoryProvider.overrideWithValue(artwork)],
      );
      await startSong(tester);

      expect(miniPlayer(tester).artwork, isNull);
      expect(find.text('Canción de prueba'), findsOneWidget);
    });

    testWidgets('cambio de canción: pide la carátula del álbum nuevo y al '
        'volver no la repite', (tester) async {
      final artwork = _BytesArtworkRepository();
      await pumpApp(
        tester,
        overrides: [artworkRepositoryProvider.overrideWithValue(artwork)],
      );
      await startSong(
        tester,
        state: PlaybackState(queue: [song, other], currentIndex: 0),
      );
      expect(memoryImageOf(artOf(tester).image!).bytes.first, song.albumId);

      player.emitState(PlaybackState(queue: [song, other], currentIndex: 1));
      await tester.pumpAndSettle();
      expect(memoryImageOf(artOf(tester).image!).bytes.first, 20);

      player.emitState(PlaybackState(queue: [song, other], currentIndex: 0));
      await tester.pumpAndSettle();
      expect(memoryImageOf(artOf(tester).image!).bytes.first, song.albumId);

      expect([for (final r in artwork.requests) r.$1], [song.albumId, 20]);
    });

    testWidgets('play/pausa cambia el estado sin volver a pedir ni cambiar la '
        'carátula', (tester) async {
      final artwork = _BytesArtworkRepository();
      await pumpApp(
        tester,
        overrides: [artworkRepositoryProvider.overrideWithValue(artwork)],
      );
      await startSong(tester);
      final bytes = memoryImageOf(artOf(tester).image!).bytes;
      final before = artwork.requests.length;

      await startSong(tester, isPlaying: true);
      expect(miniPlayer(tester).isPlaying, isTrue);
      expect(identical(memoryImageOf(artOf(tester).image!).bytes, bytes),
          isTrue);

      await startSong(tester);
      expect(miniPlayer(tester).isPlaying, isFalse);
      expect(artwork.requests.length, before);
    });
  });
}
