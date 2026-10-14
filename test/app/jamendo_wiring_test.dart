import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:taki/core/lookup/song_lookup_providers.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:taki/app/jamendo_wiring.dart';
import 'package:taki/core/artwork/http_remote_artwork_loader.dart';
import 'package:taki/core/database/taki_database.dart';
import 'package:taki/core/domain/entities/artwork_reference.dart';
import 'package:taki/core/domain/entities/local_music_identity.dart';
import 'package:taki/core/domain/entities/music_identity.dart';
import 'package:taki/core/domain/entities/playback_resolution_exception.dart';
import 'package:taki/core/domain/entities/playback_resource.dart';
import 'package:taki/core/domain/ports/artwork_http_client.dart';
import 'package:taki/core/domain/services/source_playback_resolver.dart';
import 'package:taki/features/jamendo/domain/entities/jamendo_track.dart';
import 'package:taki/features/jamendo/domain/services/jamendo_song_mapper.dart';
import 'package:taki/features/jamendo/infrastructure/jamendo_credentials.dart';
import 'package:taki/features/library/infrastructure/sqflite_favorites_repository.dart';

import '../helpers/jamendo_fakes.dart';
import '../helpers/library_fakes.dart';
import '../helpers/universal_song.dart';


void main() {
  lookupWiringTests();
  catalogSourcesWiringTests();
  final jid = MusicIdentity('jamendo', '2291526');

  group('SourcePlaybackResolver / wiring', () {
    test('local → LocalUriResource (comportamiento local intacto)', () async {
      final resolver = buildPlaybackResolver(null);
      final resource = await resolver.resolve(buildSong(id: 3));
      expect(resource, isA<LocalUriResource>());
    });

    test('jamendo → RemoteUriResource', () async {
      final api = FakeJamendoApi(tracks: [buildTrack('2291526', audio: 'https://a/x')]);
      final resolver = buildPlaybackResolver(buildJamendoServicesFor(api));
      expect(await resolver.resolve(buildUniversalSong(jid)),
          RemoteUriResource('https://a/x'));
    });

    test('fuente desconocida → IdentityNotFound', () async {
      final resolver = buildPlaybackResolver(
          buildJamendoServicesFor(FakeJamendoApi()));
      await expectLater(
        resolver.resolve(buildUniversalSong(MusicIdentity('otra', '1'))),
        throwsA(isA<IdentityNotFound>()),
      );
    });

    test('sin Jamendo configurado, jamendo es desconocida', () async {
      await expectLater(
        buildPlaybackResolver(null).resolve(buildUniversalSong(jid)),
        throwsA(isA<IdentityNotFound>()),
      );
    });

    test('SourcePlaybackResolver enruta solo por source', () async {
      final r = SourcePlaybackResolver({});
      await expectLater(
          r.resolve(buildUniversalSong(localMusicIdentity(1))),
          throwsA(isA<IdentityNotFound>()));
    });
  });

  group('credenciales', () {
    test('sin client_id no hay Jamendo', () {
      for (final id in [null, '', '  ']) {
        expect(
          buildJamendoServices(FakeHttp(),
              credentials: StaticJamendoCredentials(id)),
          isNull,
        );
      }
    });

    test('con client_id fake se construye y usa el transporte', () async {
      final http = FakeHttp();
      final services = buildJamendoServices(http,
          credentials: const StaticJamendoCredentials(fakeClientId))!;
      final result = await services.lookup
          .findAll([jid, MusicIdentity('jamendo', '2318689')]);
      expect(result.found.keys.map((i) => i.externalId),
          {'2291526', '2318689'});
      expect(http.requests.single.queryParameters['client_id'], fakeClientId);
    });

    test('sin --dart-define no hay client_id', () {
      expect(const EnvironmentJamendoCredentials().clientId, isNull);
    });
  });

  group('artwork', () {
    test('Jamendo resuelve con la referencia que ya trae la canción', () async {
      final song = buildUniversalSong(
        jid,
        artwork: jamendoArtworkReference('https://usercontent.jamendo.com?id=1'),
      );
      final resolver = buildArtworkResolver(buildJamendoServicesFor(FakeJamendoApi()));
      expect(await resolver.resolve(song), song.artwork);
    });

    test('sin Jamendo, la fuente jamendo no tiene artwork', () async {
      final song = buildUniversalSong(
        jid,
        artwork: jamendoArtworkReference('https://usercontent.jamendo.com?id=1'),
      );
      expect(await buildArtworkResolver(null).resolve(song),
          isA<UnavailableArtworkReference>());
    });

    test('el loader HTTP existente descarga la portada con width=300', () async {
      final client = _ImageHttp();
      final ref = jamendoArtworkReference(
        'https://usercontent.jamendo.com?type=album&id=620618&width=300&trackid=1',
      ) as RemoteArtworkReference;
      final bytes = await HttpRemoteArtworkLoader(client).load(ref, size: 300);
      expect(bytes, isNotNull);
      expect(client.requested.single.host, 'usercontent.jamendo.com');
      expect(client.requested.single.queryParameters['width'], '300');
      // La URL de artwork nunca lleva el client_id.
      expect(client.requested.single.toString(), isNot(contains('client_id')));
    });
  });

  group('MusicIdentity("jamendo", id) por las abstracciones existentes', () {
    setUpAll(sqfliteFfiInit);

    test('viaja por favoritos (SQLite) sin cambiar el esquema', () async {
      final db = await TakiDatabase.open(
        factory: databaseFactoryFfi,
        path: inMemoryDatabasePath,
      );
      final repo = SqfliteFavoritesRepository(() async => db);
      final song = songFromJamendoTrack(buildTrack('0042'));
      await repo.add(song);

      final entry = (await repo.getFavorites()).single;
      expect(entry.musicIdentity, MusicIdentity('jamendo', '0042'));
      expect(entry.musicIdentity.externalId, '0042');

      // Nada del audio ni de la atribución llega a la base.
      final rows = await db.query('favorites');
      expect(rows.single.values.join('|'), isNot(contains('audio.example')));
      await repo.dispose();
      await db.close();
    });

    test('la fuente es la etiqueta exacta "jamendo"', () {
      expect(jamendoSource, 'jamendo');
    });
  });
}

