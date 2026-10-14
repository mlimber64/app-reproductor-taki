import 'package:flutter_test/flutter_test.dart';
import 'package:taki/app/audius_wiring.dart';
import 'package:taki/app/jamendo_wiring.dart';
import 'package:taki/core/domain/entities/catalog_search.dart';
import 'package:taki/core/domain/entities/catalog_section.dart';
import 'package:taki/core/domain/entities/music_identity.dart';
import 'package:taki/core/domain/entities/playback_resolution_exception.dart';
import 'package:taki/core/domain/entities/playback_resource.dart';
import 'package:taki/core/domain/entities/song_lookup_failure.dart';
import 'package:taki/core/domain/entities/artwork_reference.dart';
import 'package:taki/features/audius/domain/entities/audius_exception.dart';
import 'package:taki/features/audius/domain/ports/audius_api.dart';
import 'package:taki/features/audius/domain/services/audius_attribution_lookup.dart';
import 'package:taki/features/audius/domain/services/audius_catalog_browse.dart';
import 'package:taki/features/audius/domain/services/audius_catalog_search.dart';
import 'package:taki/features/audius/domain/services/audius_playback_resolver.dart';
import 'package:taki/features/audius/domain/services/audius_song_lookup.dart';
import 'package:taki/features/audius/domain/services/audius_song_mapper.dart';

import '../../helpers/audius_fakes.dart';
import '../../helpers/universal_song.dart';

