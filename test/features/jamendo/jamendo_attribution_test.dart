import 'package:flutter_test/flutter_test.dart';
import 'package:taki/core/domain/entities/music_identity.dart';
import 'package:taki/core/domain/entities/provider_attribution.dart';
import 'package:taki/features/jamendo/domain/entities/jamendo_track.dart';
import 'package:taki/features/jamendo/domain/services/jamendo_song_mapper.dart';
import 'package:taki/features/jamendo/infrastructure/jamendo_response_parser.dart';

import '../../helpers/jamendo_fakes.dart';

JamendoTrack track({String? share, String? license, String id = '7'}) =>
    JamendoTrack(id: id, name: 'x', shareUrl: share, licenseUrl: license);

void main() {
  group('contrato JamendoTrack → ProviderAttribution', () {
    test('identifica el contenido y al proveedor', () {
      final a = track().attribution;
      expect(a.identity, MusicIdentity('jamendo', '7'));
      expect(a.providerName, 'Jamendo');
      expect(jamendoProviderName, 'Jamendo');
    });

    test('completa: enlace y licencia', () {
      final a = track(
        share: 'https://www.jamendo.com/track/7',
        license: 'http://creativecommons.org/licenses/by-nc-nd/3.0/',
      ).attribution;
      expect(a.pageUrl, Uri.parse('https://www.jamendo.com/track/7'));
      expect(a.licenseUrl,
          Uri.parse('http://creativecommons.org/licenses/by-nc-nd/3.0/'));
      expect(a.licenseName, 'CC BY-NC-ND 3.0');
      expect(a.hasPageUrl, isTrue);
      expect(a.hasLicense, isTrue);
      expect(a.isComplete, isTrue);
    });

    test('shareurl ausente: sin enlace, y NO se inventa uno desde el id', () {
      for (final share in [null, '', '  ', 'no es url', 'ftp://x/y', '/relativa', 'https:///track/7']) {
        final a = track(share: share, license: 'http://creativecommons.org/licenses/by/4.0/')
            .attribution;
        expect(a.pageUrl, isNull, reason: '$share');
        expect(a.hasPageUrl, isFalse);
        expect(a.isComplete, isFalse);
        expect(a.hasLicense, isTrue);
      }
    });

    test('license_ccurl ausente: sin licencia ni nombre', () {
      for (final license in [null, '', ' ', 'texto', 'ftp://x']) {
        final a = track(share: 'https://www.jamendo.com/track/7', license: license)
            .attribution;
        expect(a.licenseUrl, isNull, reason: '$license');
        expect(a.licenseName, isNull);
        expect(a.hasLicense, isFalse);
        expect(a.isComplete, isFalse);
        expect(a.hasPageUrl, isTrue);
      }
    });

    test('la atribución puede faltar por completo, pero sigue identificada', () {
      final a = track().attribution;
      expect(a.pageUrl, isNull);
      expect(a.licenseUrl, isNull);
      expect(a.isComplete, isFalse);
      expect(a.identity.externalId, '7');
    });

    test('con el track real del fixture', () {
      final t = parseJamendoTracks(jamendoFixture('tracks_search.json')).tracks.first;
      final a = t.attribution;
      expect(a.identity, MusicIdentity('jamendo', '2291526'));
      expect(a.pageUrl, Uri.parse('https://www.jamendo.com/track/2291526'));
      expect(a.licenseName, 'CC BY-NC-ND 3.0');
      expect(a.isComplete, isTrue);
    });
  });

  group('licencia por pista', () {
    test('dos pistas, dos licencias distintas (no hay licencia global)', () {
      final nd = track(license: 'http://creativecommons.org/licenses/by-nc-nd/3.0/', id: '1')
          .attribution;
      final sa = track(license: 'http://creativecommons.org/licenses/by-nc-sa/3.0/', id: '2')
          .attribution;
      expect(nd.licenseName, 'CC BY-NC-ND 3.0');
      expect(sa.licenseName, 'CC BY-NC-SA 3.0');
      expect(nd, isNot(sa));
    });

    test('Song no tiene licencia ni atribución', () {
      final song = songFromJamendoTrack(track(
        share: 'https://www.jamendo.com/track/7',
        license: 'http://creativecommons.org/licenses/by-nc-nd/3.0/',
      ));
      final text = '$song ${song.props}';
      expect(text, isNot(contains('creativecommons')));
      expect(text, isNot(contains('jamendo.com/track')));
      expect(text.toLowerCase(), isNot(contains('licen')));
    });

    test('nombre legible solo para URLs CC reconocibles', () {
      String? name(String url) => track(license: url).attribution.licenseName;
      expect(name('https://creativecommons.org/licenses/by/4.0/'), 'CC BY 4.0');
      expect(name('https://creativecommons.org/licenses/by-sa/3.0'), 'CC BY-SA 3.0');
      expect(name('https://www.creativecommons.org/licenses/by-nc/2.5/'), 'CC BY-NC 2.5');
      expect(name('https://creativecommons.org/licenses/by-nc-nd/3.0/'), 'CC BY-NC-ND 3.0');
      expect(name('https://creativecommons.org/licenses/by-nc-sa/3.0/'), 'CC BY-NC-SA 3.0');
      // No reconocibles: la URL se conserva, el nombre no se inventa.
      expect(name('https://otro.example/licenses/by/4.0/'), isNull);
      expect(name('https://creativecommons.org/licenses/zzz/4.0/'), isNull);
      expect(name('https://creativecommons.org/licenses/by/x/'), isNull);
      expect(name('https://creativecommons.org/publicdomain/zero/1.0/'), isNull);
      expect(name('https://creativecommons.org/licenses/by/'), isNull);
      expect(name('https://creativecommons.org/licenses/by/4.0/extra/'), isNull);
      expect(name('https://creativecommons.org/licenses/by-nc-xx/4.0/'), isNull);
      expect(name('https://creativecommons.org/otro/by/4.0/'), isNull);
      expect(name('https://creativecommons.org/licenses/xby/4.0/'), isNull);
      expect(name('https://creativecommons.org/licenses/by-nc-nd-x/4.0/'), isNull);
      expect(name('https://creativecommons.org/licenses/by/4.0x/'), isNull);
      expect(name('https://creativecommons.org/licenses/by/x4.0/'), isNull);
      expect(track(license: 'https://otro.example/licenses/by/4.0/')
          .attribution.licenseUrl, isNotNull);
    });
  });

  group('ProviderAttribution', () {
    ProviderAttribution make({
      String provider = 'P',
      Uri? page,
      Uri? license,
      String? name,
    }) =>
        ProviderAttribution(
          identity: MusicIdentity('p', '1'),
          providerName: provider,
          pageUrl: page,
          licenseUrl: license,
          licenseName: name,
        );

    test('igualdad por valor y hashCode', () {
      final a = make(page: Uri.parse('https://a'), license: Uri.parse('https://l'), name: 'n');
      final b = make(page: Uri.parse('https://a'), license: Uri.parse('https://l'), name: 'n');
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      // Un solo campo distinto cada vez.
      Uri u(String s) => Uri.parse(s);
      expect(a, isNot(make(provider: 'Q', page: u('https://a'), license: u('https://l'), name: 'n')));
      expect(a, isNot(make(page: u('https://z'), license: u('https://l'), name: 'n')));
      expect(a, isNot(make(page: u('https://a'), license: u('https://z'), name: 'n')));
      expect(a, isNot(make(page: u('https://a'), license: u('https://l'), name: 'm')));
      expect(
        a,
        isNot(ProviderAttribution(
          identity: MusicIdentity('p', '2'),
          providerName: 'P',
          pageUrl: u('https://a'),
          licenseUrl: u('https://l'),
          licenseName: 'n',
        )),
      );
    });

    test('isComplete exige enlace y licencia', () {
      expect(make().isComplete, isFalse);
      expect(make(page: Uri.parse('https://a')).isComplete, isFalse);
      expect(make(license: Uri.parse('https://l')).isComplete, isFalse);
      expect(make(page: Uri.parse('https://a'), license: Uri.parse('https://l')).isComplete, isTrue);
    });

    test('toString no rompe con datos ausentes', () {
      expect(make().toString(), contains('ProviderAttribution'));
    });
  });
}