class _ImageHttp implements ArtworkHttpClient {
  final List<Uri> requested = [];

  @override
  Future<ArtworkHttpResponse> get(
    Uri uri, {
    required Duration timeout,
    required int maxBytes,
  }) async {
    requested.add(uri);
    return ArtworkHttpResponse(
      200,
      Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 0, 0]),
    );
  }
}

/// El cableado real: `jamendoServicesProvider` → `songLookupProvider`.
void lookupWiringTests() {
  group('songLookupProvider con Jamendo', () {
    late MockMediaPermission permission;
    late MockSongRepository songs;

    setUp(() {
      permission = MockMediaPermission();
      when(permission.isGranted).thenAnswer((_) async => true);
      when(permission.isPermanentlyDenied).thenAnswer((_) async => false);
      songs = MockSongRepository();
      when(songs.getSongs).thenAnswer((_) async => [buildSong(id: 5)]);
    });

    ProviderContainer container(JamendoServices? jamendo) {
      final c = ProviderContainer(overrides: [
        ...libraryOverrides(permission: permission, songs: songs),
        jamendoServicesProvider.overrideWithValue(jamendo),
      ]);
      addTearDown(c.dispose);
      return c;
    }

    test('con Jamendo resuelve identidades jamendo y locales', () async {
      final api = FakeJamendoApi(tracks: [buildTrack('7')]);
      final result = await container(buildJamendoServicesFor(api))
          .read(songLookupProvider)
          .findAll([MusicIdentity('jamendo', '7'), localMusicIdentity(5)]);
      expect(result.found.keys,
          {MusicIdentity('jamendo', '7'), localMusicIdentity(5)});
    });

    test('sin Jamendo, la identidad jamendo es unsupported', () async {
      final result = await container(null)
          .read(songLookupProvider)
          .findAll([MusicIdentity('jamendo', '7'), localMusicIdentity(5)]);
      expect(result.unsupported, {MusicIdentity('jamendo', '7')});
      expect(result.found.keys, {localMusicIdentity(5)});
    });
  });
}

void catalogSourcesWiringTests() {
  group('buildCatalogSources', () {
    test('sin Jamendo no hay ningún catálogo', () {
      final sources = buildCatalogSources(null);
      expect(sources.isAvailable, isFalse);
      expect(sources.available, isEmpty);
    });

    test('con Jamendo se registra con su etiqueta', () {
      final jamendo = buildJamendoServicesFor(FakeJamendoApi());
      final sources = buildCatalogSources(jamendo);
      expect(sources.isAvailable, isTrue);
      expect(sources.available.single.source, 'jamendo');
      expect(sources.available.single.label, 'Jamendo');
      expect(sources.searchIn('jamendo'), same(jamendo.search));
    });
  });
}
