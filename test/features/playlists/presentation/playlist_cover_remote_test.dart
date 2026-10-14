import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:taki/app/theme/app_theme.dart';
import 'package:taki/core/artwork/artwork_providers.dart';
import 'package:taki/core/domain/entities/artwork_reference.dart';
import 'package:taki/core/domain/entities/local_music_identity.dart';
import 'package:taki/core/domain/entities/music_identity.dart';
import 'package:taki/core/domain/entities/song.dart';
import 'package:taki/core/domain/ports/artwork_repository.dart';
import 'package:taki/core/domain/ports/remote_artwork_loader.dart';
import 'package:taki/core/domain/services/source_song_lookup.dart';
import 'package:taki/core/lookup/song_lookup_providers.dart';
import 'package:taki/core/widgets/taki_artwork.dart';
import 'package:taki/core/widgets/taki_playlist_card.dart';
import 'package:taki/features/library/domain/services/local_song_lookup.dart';
import 'package:taki/features/library/presentation/providers/songs_notifier.dart';
import 'package:taki/features/playlists/presentation/pages/playlists_page.dart';
import 'package:taki/features/playlists/presentation/widgets/add_to_playlist_sheet.dart';

import '../../../helpers/artwork_image.dart';
import '../../../helpers/library_fakes.dart';
import '../../../helpers/playlists_fakes.dart';
import '../../../helpers/song_lookup_fakes.dart';
import '../../../helpers/universal_song.dart';

/// Locales: bytes `[albumId, size]`.
class _LocalArt implements ArtworkRepository {
  @override
  Future<Uint8List?> getAlbumArtwork(int albumId, {required int size}) async =>
      Uint8List.fromList([albumId, size & 0xff]);
}

/// Remotas: bytes `[n, size]` donde `n` sale de la URL `https://img.test/<n>.jpg`.
class _RemoteArt implements RemoteArtworkLoader {
  final loads = <(String, int)>[];
  final failing = <String>{};
  final missing = <String>{};

  @override
  Future<Uint8List?> load(RemoteArtworkReference reference,
      {required int size}) async {
    loads.add((reference.url, size));
    if (failing.contains(reference.url)) throw StateError('red');
    if (missing.contains(reference.url)) return null;
    final n = int.parse(RegExp(r'/(\d+)\.jpg').firstMatch(reference.url)![1]!);
    return Uint8List.fromList([n, size & 0xff]);
  }
}

