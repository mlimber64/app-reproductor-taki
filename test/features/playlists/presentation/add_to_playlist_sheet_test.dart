import 'dart:async';
import '../../../helpers/artwork_reference_ext.dart';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:taki/app/theme/app_theme.dart';
import 'package:taki/core/artwork/album_artwork_builder.dart';
import 'package:taki/core/artwork/artwork_providers.dart';
import 'package:taki/core/domain/ports/artwork_repository.dart';
import 'package:taki/core/widgets/taki_artwork.dart';
import 'package:taki/features/playlists/domain/entities/playlist.dart';
import 'package:taki/features/playlists/presentation/playlist_cover_images.dart';
import 'package:taki/features/playlists/presentation/widgets/add_to_playlist_sheet.dart';

import '../../../helpers/library_fakes.dart';
import '../../../helpers/playlists_fakes.dart';
import '../../../helpers/artwork_image.dart';

void main() {
  late _GatedPlaylistsRepository playlists;
  late MockSongRepository library;
  late MockMediaPermission permission;

  // Canciones con álbumes distintos para las portadas.
  final s11 = buildSong(id: 11, title: 's11', albumId: 11, durationMs: 60000);
  final s22 = buildSong(id: 22, title: 's22', albumId: 22, durationMs: 60000);
  final s33 = buildSong(id: 33, title: 's33', albumId: 33, durationMs: 60000);
  final s44 = buildSong(id: 44, title: 's44', albumId: 44, durationMs: 60000);
  final s11b = buildSong(id: 12, title: 's11b', albumId: 11, durationMs: 60000);
  final noAlbum = buildSong(id: 50, title: 'sin álbum', albumId: null);
  // No están en la biblioteca: entradas guardadas ausentes.
  final ghost1 = buildSong(id: 91, title: 'ausente 1', albumId: 91);
  final ghost2 = buildSong(id: 92, title: 'ausente 2', albumId: 92);
  // La canción que se añade desde el menú.
  final extra = buildSong(id: 60, title: 'extra', albumId: 60);

  setUp(() {
    playlists = _GatedPlaylistsRepository();
    permission = MockMediaPermission();
    when(permission.isGranted).thenAnswer((_) async => true);
    library = MockSongRepository();
    when(library.getSongs).thenAnswer(
      (_) async => [s11, s22, s33, s44, s11b, noAlbum, extra],
    );
  });

  /// Lado lógico de la portada y de cada tesela del 2×2, en píxeles.
  int full(WidgetTester tester) => (44 * tester.view.devicePixelRatio).round();
  int tile(WidgetTester tester) => (22 * tester.view.devicePixelRatio).round();

  /// Abre el selector "Añadir a una playlist" para [extra].
  Future<void> openSheet(
    WidgetTester tester, {
    required _BytesArtworkRepository artwork,
    bool settle = true,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...libraryOverrides(
            permission: permission,
            songs: library,
            playlists: playlists,
          ),
          artworkRepositoryProvider.overrideWithValue(artwork),
        ],
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) => TextButton(
                onPressed: () => addSongsToPlaylistFlow(context, ref, [extra]),
                child: const Text('Abrir'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Abrir'));
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
      await tester.pump();
    }
  }

  Finder rowOf(String name) =>
      find.ancestor(of: find.text(name), matching: find.byType(ListTile)).first;

  PlaylistCoverImages coverOf(WidgetTester tester, String name) =>
      tester.widget<PlaylistCoverImages>(
        find.descendant(
          of: rowOf(name),
          matching: find.byType(PlaylistCoverImages),
        ),
      );

  TakiArtwork artOf(WidgetTester tester, String name) =>
      tester.widget<TakiArtwork>(
        find.descendant(of: rowOf(name), matching: find.byType(TakiArtwork)),
      );

  List<int?> coverBytes(WidgetTester tester, String name) => [
        for (final image in artOf(tester, name).mosaic!)
          firstByteOf(image),
      ];

  Finder builderIn<T extends Widget>(String name) =>
      find.descendant(of: rowOf(name), matching: find.byType(T));

  List<int> storedSongIds(int id) =>
      [for (final e in playlists.entriesOf(id)) int.parse(e.musicIdentity.externalId)];

  group('portada: fuente y tamaño', () {
    testWidgets('la portada usa song.artwork, no albumId', (tester) async {
      final remote = remoteArtworkSong();
      when(library.getSongs).thenAnswer((_) async => [remote, extra]);
      playlists.seed('Remota', songs: [remote]);
      final artwork = _BytesArtworkRepository();
      await openSheet(tester, artwork: artwork);

      expect(coverOf(tester, 'Remota').artwork, [remoteTestArtwork]);
      final single = tester.widget<AlbumArtworkBuilder>(
        builderIn<AlbumArtworkBuilder>('Remota'),
      );
      expect(single.reference, remoteTestArtwork);
      expect(artwork.requests.where((r) => r.$1 == remoteSongAlbumId), isEmpty);
    });

    testWidgets('usa el tamaño lógico 44 y conserva el alto de fila',
        (tester) async {
      playlists.seed('Mix', songs: [s11, s22]);
      await openSheet(tester, artwork: _BytesArtworkRepository());

      expect(coverOf(tester, 'Mix').size, 44);
      expect(artOf(tester, 'Mix').size, 44);
      expect(
        tester.getSize(find.descendant(
          of: rowOf('Mix'),
          matching: find.byType(TakiArtwork),
        )),
        const Size(44, 44),
      );
      // Mismo ListTile que antes (minTileHeight: 64) y mismo alto medido con
      // el antiguo PlaylistCover (ya eliminado): 60 (en estos tests, con la
      // fuente de pruebas).
      expect(tester.widget<ListTile>(rowOf('Mix')).minTileHeight, 64);
      expect(tester.getSize(rowOf('Mix')).height, 60);
    });

    testWidgets('la fuente son las primeras 4 entradas guardadas '
        '(coverSongIds): las ausentes ocupan hueco', (tester) async {
      // Entradas: [ausente, 11, ausente, 22, 33]; solo cuentan las 4 primeras.
      playlists.seed('Con huecos', songs: [ghost1, s11, ghost2, s22, s33]);
      final artwork = _BytesArtworkRepository();
      await openSheet(tester, artwork: artwork);

      expect(coverOf(tester, 'Con huecos').albumIds, [11, 22]);
      expect(coverBytes(tester, 'Con huecos'), [11]);
      expect(artwork.requests, [(11, full(tester))]);
    });

    testWidgets('con una ausente delante no se forma mosaico aunque haya 4 '
        'álbumes visibles (semántica de la lista, no del detalle)',
        (tester) async {
      playlists.seed('Huecos', songs: [ghost1, s11, s22, s33, s44]);
      await openSheet(tester, artwork: _BytesArtworkRepository());

      // [null, 11, 22, 33] → 3 álbumes.
      expect(coverOf(tester, 'Huecos').albumIds, [11, 22, 33]);
      expect(builderIn<AlbumArtworkMosaicBuilder>('Huecos'), findsNothing);
    });
  });

  group('portada: [] / [null], 1–3 álbumes y mosaico', () {
    testWidgets('playlist vacía: [] y placeholder con borde, sin petición',
        (tester) async {
      playlists.seed('Nada');
      final artwork = _BytesArtworkRepository();
      await openSheet(tester, artwork: artwork);

      expect(coverOf(tester, 'Nada').albumIds, isEmpty);
      expect(artOf(tester, 'Nada').mosaic, isEmpty);
      expect(builderIn<AlbumArtworkBuilder>('Nada'), findsNothing);
      expect(builderIn<AlbumArtworkMosaicBuilder>('Nada'), findsNothing);
      expect(artwork.requests, isEmpty);
    });

    testWidgets('1 álbum: imagen individual a 44', (tester) async {
      playlists.seed('Uno', songs: [s11, s11b]);
      final artwork = _BytesArtworkRepository();
      await openSheet(tester, artwork: artwork);

      expect(coverOf(tester, 'Uno').albumIds, [11]);
      final single =
          tester.widget<AlbumArtworkBuilder>(builderIn<AlbumArtworkBuilder>('Uno'));
      expect(single.albumId, 11);
      expect(single.size, 44);
      expect(coverBytes(tester, 'Uno'), [11]);
      expect(artwork.requests, [(11, full(tester))]);
    });

    for (final (name, songs, first) in [
      ('2 álbumes', [s22, s11], 22),
      ('3 álbumes', [s33, s11, s22], 33),
    ]) {
      testWidgets('$name: solo la primera imagen, a tamaño completo',
          (tester) async {
        playlists.seed('Varios', songs: songs);
        final artwork = _BytesArtworkRepository();
        await openSheet(tester, artwork: artwork);

        expect(coverOf(tester, 'Varios').albumIds, hasLength(songs.length));
        expect(coverBytes(tester, 'Varios'), [first]);
        expect(builderIn<AlbumArtworkMosaicBuilder>('Varios'), findsNothing);
        expect(artwork.requests, [(first, full(tester))]);
      });
    }

    testWidgets('4 álbumes: mosaico con cada tesela a la mitad del lado',
        (tester) async {
      playlists.seed('Cuatro', songs: [s11, s22, s33, s44]);
      final artwork = _BytesArtworkRepository();
      await openSheet(tester, artwork: artwork);

      final mosaic = tester.widget<AlbumArtworkMosaicBuilder>(
        builderIn<AlbumArtworkMosaicBuilder>('Cuatro'),
      );
      expect(mosaic.albumIds, [11, 22, 33, 44]);
      expect(mosaic.size, 44);
      expect(coverBytes(tester, 'Cuatro'), [11, 22, 33, 44]);
      expect(artwork.requests.map((r) => r.$2).toSet(), {tile(tester)});
      expect(artwork.requests.map((r) => r.$1).toSet(), {11, 22, 33, 44});
      expect(tile(tester), lessThan(full(tester)));
    });

    testWidgets('[A, A, B, C, D] da [A, B, C]: no hay mosaico y el 4.º no se '
        'pide', (tester) async {
      playlists.seed('Repetidas', songs: [s11, s11b, s22, s33, s44]);
      final artwork = _BytesArtworkRepository();
      await openSheet(tester, artwork: artwork);

      expect(coverOf(tester, 'Repetidas').albumIds, [11, 22, 33]);
      expect(coverBytes(tester, 'Repetidas'), [11]);
      expect(artwork.requests, [(11, full(tester))]);
    });

    testWidgets('canciones sin álbum: [null] y una pieza sin imagen, sin '
        'petición', (tester) async {
      playlists.seed('Sin álbum', songs: [noAlbum]);
      final artwork = _BytesArtworkRepository();
      await openSheet(tester, artwork: artwork);

      expect(coverOf(tester, 'Sin álbum').albumIds, [null]);
      expect(artOf(tester, 'Sin álbum').mosaic, [null]);
      expect(artwork.requests, isEmpty);
    });

    testWidgets('todas las canciones ausentes: [null] (hay entradas)',
        (tester) async {
      playlists.seed('Fantasmas', songs: [ghost1, ghost2]);
      await openSheet(tester, artwork: _BytesArtworkRepository());

      expect(coverOf(tester, 'Fantasmas').albumIds, [null]);
      expect(artOf(tester, 'Fantasmas').mosaic, [null]);
    });

    testWidgets('artwork ausente de un álbum: pieza sin imagen y el sheet '
        'sigue', (tester) async {
      playlists.seed('Uno', songs: [s11]);
      await openSheet(
        tester,
        artwork: _BytesArtworkRepository()..missing.add(11),
      );

      expect(artOf(tester, 'Uno').mosaic, [null]);
      expect(find.text('Uno'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('error de lectura en un mosaico: una pieza sin imagen y la '
        'selección sigue funcionando', (tester) async {
      final id = playlists.seed('Cuatro', songs: [s11, s22, s33, s44]);
      await openSheet(
        tester,
        artwork: _BytesArtworkRepository()..failing.add(22),
      );

      expect(coverBytes(tester, 'Cuatro'), [11, null, 33, 44]);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Cuatro'));
      await tester.pumpAndSettle();
      expect(storedSongIds(id), [11, 22, 33, 44, 60]);
    });
  });

  group('selección y añadir', () {
    testWidgets('tocar una playlist la añade y avisa (sin cambios)',
        (tester) async {
      final id = playlists.seed('Mix', songs: [s11]);
      await openSheet(tester, artwork: _BytesArtworkRepository());

      await tester.tap(find.text('Mix'));
      await tester.pumpAndSettle();

      expect(storedSongIds(id), [11, 60]);
      expect(find.text('Añadida a «Mix»'), findsOneWidget);
      expect(find.byType(BottomSheet), findsNothing);
    });

    testWidgets('si ya estaba, la añade otra vez y lo avisa', (tester) async {
      final id = playlists.seed('Mix', songs: [extra]);
      await openSheet(tester, artwork: _BytesArtworkRepository());

      await tester.tap(find.text('Mix'));
      await tester.pumpAndSettle();

      expect(storedSongIds(id), [60, 60]);
      expect(
        find.text('Ya estaba en «Mix»; se añadió otra vez'),
        findsOneWidget,
      );
    });

    testWidgets('el resumen y el orden de las playlists no cambian',
        (tester) async {
      playlists
        ..seed('Vieja', songs: [s11])
        ..seed('Reciente', songs: [s11, s22]);
      await openSheet(tester, artwork: _BytesArtworkRepository());

      expect(find.text('2 canciones · 2 min'), findsOneWidget);
      expect(find.text('1 canción · 1 min'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Reciente')).dy,
        lessThan(tester.getTopLeft(find.text('Vieja')).dy),
      );
    });

    testWidgets('"Nueva playlist" sigue arriba y abre el diálogo',
        (tester) async {
      playlists.seed('Mix');
      await openSheet(tester, artwork: _BytesArtworkRepository());

      await tester.tap(find.text('Nueva playlist'));
      await tester.pumpAndSettle();

      expect(find.text('Crear'), findsOneWidget);
    });

    testWidgets('añadir una canción actualiza la portada al reabrir el '
        'selector', (tester) async {
      final id = playlists.seed('Crece', songs: [s11, s22, s33]);
      final artwork = _BytesArtworkRepository();
      await openSheet(tester, artwork: artwork);
      expect(coverBytes(tester, 'Crece'), [11]);
      expect(builderIn<AlbumArtworkMosaicBuilder>('Crece'), findsNothing);

      // La cuarta canción (álbum 60) entra por el propio selector.
      await tester.tap(find.text('Crece'));
      await tester.pumpAndSettle();
      expect(storedSongIds(id), [11, 22, 33, 60]);

      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();

      expect(coverOf(tester, 'Crece').albumIds, [11, 22, 33, 60]);
      expect(builderIn<AlbumArtworkMosaicBuilder>('Crece'), findsOneWidget);
      expect(coverBytes(tester, 'Crece'), [11, 22, 33, 60]);
    });

    testWidgets('con el selector abierto, un cambio de la playlist actualiza '
        'la portada', (tester) async {
      final id = playlists.seed('Crece', songs: [s11, s22, s33]);
      await openSheet(tester, artwork: _BytesArtworkRepository());
      expect(coverBytes(tester, 'Crece'), [11]);

      await playlists.addSongs(id, [s44]);
      await tester.pumpAndSettle();

      expect(coverBytes(tester, 'Crece'), [11, 22, 33, 44]);
    });
  });

  group('carga y error (sin cambios)', () {
    testWidgets('mientras carga: spinner; luego las playlists',
        (tester) async {
      playlists
        ..seed('Mix', songs: [s11])
        ..gate = Completer<void>();
      await openSheet(
        tester,
        artwork: _BytesArtworkRepository(),
        settle: false,
      );

      expect(
        find.byWidgetPredicate(
            (w) => w.runtimeType == CircularProgressIndicator),
        findsOneWidget,
      );
      expect(find.text('Nueva playlist'), findsOneWidget);

      playlists.gate!.complete();
      await tester.pumpAndSettle();
      expect(find.text('Mix'), findsOneWidget);
    });

    testWidgets('base no disponible: mensaje y "Nueva playlist" sigue ahí',
        (tester) async {
      playlists
        ..seed('Mix')
        ..failing = true;
      await openSheet(tester, artwork: _BytesArtworkRepository());

      expect(find.text('Las playlists no están disponibles'), findsOneWidget);
      expect(find.text('Nueva playlist'), findsOneWidget);
      expect(find.byType(PlaylistCoverImages), findsNothing);
    });
  });
}

/// [FakePlaylistsRepository] cuyo stream puede quedar retenido con [gate].
class _GatedPlaylistsRepository extends FakePlaylistsRepository {
  Completer<void>? gate;

  @override
  Stream<List<Playlist>> watchPlaylists() async* {
    final gate = this.gate;
    if (gate != null) await gate.future;
    yield* super.watchPlaylists();
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