void main() {
  group('attribution', () {
    test('page link comes from the permalink, license as declared', () {
      final attribution = buildAudiusTrack('t1',
              permalink: '/artist/song', license: 'CC BY 4.0')
          .attribution;

      expect(attribution.providerName, 'Audius');
      expect(attribution.pageUrl, Uri.parse('https://audius.co/artist/song'));
      expect(attribution.licenseName, 'CC BY 4.0');
      expect(attribution.licenseUrl, isNull);
    });

    test('a missing license is not invented', () {
      final attribution = buildAudiusTrack('t1', license: null).attribution;
      expect(attribution.licenseName, isNull);
    });

    test('a permalink that is not a path gives no link', () {
      for (final bad in ['//evil.example/x', 'https://evil.example', '', '/']) {
        final attribution = buildAudiusTrack('t1', permalink: bad).attribution;
        expect(attribution.pageUrl, isNull, reason: bad);
      }
    });
  });

  group('song mapper', () {
    test('keeps identity, durations and a remote cover', () {
      final song = songFromAudiusTrack(buildAudiusTrack('t1'));

      expect(song.musicIdentity, MusicIdentity('audius', 't1'));
      expect(song.durationMs, 120000);
      expect(song.artwork, isA<RemoteArtworkReference>());
    });

    test('without cover the artwork is unavailable', () {
      expect(audiusArtworkReference(null), isA<UnavailableArtworkReference>());
      expect(audiusArtworkReference('ftp://x/y'),
          isA<UnavailableArtworkReference>());
    });
  });

  group('AudiusCatalogSearch', () {
    test('folds artist and tag into the text and returns attributions',
        () async {
      final api = FakeAudiusApi(tracks: [buildAudiusTrack('t1')]);
      final page = await AudiusCatalogSearch(api).search(
        CatalogSearchQuery(text: ' lofi ', artist: 'Bob', limit: 20),
      );

      expect(api.searches.single, 'lofi Bob');
      expect(page.songs.single.musicIdentity, MusicIdentity('audius', 't1'));
      expect(page.attributions, contains(MusicIdentity('audius', 't1')));
    });

    test('an API error becomes CatalogSearchFailure with the source',
        () async {
      final api = FakeAudiusApi(error: const AudiusNetworkException('down'));

      await expectLater(
        AudiusCatalogSearch(api).search(
          CatalogSearchQuery(text: 'x', limit: 20),
        ),
        throwsA(isA<CatalogSearchFailure>()
            .having((f) => f.source, 'source', 'audius')),
      );
    });
  });

  group('AudiusCatalogBrowse', () {
    late FakeAudiusApi api;
    late AudiusCatalogBrowse browse;

    setUp(() {
      api = FakeAudiusApi(tracks: [buildAudiusTrack('t1')]);
      browse = AudiusCatalogBrowse(api);
    });

    test('week and month use the trending charts', () async {
      await browse.section(CatalogSection.popularThisWeek);
      await browse.section(CatalogSection.popularThisMonth);

      expect(api.trendingCalls.map((c) => c.window),
          [AudiusTrendingWindow.week, AudiusTrendingWindow.month]);
      expect(api.trendingCalls.every((c) => c.genre == null), isTrue);
    });

    test('new releases use the underground chart', () async {
      await browse.section(CatalogSection.newReleases);

      expect(api.undergroundCalls, 1);
      expect(api.trendingCalls, isEmpty);
    });

    test('every genre of the screen maps to an Audius genre', () async {
      for (final tag in audiusGenres.keys) {
        await browse.section(CatalogSection.genre(tag));
      }

      expect(api.trendingCalls.map((c) => c.genre),
          audiusGenres.values.toList());
    });

    test('an unknown genre answers an empty page without asking', () async {
      final page = await browse.section(CatalogSection.genre('polka'));

      expect(page.songs, isEmpty);
      expect(api.trendingCalls, isEmpty);
    });

    test('an API error becomes CatalogSearchFailure', () async {
      api.error = const AudiusNetworkException('down');

      await expectLater(
        browse.section(CatalogSection.popularThisWeek),
        throwsA(isA<CatalogSearchFailure>()),
      );
    });
  });

  group('AudiusPlaybackResolver', () {
    final identity = MusicIdentity('audius', 't1');

    test('known track → remote stream URL', () async {
      final api = FakeAudiusApi(tracks: [buildAudiusTrack('t1')]);
      final resolver = AudiusPlaybackResolver(api);

      final resource = await resolver.resolve(buildUniversalSong(identity));

      expect(resource, RemoteUriResource('https://stream.example/t1'));
    });

    test('a track the API does not return is IdentityNotFound', () async {
      final resolver = AudiusPlaybackResolver(FakeAudiusApi());

      await expectLater(
        resolver.resolve(buildUniversalSong(identity)),
        throwsA(isA<IdentityNotFound>()),
      );
    });

    test('another source is IdentityNotFound', () async {
      final resolver = AudiusPlaybackResolver(FakeAudiusApi());

      await expectLater(
        resolver.resolve(buildUniversalSong(MusicIdentity('jamendo', '1'))),
        throwsA(isA<IdentityNotFound>()),
      );
    });

    test('an API error is PlaybackResolutionError and is not remembered',
        () async {
      final api = FakeAudiusApi(
        tracks: [buildAudiusTrack('t1')],
        error: const AudiusNetworkException('down'),
      );
      final resolver = AudiusPlaybackResolver(api);

      await expectLater(
        resolver.resolve(buildUniversalSong(identity)),
        throwsA(isA<PlaybackResolutionError>()),
      );

      api.error = null;
      expect(await resolver.resolve(buildUniversalSong(identity)),
          isA<RemoteUriResource>());
    });

    test('two concurrent resolves share one lookup', () async {
      final api = FakeAudiusApi(tracks: [buildAudiusTrack('t1')]);
      final resolver = AudiusPlaybackResolver(api);
      final song = buildUniversalSong(identity);

      await Future.wait([resolver.resolve(song), resolver.resolve(song)]);

      expect(api.idCalls, 1);
    });
  });

  group('AudiusSongLookup', () {
    test('splits found, missing and unsupported', () async {
      final api = FakeAudiusApi(tracks: [buildAudiusTrack('t1')]);
      final result = await AudiusSongLookup(api).findAll([
        MusicIdentity('audius', 't1'),
        MusicIdentity('audius', 'gone'),
        MusicIdentity('jamendo', '9'),
      ]);

      expect(result.found.keys, [MusicIdentity('audius', 't1')]);
      expect(result.missing, {MusicIdentity('audius', 'gone')});
      expect(result.unsupported, {MusicIdentity('jamendo', '9')});
    });

    test('an API error is SongLookupFailure, not missing', () async {
      final api = FakeAudiusApi(error: const AudiusNetworkException('down'));

      await expectLater(
        AudiusSongLookup(api).findAll([MusicIdentity('audius', 't1')]),
        throwsA(isA<SongLookupFailure>()),
      );
    });
  });

  group('AudiusAttributionLookup', () {
    test('found for known tracks, absent for the rest', () async {
      final api = FakeAudiusApi(tracks: [buildAudiusTrack('t1')]);
      final result = await AudiusAttributionLookup(api).findAll([
        MusicIdentity('audius', 't1'),
        MusicIdentity('audius', 'gone'),
        MusicIdentity('local', '5'),
      ]);

      expect(result.found.keys, [MusicIdentity('audius', 't1')]);
      expect(result.absent,
          {MusicIdentity('audius', 'gone'), MusicIdentity('local', '5')});
    });
  });

  group('wiring', () {
    test('Audius registers search, browse, playback and lookups', () async {
      final audius = buildAudiusServicesFor(
        FakeAudiusApi(tracks: [buildAudiusTrack('t1')]),
      );

      final sources = buildCatalogSources(null, audius: audius);
      expect(sources.available.map((i) => i.source), ['audius']);
      expect(sources.available.single.label, 'Audius');
      expect(sources.browseIn('audius'), isNotNull);

      final playback = buildPlaybackResolver(null, audius: audius);
      expect(
        await playback.resolve(
            buildUniversalSong(MusicIdentity('audius', 't1'))),
        isA<RemoteUriResource>(),
      );

      final attribution = await buildAttributionLookup(null, audius: audius)
          .findAll([MusicIdentity('audius', 't1')]);
      expect(attribution.found, hasLength(1));
    });

    test('without Audius its identities are unknown', () async {
      await expectLater(
        buildPlaybackResolver(null).resolve(
            buildUniversalSong(MusicIdentity('audius', 't1'))),
        throwsA(isA<IdentityNotFound>()),
      );
    });
  });
}
