import 'package:flutter_test/flutter_test.dart';
import 'package:taki/core/domain/entities/local_music_identity.dart';
import 'package:taki/core/domain/entities/local_song.dart';
import 'package:taki/core/domain/entities/music_identity.dart';
import 'package:taki/core/domain/entities/song.dart';
import 'package:taki/core/domain/entities/song_lookup_failure.dart';
import 'package:taki/core/domain/ports/song_lookup.dart';
import 'package:taki/core/domain/services/source_song_lookup.dart';
import 'package:taki/features/library/domain/entities/favorite_entry.dart';
import 'package:taki/features/library/domain/services/local_song_lookup.dart';
import 'package:taki/features/library/domain/usecases/favorites_usecases.dart';
import 'package:taki/features/playlists/domain/entities/playlist_entry.dart';
import 'package:taki/features/playlists/domain/usecases/playlist_usecases.dart';

import '../../../helpers/favorites_fakes.dart';
import '../../../helpers/library_fakes.dart';
import '../../../helpers/playlists_fakes.dart';
import '../../../helpers/song_lookup_fakes.dart';
import '../../../helpers/universal_song.dart';

/// Favoritos y playlists resueltos con un lookup de varias fuentes: la local y
/// una remota ficticia (`otra`), sin ningún proveedor real.
void main() {
  final localA = buildSong(id: 1, title: 'A');
  final localB = buildSong(id: 2, title: 'B');
  final remoteX = buildUniversalSong(
    MusicIdentity('otra', 'x'),
    title: 'Remota X',
    durationMs: 111000,
  );
  final remoteY = buildUniversalSong(MusicIdentity('otra', 'y'), title: 'Y');

  SongLookup lookup({
    required List<LocalSong> library,
    Iterable<Song> remote = const [],
    bool registerLocal = true,
    bool registerRemote = true,
    FakeSourceLookup? remoteLookup,
    Future<List<LocalSong>> Function()? localLoader,
  }) {
    return SourceSongLookup({
      if (registerLocal)
        localMusicSource: LocalSongLookup(localLoader ?? () async => library),
      if (registerRemote)
        'otra': remoteLookup ?? FakeSourceLookup(remote),
    });
  }

  group('GetFavoriteSongs con varias fuentes', () {
    late FakeFavoritesRepository favorites;
    setUp(() => favorites = FakeFavoritesRepository());

    FavoriteEntry entry(Song song, int minute) {
      final base = favorites.entryFor(song);
      return FavoriteEntry(
        musicIdentity: base.musicIdentity,
        addedAt: DateTime(2026, 9, 1, 12, minute),
        title: base.title,
        artist: base.artist,
        album: base.album,
        durationMs: base.durationMs,
        path: base.path,
      );
    }

    test('favorito local resuelto y favorito remoto resuelto, en orden',
        () async {
      favorites
        ..seed(entry(localA, 1))
        ..seed(entry(remoteX, 2))
        ..seed(entry(localB, 3));

      final songs = await GetFavoriteSongs(
        favorites,
        lookup(library: [localA, localB], remote: [remoteX]),
      )([localA, localB]);

      expect(songs, [localB, remoteX, localA]);
      expect(favorites.relinks, isEmpty);
    });

    test('favorito local ausente: se oculta pero no se borra', () async {
      favorites
        ..seed(entry(localA, 1))
        ..seed(entry(localB, 2));

      final songs = await GetFavoriteSongs(
        favorites,
        lookup(library: [localA]),
      )([localA]);

      expect(songs, [localA]);
      expect(favorites.entries.keys, hasLength(2));
    });

    test('identidad de una fuente sin lookup: oculta, conservada y sin '
        'reencuentro local', () async {
      favorites
        ..seed(entry(localA, 1))
        ..seed(entry(remoteY, 2));

      final songs = await GetFavoriteSongs(
        favorites,
        lookup(library: [localA], registerRemote: false),
      )([localA]);

      expect(songs, [localA]);
      expect(favorites.entries.keys, contains(remoteY.musicIdentity));
      expect(favorites.relinks, isEmpty);
    });

    test('una entrada remota NO se reencuentra por título/ruta con una '
        'canción local', () async {
      // Mismo título, artista, duración y ruta que `localA`, pero identidad de
      // otra fuente que la declara `missing`.
      favorites.seed(FavoriteEntry(
        musicIdentity: MusicIdentity('otra', 'z'),
        addedAt: DateTime(2026, 9, 1),
        title: localA.title,
        artist: localA.artist,
        durationMs: localA.durationMs,
        path: localA.path,
      ));

      final songs = await GetFavoriteSongs(
        favorites,
        lookup(library: [localA]),
      )([localA]);

      expect(songs, isEmpty);
      expect(favorites.relinks, isEmpty);
      expect(favorites.entries.keys, [MusicIdentity('otra', 'z')]);
    });

    test('un favorito local missing sí usa el reencuentro local y se '
        'reenlaza', () async {
      final moved = buildSong(id: 50, title: 'A');
      favorites.seed(FavoriteEntry(
        musicIdentity: localMusicIdentity(5),
        addedAt: DateTime(2026, 9, 1),
        path: moved.path,
      ));

      final songs = await GetFavoriteSongs(
        favorites,
        lookup(library: [moved]),
      )([moved]);

      expect(songs, [moved]);
      expect(favorites.relinks, [(localMusicIdentity(5), localMusicIdentity(50))]);
    });

    test('un favorito local con lookup local NO registrado no se tapa con el '
        'reencuentro (error de configuración visible)', () async {
      favorites.seed(entry(localA, 1));

      final songs = await GetFavoriteSongs(
        favorites,
        lookup(library: [localA], registerLocal: false),
      )([localA]);

      expect(songs, isEmpty);
      expect(favorites.relinks, isEmpty);
    });

    test('la fuente remota falla: la local se resuelve y la remota se oculta '
        'sin borrarse', () async {
      favorites
        ..seed(entry(localA, 1))
        ..seed(entry(remoteX, 2));
      final failing = FakeSourceLookup()..failure = StateError('sin red');

      final songs = await GetFavoriteSongs(
        favorites,
        lookup(library: [localA], remoteLookup: failing),
      )([localA]);

      expect(songs, [localA]);
      expect(favorites.relinks, isEmpty);
      expect(favorites.entries, hasLength(2));
    });

    test('la fuente local falla: la remota se resuelve', () async {
      favorites
        ..seed(entry(localA, 1))
        ..seed(entry(remoteX, 2));

      final songs = await GetFavoriteSongs(
        favorites,
        lookup(
          library: const [],
          remote: [remoteX],
          localLoader: () async => throw StateError('MediaStore'),
        ),
      )(const []);

      expect(songs, [remoteX]);
      expect(favorites.entries, hasLength(2));
    });

    test('un fallo NO es missing: no se reencuentra por título ni se relinka',
        () async {
      // Entrada local con id viejo; la biblioteca tiene la misma canción con
      // otra identidad (el matcher la reencontraría si fuera `missing`).
      favorites
        ..seed(favorites.entryFor(localA, identity: localMusicIdentity(99)))
        ..seed(entry(remoteX, 2));

      final songs = await GetFavoriteSongs(
        favorites,
        lookup(
          library: [localA],
          remote: [remoteX],
          localLoader: () async => throw StateError('MediaStore'),
        ),
      )([localA]);

      expect(songs, [remoteX]);
      expect(favorites.relinks, isEmpty);
      expect(favorites.entries.keys,
          containsAll([localMusicIdentity(99), remoteX.musicIdentity]));
    });

    test('fallan todas las fuentes: el error llega a quien llama y no '
        'modifica nada', () async {
      favorites
        ..seed(entry(localA, 1))
        ..seed(entry(remoteX, 2));
      final failing = FakeSourceLookup()..failure = StateError('sin red');

      await expectLater(
        GetFavoriteSongs(
          favorites,
          lookup(
            library: [localA],
            remoteLookup: failing,
            localLoader: () async => throw StateError('MediaStore'),
          ),
        )([localA]),
        throwsA(isA<SongLookupFailure>()),
      );
      expect(favorites.relinks, isEmpty);
      expect(favorites.entries, hasLength(2));
    });

    test('solo remotas y la fuente local no se consulta si no hay locales',
        () async {
      favorites.seed(entry(remoteX, 1));
      var localCalls = 0;

      final songs = await GetFavoriteSongs(
        favorites,
        lookup(
          library: const [],
          remote: [remoteX],
          localLoader: () async {
            localCalls++;
            return const [];
          },
        ),
      )(const []);

      expect(songs, [remoteX]);
      expect(localCalls, 0);
    });

    test('no repite una canción resuelta por dos entradas', () async {
      favorites
        ..seed(entry(localA, 1))
        ..seed(FavoriteEntry(
          musicIdentity: localMusicIdentity(99),
          addedAt: DateTime(2026, 9, 1, 12, 2),
          path: localA.path,
        ));

      final songs = await GetFavoriteSongs(
        favorites,
        lookup(library: [localA]),
      )([localA]);

      expect(songs, [localA]);
    });

    test('sin favoritos no consulta al lookup', () async {
      final remote = FakeSourceLookup();
      final songs = await GetFavoriteSongs(
        favorites,
        lookup(library: [localA], remoteLookup: remote),
      )([localA]);

      expect(songs, isEmpty);
      expect(remote.requests, isEmpty);
    });

    test('todas las identidades se resuelven en una sola llamada por fuente',
        () async {
      favorites
        ..seed(entry(remoteX, 1))
        ..seed(entry(remoteY, 2));
      final remote = FakeSourceLookup([remoteX, remoteY]);

      await GetFavoriteSongs(
        favorites,
        lookup(library: [], remoteLookup: remote),
      )(const []);

      expect(remote.requests, hasLength(1));
      expect(remote.requests.single, {remoteX.musicIdentity, remoteY.musicIdentity});
    });
  });

  group('GetPlaylistSongs con varias fuentes', () {
    late FakePlaylistsRepository playlists;
    setUp(() => playlists = FakePlaylistsRepository());

    test('conserva orden, duplicados e identidad de cada entrada', () async {
      final id = playlists.seed(
        'Mix',
        songs: [remoteX, localA, remoteX, localB, localA],
      );

      final items = await GetPlaylistSongs(
        playlists,
        lookup(library: [localA, localB], remote: [remoteX]),
      )(id, [localA, localB]);

      expect(items.map((i) => i.song), [remoteX, localA, remoteX, localB, localA]);
      expect(items.map((i) => i.entry.position), [0, 1, 2, 3, 4]);
      expect(items.map((i) => i.entry.musicIdentity), [
        remoteX.musicIdentity,
        localA.musicIdentity,
        remoteX.musicIdentity,
        localB.musicIdentity,
        localA.musicIdentity,
      ]);
      // Cada repetición conserva su propia entrada.
      expect({for (final i in items) i.entry.id}, hasLength(5));
    });

    test('identidad local no disponible: se oculta y se conserva', () async {
      final id = playlists.seed('Mix', songs: [localA, localB, remoteX]);

      final items = await GetPlaylistSongs(
        playlists,
        lookup(library: [localA], remote: [remoteX]),
      )(id, [localA]);

      expect(items.map((i) => i.song), [localA, remoteX]);
      expect(items.map((i) => i.entry.position), [0, 2]);
      expect(playlists.entriesOf(id), hasLength(3));
    });

    test('fuente sin lookup: sus entradas se ocultan sin afectar al resto',
        () async {
      final id = playlists.seed('Mix', songs: [localA, remoteY, localB]);

      final items = await GetPlaylistSongs(
        playlists,
        lookup(library: [localA, localB], registerRemote: false),
      )(id, [localA, localB]);

      expect(items.map((i) => i.song), [localA, localB]);
      expect(items.map((i) => i.entry.position), [0, 2]);
      expect(playlists.entriesOf(id), hasLength(3));
      expect(playlists.relinks, isEmpty);
    });

    test('una entrada remota no se reencuentra por título/ruta con una local',
        () async {
      final id = playlists.seed('Mix');
      playlists.seedEntry(
        id,
        (entryId, position) => PlaylistEntry(
          id: entryId,
          playlistId: id,
          position: position,
          musicIdentity: MusicIdentity('otra', 'z'),
          title: localA.title,
          artist: localA.artist,
          durationMs: localA.durationMs,
          path: localA.path,
        ),
      );

      final items = await GetPlaylistSongs(
        playlists,
        lookup(library: [localA]),
      )(id, [localA]);

      expect(items, isEmpty);
      expect(playlists.relinks, isEmpty);
    });

    test('una entrada local con el lookup local NO registrado no se tapa con '
        'el reencuentro (error de configuración visible)', () async {
      final id = playlists.seed('Mix');
      playlists.seedEntry(
        id,
        (entryId, position) => PlaylistEntry(
          id: entryId,
          playlistId: id,
          position: position,
          musicIdentity: localMusicIdentity(99),
          path: localA.path, // el reencuentro por ruta la habría encontrado
        ),
      );

      final items = await GetPlaylistSongs(
        playlists,
        lookup(library: [localA], registerLocal: false),
      )(id, [localA]);

      expect(items, isEmpty);
      expect(playlists.relinks, isEmpty);
      expect(playlists.entriesOf(id), hasLength(1));
    });

    test('reencuentro local de una entrada missing: conserva id y posición',
        () async {
      final moved = buildSong(id: 50, title: 'A');
      final id = playlists.seed('Mix', songs: [remoteX]);
      playlists.seedEntry(
        id,
        (entryId, position) => PlaylistEntry(
          id: entryId,
          playlistId: id,
          position: position,
          musicIdentity: localMusicIdentity(1),
          path: moved.path,
        ),
      );

      final items = await GetPlaylistSongs(
        playlists,
        lookup(library: [moved], remote: [remoteX]),
      )(id, [moved]);

      expect(items.map((i) => i.song), [remoteX, moved]);
      expect(items.last.entry.position, 1);
      expect(items.last.entry.musicIdentity, localMusicIdentity(50));
      expect(playlists.relinks, hasLength(1));
    });

    test('la fuente remota falla: se muestran las locales (orden y posiciones '
        'intactos) y nada se borra', () async {
      final id = playlists.seed('Mix', songs: [localA, remoteX, localB, localA]);
      final failing = FakeSourceLookup()..failure = StateError('sin red');

      final items = await GetPlaylistSongs(
        playlists,
        lookup(library: [localA, localB], remoteLookup: failing),
      )(id, [localA, localB]);

      expect(items.map((i) => i.song), [localA, localB, localA]);
      expect(items.map((i) => i.entry.position), [0, 2, 3]);
      expect(playlists.entriesOf(id), hasLength(4));
      expect(playlists.relinks, isEmpty);
    });

    test('la fuente local falla: se muestran las remotas, con orden y '
        'duplicados', () async {
      final id = playlists.seed(
        'Mix',
        songs: [remoteX, localA, remoteY, remoteX],
      );

      final items = await GetPlaylistSongs(
        playlists,
        lookup(
          library: const [],
          remote: [remoteX, remoteY],
          localLoader: () async => throw StateError('MediaStore'),
        ),
      )(id, const []);

      expect(items.map((i) => i.song), [remoteX, remoteY, remoteX]);
      expect(items.map((i) => i.entry.position), [0, 2, 3]);
      expect(playlists.entriesOf(id), hasLength(4));
    });

    test('un fallo NO es missing: no se reencuentra ni se relinka', () async {
      final id = playlists.seed('Mix', songs: [remoteX]);
      playlists.seedEntry(
        id,
        (entryId, position) => PlaylistEntry(
          id: entryId,
          playlistId: id,
          position: position,
          musicIdentity: localMusicIdentity(99),
          title: localA.title,
          artist: localA.artist,
          album: localA.album,
          durationMs: localA.durationMs,
        ),
      );

      final items = await GetPlaylistSongs(
        playlists,
        lookup(
          library: [localA],
          remote: [remoteX],
          localLoader: () async => throw StateError('MediaStore'),
        ),
      )(id, [localA]);

      expect(items.map((i) => i.song), [remoteX]);
      expect(playlists.relinks, isEmpty);
      expect(playlists.entriesOf(id).last.musicIdentity,
          localMusicIdentity(99));
    });

    test('fallan todas las fuentes: el error llega a quien llama', () async {
      final id = playlists.seed('Mix', songs: [localA, remoteX]);
      final failing = FakeSourceLookup()..failure = StateError('sin red');

      await expectLater(
        GetPlaylistSongs(
          playlists,
          lookup(
            library: [localA],
            remoteLookup: failing,
            localLoader: () async => throw StateError('MediaStore'),
          ),
        )(id, [localA]),
        throwsA(isA<SongLookupFailure>()),
      );
      expect(playlists.entriesOf(id), hasLength(2));
    });

    test('playlist vacía: no consulta al lookup', () async {
      final id = playlists.seed('Vacía');
      final remote = FakeSourceLookup();

      final items = await GetPlaylistSongs(
        playlists,
        lookup(library: [localA], remoteLookup: remote),
      )(id, [localA]);

      expect(items, isEmpty);
      expect(remote.requests, isEmpty);
    });
  });
}
