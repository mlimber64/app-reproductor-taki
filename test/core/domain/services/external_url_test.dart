import 'package:flutter_test/flutter_test.dart';
import 'package:taki/core/domain/services/external_url.dart';
import 'package:taki/core/links/external_link_providers.dart';

void main() {
  group('openableUrlFromText', () {
    test('http y https válidos se aceptan tal cual', () {
      expect(openableUrlFromText('http://a.example/x?y=1#z'),
          Uri.parse('http://a.example/x?y=1#z'));
      expect(openableUrlFromText('https://a.example/track/1'),
          Uri.parse('https://a.example/track/1'));
    });

    test('esquema en mayúsculas se acepta', () {
      expect(openableUrlFromText('HTTPS://a.example/'), isNotNull);
    });

    test('ausente, vacía o en blanco → null', () {
      expect(openableUrlFromText(null), isNull);
      expect(openableUrlFromText(''), isNull);
      expect(openableUrlFromText('   '), isNull);
    });

    test('inválida o malformada → null', () {
      expect(openableUrlFromText('http://'), isNull);
      expect(openableUrlFromText('https://exa mple.com'), isNull);
      expect(openableUrlFromText('no es una url'), isNull);
      expect(openableUrlFromText('//a.example/x'), isNull);
    });

    test('otros esquemas → null', () {
      for (final url in [
        'ftp://a.example/x',
        'javascript:alert(1)',
        'file:///etc/passwd',
        'intent://x#Intent;end',
        'mailto:a@b.c',
        'tel:123',
      ]) {
        expect(openableUrlFromText(url), isNull, reason: url);
      }
    });
  });

  group('openableUrl', () {
    test('null → null', () => expect(openableUrl(null), isNull));

    test('no reescribe la URL', () {
      final url = Uri.parse('https://a.example/p?q=%C3%A1&b=1');
      expect(identical(openableUrl(url), url), isTrue);
    });

    test('sin host → null', () {
      expect(openableUrl(Uri.parse('https:///x')), isNull);
    });
  });

  group('UrlLauncherLinkOpener', () {
    test('una URL no http(s) no se abre y no lanza', () async {
      const opener = UrlLauncherLinkOpener();
      expect(await opener.open(Uri.parse('ftp://a.example/x')), isFalse);
      expect(await opener.open(Uri.parse('javascript:alert(1)')), isFalse);
    });
  });
}