/// Fase 3.6: las portadas de playlist salen de `Song.artwork` de las canciones
/// resueltas, sea local o remota, por la infraestructura de artwork de siempre.
/// «jamendo» es solo la etiqueta de una fuente de prueba.
void main() {
  final l11 = buildSong(id: 11, title: 'l11', albumId: 11);
  final l22 = buildSong(id: 22, title: 'l22', albumId: 22);
  final l33 = buildSong(id: 33, title: 'l33', albumId: 33);

  Song remoteSong(String id, {String? image, bool unavailable = false}) =>
      buildUniversalSong(
        MusicIdentity('jamendo', id),
        title: 'r$id',
        artwork: unavailable
            ? const UnavailableArtworkReference()
            : RemoteArtworkReference(image ?? 'https://img.test/$id.jpg'),
      );

  final r1 = remoteSong('101');
  final r2 = remoteSong('102');
  final r3 = remoteSong('103');
  final rNone = remoteSong('104', unavailable: true);

  late FakePlaylistsRepository playlists;
  late FakeSourceLookup remoteLookup;
  late _RemoteArt remoteArt;
  late MockMediaPermission permission;
  late MockSongRepository library;

  setUp(() {
    playlists = FakePlaylistsRepository();
    remoteLookup = FakeSourceLookup([r1, r2, r3, rNone]);
    remoteArt = _RemoteArt();
    permission = MockMediaPermission();
    when(permission.isGranted).thenAnswer((_) async => true);
    when(permission.isPermanentlyDenied).thenAnswer((_) async => false);
    library = MockSongRepository();
    when(library.getSongs).thenAnswer((_) async => [l11, l22, l33]);
  });

  List<Override> overrides() => [
        ...libraryOverrides(
          permission: permission,
          songs: library,
          playlists: playlists,
        ),
        artworkRepositoryProvider.overrideWithValue(_LocalArt()),
        remoteArtworkLoaderProvider.overrideWithValue(remoteArt),
        songLookupProvider.overrideWith(
          (ref) => SourceSongLookup({
            localMusicSource: LocalSongLookup(() async {
              final state = await ref.read(songsProvider.future);
              return state is LibraryLoaded ? state.songs : const [];
            }),
            'jamendo': remoteLookup,
          }),
        ),
      ];

  Future<void> pumpPage(WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides(),
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: PlaylistsPage(onOpenPlaylist: (_) {}),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder card(String title) => find.ancestor(
        of: find.text(title),
        matching: find.byType(TakiPlaylistCard),
      );

  TakiArtwork coverOf(WidgetTester tester, String title) =>
      tester.widget<TakiArtwork>(
        find.descendant(of: card(title), matching: find.byType(TakiArtwork)),
      );

  List<int?> bytes(WidgetTester tester, String title) => [
        for (final image in coverOf(tester, title).mosaic!) firstByteOf(image),
      ];

  group('portadas', () {
    testWidgets('A: solo locales — igual que antes y sin consultar a la otra '
        'fuente', (tester) async {
      playlists.seed('Locales', songs: [l11, l22]);
      await pumpPage(tester);

      expect(bytes(tester, 'Locales'), [11]);
      expect(remoteLookup.requests, isEmpty);
      expect(remoteArt.loads, isEmpty);
    });

    testWidgets('B: solo remotas — se muestra la carátula remota',
        (tester) async {
      playlists.seed('Remotas', songs: [r1, r2]);
      await pumpPage(tester);

      expect(bytes(tester, 'Remotas'), [101]);
      expect(remoteLookup.requests.single, {r1.musicIdentity, r2.musicIdentity});
    });

    testWidgets('C/J: mixta de 4 — orden y número de celdas se conservan',
        (tester) async {
      playlists.seed('Mixta', songs: [l11, r1, l22, r2]);
      await pumpPage(tester);

      expect(bytes(tester, 'Mixta'), [11, 101, 22, 102]);
      expect(
        find.descendant(of: card('Mixta'), matching: find.byType(Image)),
        findsNWidgets(4),
      );
    });

    testWidgets('mixta con menos de 4: la primera canción manda', (tester) async {
      playlists.seed('Primera remota', songs: [r1, l11]);
      playlists.seed('Primera local', songs: [l22, r2]);
      await pumpPage(tester);

      expect(bytes(tester, 'Primera remota'), [101]);
      expect(bytes(tester, 'Primera local'), [22]);
    });

    testWidgets('D: remota sin carátula (unavailable) → pieza sin imagen',
        (tester) async {
      playlists.seed('Sin arte', songs: [rNone]);
      await pumpPage(tester);

      expect(bytes(tester, 'Sin arte'), [null]);
      expect(remoteArt.loads, isEmpty); // no se pide nada
    });

    testWidgets('D2: se ignoran las sin carátula y cuenta la siguiente',
        (tester) async {
      playlists.seed('Mix', songs: [rNone, r3]);
      await pumpPage(tester);

      expect(bytes(tester, 'Mix'), [103]);
    });

    testWidgets('E: el cargador remoto falla → fallback, la playlist se '
        'muestra', (tester) async {
      remoteArt.failing.add(r1.artwork is RemoteArtworkReference
          ? (r1.artwork as RemoteArtworkReference).url
          : '');
      playlists.seed('Falla', songs: [r1]);
      await pumpPage(tester);

      expect(find.text('Falla'), findsOneWidget);
      expect(bytes(tester, 'Falla'), [null]);
      expect(tester.takeException(), isNull);
    });

    testWidgets('el cargador devuelve null → fallback', (tester) async {
      remoteArt.missing.add('https://img.test/101.jpg');
      playlists.seed('Nula', songs: [r1]);
      await pumpPage(tester);

      expect(bytes(tester, 'Nula'), [null]);
    });

    testWidgets('la fuente remota falla en el lookup → fallback, las locales '
        'siguen', (tester) async {
      remoteLookup.failure = StateError('sin red');
      playlists
        ..seed('Remota', songs: [r1])
        ..seed('Local', songs: [l11]);
      await pumpPage(tester);

      expect(bytes(tester, 'Remota'), [null]);
      expect(bytes(tester, 'Local'), [11]);
      expect(tester.takeException(), isNull);
    });

    testWidgets('F: playlist vacía → estado visual existente', (tester) async {
      playlists.seed('Vacía');
      await pumpPage(tester);

      expect(coverOf(tester, 'Vacía').mosaic, isEmpty);
      expect(remoteLookup.requests, isEmpty);
    });

    testWidgets('G: una imagen remota que falla no rompe las locales del '
        'mosaico', (tester) async {
      remoteArt.failing.add('https://img.test/102.jpg');
      playlists.seed('Cuatro', songs: [l11, r2, l22, l33]);
      await pumpPage(tester);

      expect(bytes(tester, 'Cuatro'), [11, null, 22, 33]);
    });

    testWidgets('la misma carátula remota en dos playlists se descarga una '
        'sola vez (caché existente)', (tester) async {
      playlists
        ..seed('Uno', songs: [r1])
        ..seed('Dos', songs: [r1, l11]);
      await pumpPage(tester);

      expect(bytes(tester, 'Uno'), [101]);
      expect(bytes(tester, 'Dos'), [101]);
      expect(remoteArt.loads.where((l) => l.$1.endsWith('/101.jpg')), hasLength(1));
    });

    testWidgets('si crece el conjunto de portadas remotas se vuelve a resolver',
        (tester) async {
      final id = playlists.seed('Mix', songs: [r1]);
      await pumpPage(tester);
      expect(remoteLookup.requests, hasLength(1));

      // Una nueva playlist con otra remota: el conjunto pasa de {r1} a {r1, r2}.
      final other = await playlists.create('Otra');
      await playlists.addSongs(other, [r2]);
      await tester.pumpAndSettle();

      expect(remoteLookup.requests, hasLength(2));
      expect(bytes(tester, 'Otra'), [102]);
      expect(bytes(tester, 'Mix'), [101]);
      expect(playlists.entriesOf(id), hasLength(1));
    });

    testWidgets('si cambia el contenido del conjunto (mismo tamaño) se vuelve '
        'a resolver', (tester) async {
      final id = playlists.seed('Mix', songs: [r1]);
      await pumpPage(tester);
      expect(bytes(tester, 'Mix'), [101]);

      // Se quita r1 y se añade r2: el conjunto pasa de {r1} a {r2}.
      await playlists.removeEntry(playlists.entriesOf(id).single.id);
      await playlists.addSongs(id, [r2]);
      await tester.pumpAndSettle();

      expect(remoteLookup.requests, hasLength(2));
      expect(bytes(tester, 'Mix'), [102]);
    });

    testWidgets('la biblioteca local falla: las remotas siguen mostrándose',
        (tester) async {
      when(library.getSongs).thenAnswer((_) async => throw StateError('x'));
      playlists.seed('Mixta', songs: [l11, r1]);
      await pumpPage(tester);

      // l11 no se pudo resolver (queda sin imagen), r1 sí.
      expect(bytes(tester, 'Mixta'), [101]);
    });

    testWidgets('H: editar una playlist sin cambiar sus portadas no vuelve a '
        'consultar ni a descargar', (tester) async {
      final id = playlists.seed('Remotas', songs: [r1]);
      await pumpPage(tester);
      expect(remoteLookup.requests, hasLength(1));
      expect(remoteArt.loads, hasLength(1));

      // Añadir una local cambia la playlist, no el conjunto a resolver.
      await playlists.addSongs(id, [l11]);
      await tester.pumpAndSettle();
      expect(remoteLookup.requests, hasLength(1));
      expect(remoteArt.loads, hasLength(1));
      expect(bytes(tester, 'Remotas'), [101]);
    });
  });

  group('selector «Añadir a una playlist»', () {
    testWidgets('K: muestra la portada remota y sigue funcionando',
        (tester) async {
      final id = playlists.seed('Mix', songs: [r1]);
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: overrides(),
          child: MaterialApp(
            theme: AppTheme.dark(),
            home: Consumer(
              builder: (context, ref, _) => Scaffold(
                body: TextButton(
                  onPressed: () => addSongsToPlaylistFlow(context, ref, [l22]),
                  child: const Text('Abrir'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();

      final art = tester.widget<TakiArtwork>(find.descendant(
        of: find.byType(BottomSheet),
        matching: find.byType(TakiArtwork),
      ));
      expect([for (final i in art.mosaic!) firstByteOf(i)], [101]);

      await tester.tap(find.text('Mix'));
      await tester.pumpAndSettle();
      expect(playlists.entriesOf(id).last.musicIdentity, l22.musicIdentity);
    });
  });
}
