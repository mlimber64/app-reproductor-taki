import 'package:flutter_test/flutter_test.dart';
import 'package:taki/core/domain/entities/artwork_reference.dart';
import 'package:taki/core/domain/entities/catalog_search.dart';
import 'package:taki/core/domain/entities/local_music_identity.dart';
import 'package:taki/core/domain/entities/music_identity.dart';
import 'package:taki/core/domain/entities/playback_resolution_exception.dart';
import 'package:taki/core/domain/entities/playback_resource.dart';
import 'package:taki/core/domain/entities/song_lookup_failure.dart';
import 'package:taki/core/domain/services/source_song_lookup.dart';
import 'package:taki/features/jamendo/domain/entities/jamendo_exception.dart';
import 'package:taki/features/jamendo/domain/entities/jamendo_track.dart';
import 'package:taki/features/jamendo/domain/services/caching_jamendo_api.dart';
import 'package:taki/features/jamendo/domain/services/jamendo_audio_cache.dart';
import 'package:taki/features/jamendo/domain/services/jamendo_catalog_search.dart';
import 'package:taki/features/jamendo/domain/services/jamendo_playback_resolver.dart';
import 'package:taki/features/jamendo/domain/services/jamendo_song_lookup.dart';
import 'package:taki/features/jamendo/domain/services/jamendo_song_mapper.dart';

import '../../helpers/jamendo_fakes.dart';
import '../../helpers/universal_song.dart';

MusicIdentity jid(String id) => MusicIdentity('jamendo', id);

