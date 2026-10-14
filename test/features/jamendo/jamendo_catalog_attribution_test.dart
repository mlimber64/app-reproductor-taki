import 'package:flutter_test/flutter_test.dart';
import 'package:taki/core/domain/entities/catalog_search.dart';
import 'package:taki/core/domain/entities/music_identity.dart';
import 'package:taki/features/jamendo/domain/entities/jamendo_track.dart';
import 'package:taki/features/jamendo/domain/services/jamendo_catalog_search.dart';

import '../../helpers/jamendo_fakes.dart';

void main() {
  MusicIdentity jid(String id) => MusicIdentity('jamendo', id);

  group('JamendoCatalogSearch conserva la atribución (C1)', () {
    test('cada canción trae la atribución de su track', () async {
      final api = FakeJamendoApi(tracks: [buildTrack('1'), buildTrack('2')]);
      final page = await JamendoCatalogSearch(api)
          .search(CatalogSearchQuery(text: 'x'));

      expect(page.attributions.keys, {jid('1'), jid('2')});
      final first = page.attributionOf(page.songs.first)!;
      expect(first.identity, jid('1'));
      expect(first.providerName, jamendoProviderName);
      expect(first.pageUrl, Uri.parse('https://www.jamendo.com/track/1'));
      expect(first.licenseName, 'CC BY-NC-ND 3.0');
      expect(page.attributionOf(page.songs.last)!.identity, jid('2'));
    });

    test('es la misma que expone el track', () async {
      final track = buildTrack('7');
      final page = await JamendoCatalogSearch(FakeJamendoApi(tracks: [track]))
          .search(CatalogSearchQuery(text: 'x'));
      expect(page.attributions[jid('7')], track.attribution);
    });

    test('un track sin datos de atribución llega con la atribución incompleta',
        () async {
      final api = FakeJamendoApi(tracks: [const JamendoTrack(id: '9', name: 'n')]);
      final page = await JamendoCatalogSearch(api)
          .search(CatalogSearchQuery(text: 'x'));
      final attribution = page.attributionOf(page.songs.single)!;
      expect(attribution.isComplete, isFalse);
      expect(attribution.pageUrl, isNull);
    });

    test('sin resultados: sin atribuciones', () async {
      final page = await JamendoCatalogSearch(FakeJamendoApi())
          .search(CatalogSearchQuery(text: 'x'));
      expect(page.attributions, isEmpty);
    });

    test('la Song no lleva datos de atribución', () async {
      final page = await JamendoCatalogSearch(
              FakeJamendoApi(tracks: [buildTrack('1')]))
          .search(CatalogSearchQuery(text: 'x'));
      final text = page.songs.single.toString() + page.songs.single.props.join();
      expect(text, isNot(contains('creativecommons')));
      expect(text, isNot(contains('jamendo.com/track')));
    });
  });
}
