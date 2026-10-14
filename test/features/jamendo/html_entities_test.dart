import 'package:flutter_test/flutter_test.dart';
import 'package:taki/features/jamendo/infrastructure/html_entities.dart';

void main() {
  String d(String s) => decodeHtmlEntities(s);

  group('nombradas', () {
    test('las observadas', () {
      expect(d('Tom &amp; Jerry'), 'Tom & Jerry');
      expect(d('&quot;Hello&quot;'), '"Hello"');
      expect(d('Don&apos;t'), "Don't");
      expect(d('&lt;test&gt;'), '<test>');
    });

    test('nbsp es un espacio normal', () {
      expect(d('Rock&nbsp;Music'), 'Rock Music');
      expect(d('Rock&nbsp;Music'), isNot(contains(' ')));
    });

    test('son sensibles a mayúsculas: &AMP; no es &amp;', () {
      expect(d('&AMP; &Amp; &QUOT;'), '&AMP; &Amp; &QUOT;');
    });

    test('desconocidas quedan intactas', () {
      expect(d('&foo;'), '&foo;');
      expect(d('caf&eacute;'), 'caf&eacute;');
      expect(d('&copy; 2020'), '&copy; 2020');
    });
  });

  group('numéricas', () {
    test('decimal', () {
      expect(d('Don&#039;t Cry'), "Don't Cry");
      expect(d('Don&#39;t Cry'), "Don't Cry");
      expect(d('&#38;'), '&');
      expect(d('&#34;'), '"');
    });

    test('hexadecimal, minúscula y mayúscula', () {
      expect(d('Don&#x27;t'), "Don't");
      expect(d('Don&#X27;t'), "Don't");
      expect(d('&#x26;'), '&');
      expect(d('&#xe9;&#xE9;'), 'éé');
    });

    test('la referencia numérica 160 es exactamente U+00A0', () {
      expect(d('&#160;'), String.fromCharCode(0xA0));
      expect(d('&#xA0;'), String.fromCharCode(0xA0));
      expect(d('&#160;'), isNot(' '));
    });

    test('valores Unicode válidos: fuera del BMP y los límites', () {
      expect(d('&#128512;'), '😀');
      expect(d('&#x1F600;'), '😀');
      expect(d('&#1;'), '\u0001');
      expect(d('&#x10FFFF;'), String.fromCharCode(0x10FFFF));
      expect(d('&#233;'), 'é');
    });

    test('inválidas quedan intactas', () {
      expect(d('&#0;'), '&#0;');
      expect(d('&#x0;'), '&#x0;');
      expect(d('&#xD800;'), '&#xD800;');
      expect(d('&#xDFFF;'), '&#xDFFF;');
      expect(d('&#55296;'), '&#55296;');
      expect(d('&#1114112;'), '&#1114112;');
      expect(d('&#x110000;'), '&#x110000;');
      expect(d('&#99999999999999999999999;'), '&#99999999999999999999999;');
      expect(d('&#xFFFFFFFFFFFFFFFFFFFF;'), '&#xFFFFFFFFFFFFFFFFFFFF;');
    });

    test('malformadas quedan intactas', () {
      expect(d('&#;'), '&#;');
      expect(d('&#x;'), '&#x;');
      expect(d('&#12a;'), '&#12a;');
      expect(d('&#xZZ;'), '&#xZZ;');
      expect(d('&# 39;'), '&# 39;');
      expect(d('&#-39;'), '&#-39;');
    });

    test('el límite justo antes y después de los sustitutos', () {
      expect(d('&#xD7FF;'), '퟿');
      expect(d('&#xE000;'), '');
    });
  });

  group('incompletas', () {
    test('sin punto y coma', () {
      expect(d('Tom &amp Jerry'), 'Tom &amp Jerry');
      expect(d('&#039'), '&#039');
      expect(d('&#x27'), '&#x27');
    });

    test('& suelto y fragmentos', () {
      expect(d('AT&T'), 'AT&T');
      expect(d('A & B'), 'A & B');
      expect(d('&'), '&');
      expect(d('&;'), '&;');
      expect(d('&&amp;'), '&&');
      expect(d('amp;'), 'amp;');
      expect(d('&amp;amp'), '&amp');
    });
  });

  group('una sola pasada', () {
    test('no hay doble decodificación', () {
      expect(d('&amp;quot;'), '&quot;');
      expect(d('&amp;amp;'), '&amp;');
      expect(d('&amp;#039;'), '&#039;');
      expect(d('&amp;lt;b&amp;gt;'), '&lt;b&gt;');
      expect(d('&amp;#x27;'), '&#x27;');
    });

    test('decodificar el resultado otra vez sí lo cambiaría', () {
      final once = d('&amp;quot;');
      expect(once, '&quot;');
      expect(d(once), '"');
      expect(once, isNot('"'));
    });

    test('una entidad numérica que produce & no genera otra entidad', () {
      expect(d('&#38;quot;'), '&quot;');
      expect(d('&#38;#39;'), '&#39;');
    });
  });

  group('texto', () {
    test('sin entidades queda igual (misma instancia)', () {
      const text = 'Plain Text 123 ñ 日本語 😀';
      expect(identical(d(text), text), isTrue);
    });

    test('vacío', () {
      expect(d(''), '');
    });

    test('varias entidades en un texto', () {
      expect(d('&quot;Tom &amp; Jerry&quot; &#039;n&#x27; &lt;3 &gt;'),
          '"Tom & Jerry" \'n\' <3 >');
    });

    test('entidades pegadas', () {
      expect(d('&amp;&amp;&amp;'), '&&&');
      expect(d('&lt;&gt;&lt;&gt;'), '<><>');
      expect(d('&#039;&#039;'), "''");
    });

    test('mezcla válidas e inválidas', () {
      expect(d('&amp;&foo;&amp;'), '&&foo;&');
      expect(d('&#0;&amp;&#xD800;'), '&#0;&&#xD800;');
    });

    test('las etiquetas y las URLs no se interpretan', () {
      expect(d('<b>bold</b>'), '<b>bold</b>');
      expect(d('<script>x</script>'), '<script>x</script>');
      expect(d('https://a.example/x?a=1&b=2'), 'https://a.example/x?a=1&b=2');
      expect(d('<i>&amp;</i>'), '<i>&</i>');
    });

    test('no recorta ni normaliza espacios', () {
      expect(d('  a&amp;b  '), '  a&b  ');
      expect(d('a\n&amp;\tb'), 'a\n&\tb');
    });

    test('Unicode previo se conserva', () {
      expect(d('Ñandú &amp; café'), 'Ñandú & café');
    });
  });
}