void main() {
  group('mapeo JamendoTrack → Song', () {
    test('identidad, textos, duración y artwork', () {
      final song = songFromJamendoTrack(buildTrack('5', duration: 144));
      expect(song.musicIdentity, jid('5'));
      expect(song.musicIdentity.source, 'jamendo');
      expect(song.title, 'Pista');
      expect(song.artist, 'Artista');
      expect(song.album, 'Álbum');
      expect(song.durationMs, 144000);
      expect(song.artwork, isA<RemoteArtworkReference>());
    });

    test('el id se conserva sin normalizar (ceros, mayúsculas)', () {
      expect(songFromJamendoTrack(buildTrack('0042')).musicIdentity,
          jid('0042'));
      expect(songFromJamendoTrack(buildTrack('AbC')).musicIdentity, jid('AbC'));
    });

    test('artista y álbum vacíos o en blanco son null', () {
      final song = songFromJamendoTrack(buildTrack('1', artist: ' ', album: ''));
      expect(song.artist, isNull);
      expect(song.album, isNull);
      final none = songFromJamendoTrack(buildTrack('1', artist: null, album: null));
      expect(none.artist, isNull);
      expect(none.album, isNull);
    });

    test('duración 0 o negativa → 0 ms', () {
      expect(songFromJamendoTrack(buildTrack('1', duration: 0)).durationMs, 0);
      expect(songFromJamendoTrack(buildTrack('1', duration: -5)).durationMs, 0);
      expect(songFromJamendoTrack(buildTrack('1', duration: 1)).durationMs, 1000);
    });

    test('Song no contiene audio, shareurl ni licencia', () {
      final track = buildTrack('9', audio: 'https://audio.example/secret');
      final text = songFromJamendoTrack(track).toString() +
          songFromJamendoTrack(track).props.join('|');
      expect(text, isNot(contains('audio.example')));
      expect(text, isNot(contains('jamendo.com/track')));
      expect(text, isNot(contains('creativecommons')));
    });

    test('la atribución se conserva en el track, no en Song', () {
      final track = buildTrack('9');
      expect(track.attribution.pageUrl, Uri.parse('https://www.jamendo.com/track/9'));
      expect(track.attribution.licenseUrl.toString(), contains('creativecommons'));
    });
  });

  group('artwork', () {
    test('fija width=300 y conserva el resto de la query', () {
      final art = jamendoArtworkReference(
        'https://usercontent.jamendo.com?type=album&id=620618&width=999&trackid=1',
      ) as RemoteArtworkReference;
      final uri = Uri.parse(art.url);
      expect(uri.host, 'usercontent.jamendo.com');
      expect(uri.queryParameters, {
        'type': 'album',
        'id': '620618',
        'width': '300',
        'trackid': '1',
      });
      expect(art.width, 300);
      expect(art.height, 300);
      expect(jamendoArtworkWidth, 300);
    });

    test('añade width si faltaba', () {
      final art = jamendoArtworkReference(
          'https://usercontent.jamendo.com?type=album&id=1') as RemoteArtworkReference;
      expect(Uri.parse(art.url).queryParameters['width'], '300');
    });

    test('width explícito', () {
      final art = jamendoArtworkReference(
          'https://usercontent.jamendo.com?type=album&id=1',
          width: 600) as RemoteArtworkReference;
      expect(Uri.parse(art.url).queryParameters['width'], '600');
      expect(art.width, 600);
    });

    test('sin imagen o URL inválida → no disponible', () {
      for (final bad in [null, '', '  ', 'ftp://x/y.jpg', 'no es url', '/relativa', 'https:///sin-host']) {
        expect(jamendoArtworkReference(bad), isA<UnavailableArtworkReference>(),
            reason: '$bad');
      }
    });

    test('http también es válido', () {
      expect(jamendoArtworkReference('http://usercontent.jamendo.com?id=1'),
          isA<RemoteArtworkReference>());
    });
  });

  group('JamendoSongLookup', () {
    final tracks = [buildTrack('1'), buildTrack('2'), buildTrack('3')];

    test('found y missing en una sola llamada', () async {
      final api = FakeJamendoApi(tracks: tracks);
      final result =
          await JamendoSongLookup(api).findAll([jid('1'), jid('2'), jid('99')]);
      expect(result.found.keys, {jid('1'), jid('2')});
      expect(result.found[jid('1')]!.title, 'Pista');
      expect(result.missing, {jid('99')});
      expect(result.unsupported, isEmpty);
      expect(api.idCalls, hasLength(1));
      expect(api.idCalls.single, unorderedEquals(['1', '2', '99']));
    });

    test('duplicados se consultan una vez', () async {
      final api = FakeJamendoApi(tracks: tracks);
      final result =
          await JamendoSongLookup(api).findAll([jid('1'), jid('1'), jid('1')]);
      expect(result.found.keys, {jid('1')});
      expect(api.idCalls.single, ['1']);
    });

    test('otras fuentes son unsupported y no se consultan', () async {
      final api = FakeJamendoApi(tracks: tracks);
      final result = await JamendoSongLookup(api)
          .findAll([jid('1'), localMusicIdentity(5), MusicIdentity('otra', '1')]);
      expect(result.unsupported, {localMusicIdentity(5), MusicIdentity('otra', '1')});
      expect(result.found.keys, {jid('1')});
      expect(api.idCalls.single, ['1']);
    });

    test('solo otras fuentes: sin llamada', () async {
      final api = FakeJamendoApi(tracks: tracks);
      final result =
          await JamendoSongLookup(api).findAll([localMusicIdentity(5)]);
      expect(result.unsupported, {localMusicIdentity(5)});
      expect(api.idCalls, isEmpty);
    });

    test('lista vacía: sin llamada y resultado vacío', () async {
      final api = FakeJamendoApi();
      final result = await JamendoSongLookup(api).findAll(const []);
      expect(result.found, isEmpty);
      expect(result.missing, isEmpty);
      expect(result.unsupported, isEmpty);
      expect(api.idCalls, isEmpty);
    });

    test('identidad incorrecta devuelta por la API → SongLookupFailure', () async {
      final api = FakeJamendoApi(tracks: [buildTrack('2')]);
      api.tracks = [buildTrack('2')];
      final lookup = JamendoSongLookup(_Echo(api, ['2']));
      await expectLater(
        lookup.findAll([jid('1')]),
        throwsA(isA<SongLookupFailure>()
            .having((e) => e.source, 'source', 'jamendo')),
      );
    });

    test('el id no se normaliza: "0042" pedido, "42" devuelto → fallo', () async {
      final lookup = JamendoSongLookup(_Echo(FakeJamendoApi(tracks: [buildTrack('42')]), ['42']));
      await expectLater(
          lookup.findAll([jid('0042')]), throwsA(isA<SongLookupFailure>()));
    });

    test('errores de la API → SongLookupFailure con la fuente', () async {
      for (final error in <Object>[
        const JamendoNetworkException('x'),
        const JamendoInvalidClientException(),
      ]) {
        final lookup = JamendoSongLookup(FakeJamendoApi(error: error));
        await expectLater(
          lookup.findAll([jid('1')]),
          throwsA(isA<SongLookupFailure>()
              .having((e) => e.source, 'source', 'jamendo')
              .having((e) => e.cause, 'cause', error)),
        );
      }
    });

    test('un error inesperado no filtra el objeto original', () async {
      final lookup = JamendoSongLookup(FakeJamendoApi(error: StateError('secreto')));
      await expectLater(
        lookup.findAll([jid('1')]),
        throwsA(isA<SongLookupFailure>()
            .having((e) => e.cause, 'cause', StateError)),
      );
    });

    test('dentro de SourceSongLookup el fallo se propaga (contrato 3.0)', () async {
      final router = SourceSongLookup({
        'jamendo': JamendoSongLookup(
            FakeJamendoApi(error: const JamendoNetworkException('x'))),
      });
      await expectLater(
          router.findAll([jid('1')]), throwsA(isA<SongLookupFailure>()));
    });

    test('dentro de SourceSongLookup resuelve found/missing', () async {
      final router = SourceSongLookup({
        'jamendo': JamendoSongLookup(FakeJamendoApi(tracks: tracks)),
      });
      final result = await router.findAll([jid('1'), jid('9'), localMusicIdentity(1)]);
      expect(result.found.keys, {jid('1')});
      expect(result.missing, {jid('9')});
      expect(result.unsupported, {localMusicIdentity(1)});
    });
  });

  group('JamendoPlaybackResolver', () {
    late FakeJamendoApi api;
    late JamendoAudioCache cache;
    late JamendoPlaybackResolver resolver;
    late DateTime now;

    setUp(() {
      now = DateTime(2026, 10, 1, 12);
      api = FakeJamendoApi(tracks: [buildTrack('1', audio: 'https://a/1')]);
      cache = JamendoAudioCache(clock: () => now);
      resolver = JamendoPlaybackResolver(api, cache);
    });

    Future<PlaybackResource> resolve(String id) => resolver
        .resolve(buildUniversalSong(jid(id)));

    test('devuelve RemoteUriResource con el audio', () async {
      expect(await resolve('1'), RemoteUriResource('https://a/1'));
    });

    test('segunda resolución sale de la caché en memoria', () async {
      await resolve('1');
      final second = await resolve('1');
      expect(second, RemoteUriResource('https://a/1'));
      expect(api.idCalls, hasLength(1));
    });

    test('la caché caduca por TTL', () async {
      await resolve('1');
      now = now.add(const Duration(minutes: 9, seconds: 59));
      await resolve('1');
      expect(api.idCalls, hasLength(1));
      now = now.add(const Duration(seconds: 1));
      await resolve('1');
      expect(api.idCalls, hasLength(2));
    });

    test('la clave es la identidad, no el título', () async {
      api.tracks = [buildTrack('1', audio: 'https://a/1'), buildTrack('2', audio: 'https://a/2')];
      final a = await resolver.resolve(buildUniversalSong(jid('1'), title: 'X'));
      final b = await resolver.resolve(buildUniversalSong(jid('2'), title: 'X'));
      expect(a, RemoteUriResource('https://a/1'));
      expect(b, RemoteUriResource('https://a/2'));
    });

    test('fuente distinta → IdentityNotFound sin llamar', () async {
      await expectLater(
        resolver.resolve(buildUniversalSong(localMusicIdentity(1))),
        throwsA(isA<IdentityNotFound>()),
      );
      expect(api.idCalls, isEmpty);
    });

    test('id inexistente → IdentityNotFound', () async {
      await expectLater(resolve('404'), throwsA(isA<IdentityNotFound>()));
    });

    test('track sin audio → UnavailableResource', () async {
      api.tracks = [
        const JamendoTrack(id: '1', name: 'x'),
        const JamendoTrack(id: '2', name: 'x', audio: '  '),
      ];
      expect(await resolve('1'), isA<UnavailableResource>());
      expect(await resolve('2'), isA<UnavailableResource>());
    });

    test('error de la API → PlaybackResolutionError', () async {
      api.error = const JamendoNetworkException('x');
      await expectLater(resolve('1'), throwsA(isA<PlaybackResolutionError>()));
      api.error = StateError('x');
      await expectLater(
        resolve('1'),
        throwsA(isA<PlaybackResolutionError>()
            .having((e) => e.cause, 'cause', StateError)),
      );
    });

    test('un fallo no se cachea', () async {
      api.error = const JamendoNetworkException('x');
      await expectLater(resolve('1'), throwsA(isA<PlaybackResolutionError>()));
      api.error = null;
      expect(await resolve('1'), RemoteUriResource('https://a/1'));
    });

    test('no mezcla con un id de otro track devuelto por la API', () async {
      final wrong = _Echo(FakeJamendoApi(tracks: [buildTrack('2')]), ['2']);
      await expectLater(
        JamendoPlaybackResolver(wrong, cache)
            .resolve(buildUniversalSong(jid('1'))),
        throwsA(isA<IdentityNotFound>()),
      );
    });
  });

  group('JamendoAudioCache', () {
    test('capacidad: expulsa la más antigua', () {
      final cache = JamendoAudioCache(capacity: 2);
      cache.put(jid('1'), 'a');
      cache.put(jid('2'), 'b');
      cache.put(jid('3'), 'c');
      expect(cache.get(jid('1')), isNull);
      expect(cache.get(jid('2')), 'b');
      expect(cache.get(jid('3')), 'c');
    });

    test('reponer refresca la posición y el valor', () {
      final cache = JamendoAudioCache(capacity: 2);
      cache.put(jid('1'), 'a');
      cache.put(jid('2'), 'b');
      cache.put(jid('1'), 'a2');
      cache.put(jid('3'), 'c');
      expect(cache.get(jid('2')), isNull);
      expect(cache.get(jid('1')), 'a2');
    });

    test('clear vacía', () {
      final cache = JamendoAudioCache()..put(jid('1'), 'a');
      cache.clear();
      expect(cache.get(jid('1')), isNull);
    });

    test('es solo memoria: el TTL por defecto es de 10 minutos', () {
      expect(JamendoAudioCache().ttl, const Duration(minutes: 10));
    });
  });

  group('CachingJamendoApi', () {
    test('búsqueda y lote alimentan la caché', () async {
      final api = FakeJamendoApi(tracks: [buildTrack('1', audio: 'https://a/1')]);
      final cache = JamendoAudioCache();
      final caching = CachingJamendoApi(api, cache);

      await caching.searchTracks(name: 'x', limit: 1, offset: 0);
      expect(cache.get(jid('1')), 'https://a/1');

      cache.clear();
      await caching.tracksByIds(['1']);
      expect(cache.get(jid('1')), 'https://a/1');
    });

    test('no cachea audio en blanco', () async {
      final api = FakeJamendoApi(
          tracks: [const JamendoTrack(id: '1', name: 'x', audio: '   ')]);
      final cache = JamendoAudioCache();
      await CachingJamendoApi(api, cache).tracksByIds(['1']);
      expect(cache.get(jid('1')), isNull);
    });

    test('pasa los argumentos y no cachea audio vacío', () async {
      final api = FakeJamendoApi(tracks: [const JamendoTrack(id: '1', name: 'x')]);
      final cache = JamendoAudioCache();
      await CachingJamendoApi(api, cache)
          .searchTracks(name: 'n', artistName: 'a', tag: 't', limit: 7, offset: 3);
      expect(api.searchArgs.single,
          {'name': 'n', 'artistName': 'a', 'tag': 't', 'limit': 7, 'offset': 3});
      expect(cache.get(jid('1')), isNull);
    });

    test('una búsqueda evita la llamada de playback', () async {
      final api = FakeJamendoApi(tracks: [buildTrack('1', audio: 'https://a/1')]);
      final cache = JamendoAudioCache();
      await CachingJamendoApi(api, cache).searchTracks(name: 'x', limit: 1, offset: 0);
      final r = JamendoPlaybackResolver(CachingJamendoApi(api, cache), cache);
      await r.resolve(buildUniversalSong(jid('1')));
      expect(api.idCalls, isEmpty);
    });
  });

  group('JamendoCatalogSearch', () {
    test('traduce la consulta y mapea a Song', () async {
      final api = FakeJamendoApi(tracks: [buildTrack('1'), buildTrack('2')])
        ..hasMore = true;
      final page = await JamendoCatalogSearch(api).search(CatalogSearchQuery(
        text: 'piano',
        artist: 'A',
        tag: 't',
        limit: 2,
        offset: 4,
      ));
      expect(page.songs.map((s) => s.musicIdentity), [jid('1'), jid('2')]);
      expect(page.hasMore, isTrue);
      expect(api.searchArgs.single,
          {'name': 'piano', 'artistName': 'A', 'tag': 't', 'limit': 2, 'offset': 4});
    });

    test('sin resultados', () async {
      final page = await JamendoCatalogSearch(FakeJamendoApi())
          .search(CatalogSearchQuery(text: 'zzz'));
      expect(page.songs, isEmpty);
      expect(page.hasMore, isFalse);
    });

    test('los errores de Jamendo salen como CatalogSearchFailure', () async {
      final search = JamendoCatalogSearch(
          FakeJamendoApi(error: const JamendoInvalidClientException()));
      await expectLater(
        search.search(CatalogSearchQuery(text: 'x')),
        throwsA(isA<CatalogSearchFailure>()
            .having((e) => e.source, 'source', 'jamendo')),
      );
    });
  });

  group('CatalogSearchQuery', () {
    test('necesita un criterio no vacío', () {
      expect(() => CatalogSearchQuery(), throwsArgumentError);
      expect(() => CatalogSearchQuery(text: ' ', artist: '', tag: null),
          throwsArgumentError);
      expect(CatalogSearchQuery(artist: 'a').artist, 'a');
      expect(CatalogSearchQuery(tag: 't').tag, 't');
    });

    test('valida limit y offset', () {
      expect(() => CatalogSearchQuery(text: 'a', limit: 0), throwsArgumentError);
      expect(() => CatalogSearchQuery(text: 'a', offset: -1), throwsArgumentError);
      expect(CatalogSearchQuery(text: 'a', limit: 1, offset: 0).limit, 1);
    });
  });
}

/// Fuerza a la API a devolver `tracks` aunque no coincidan con lo pedido, para
/// simular una respuesta con otra identidad.
class _Echo extends FakeJamendoApi {
  _Echo(FakeJamendoApi base, this.returned) : super(tracks: base.tracks);

  final List<String> returned;

  @override
  Future<List<JamendoTrack>> tracksByIds(Iterable<String> ids) async => [
        for (final t in tracks)
          if (returned.contains(t.id)) t,
      ];
}
