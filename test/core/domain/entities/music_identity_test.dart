import 'package:flutter_test/flutter_test.dart';
import 'package:taki/core/domain/entities/music_identity.dart';

void main() {
  group('igualdad y hashCode', () {
    test('misma fuente e id: iguales y con el mismo hashCode', () {
      final a = MusicIdentity('local', '42');
      final b = MusicIdentity('local', '42');

      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(identical(a, b), isFalse);
    });

    test('otra fuente con el mismo id: distintas', () {
      expect(MusicIdentity('a', '1'), isNot(MusicIdentity('b', '1')));
    });

    test('la misma fuente con otro id: distintas', () {
      expect(MusicIdentity('a', '1'), isNot(MusicIdentity('a', '2')));
    });

    test('fuente e id no son intercambiables', () {
      expect(MusicIdentity('a', 'b'), isNot(MusicIdentity('b', 'a')));
    });

    test('sirve como clave de Set y de Map', () {
      final set = {
        MusicIdentity('local', '1'),
        MusicIdentity('local', '1'),
        MusicIdentity('local', '2'),
        MusicIdentity('otra', '1'),
      };
      expect(set, hasLength(3));

      final map = {MusicIdentity('local', '1'): 'x'};
      expect(map[MusicIdentity('local', '1')], 'x');
      expect(map[MusicIdentity('local', '2')], isNull);
    });

    test('no es igual a un objeto de otro tipo', () {
      // ignore: unrelated_type_equality_checks
      expect(MusicIdentity('a', '1') == 'a:1', isFalse);
    });
  });

  group('valores válidos', () {
    test('conserva source y externalId tal cual', () {
      final id = MusicIdentity('local', '12345');

      expect(id.source, 'local');
      expect(id.externalId, '12345');
    });

    test('ids numéricos representados como texto', () {
      expect(MusicIdentity('x', '0').externalId, '0');
      expect(MusicIdentity('x', '007').externalId, '007');
      expect(MusicIdentity('x', '9007199254740993').externalId,
          '9007199254740993');
      // "007" y "7" son ids distintos: no se interpretan como números.
      expect(MusicIdentity('x', '007'), isNot(MusicIdentity('x', '7')));
    });

    test('ids alfanuméricos', () {
      expect(MusicIdentity('x', 'mWB22').externalId, 'mWB22');
      expect(MusicIdentity('x', 'a1B2-c3_D4').externalId, 'a1B2-c3_D4');
    });

    test('un id con aspecto de URL es solo texto', () {
      const text = 'https://example.com/track/1?x=y#z';
      final id = MusicIdentity('x', text);

      expect(id.externalId, text);
      expect(id, isNot(MusicIdentity('x', 'https://example.com/track/1')));
    });

    test('caracteres especiales, unicode y separadores', () {
      for (final value in ['a:b', 'a/b', r'a\b', 'ñandú', '曲', '🎵', 'a b']) {
        expect(MusicIdentity('x', value).externalId, value);
        expect(MusicIdentity(value, 'id').source, value);
      }
    });

    test('ids largos', () {
      final long = 'a' * 10000;
      expect(MusicIdentity('x', long).externalId, long);
    });
  });

  group('sin normalizar', () {
    test('mayúsculas y minúsculas importan', () {
      expect(MusicIdentity('x', 'ABC'), isNot(MusicIdentity('x', 'abc')));
      expect(MusicIdentity('Local', '1'), isNot(MusicIdentity('local', '1')));
      expect(MusicIdentity('x', 'ABC').externalId, 'ABC');
    });

    test('los espacios laterales no se recortan y distinguen identidades', () {
      final padded = MusicIdentity('x', ' id ');

      expect(padded.externalId, ' id ');
      expect(padded, isNot(MusicIdentity('x', 'id')));
      expect(MusicIdentity(' x', '1').source, ' x');
    });
  });

  group('invariantes', () {
    test('source vacío', () {
      expect(() => MusicIdentity('', '1'), throwsArgumentError);
    });

    test('externalId vacío', () {
      expect(() => MusicIdentity('local', ''), throwsArgumentError);
    });

    test('solo espacios en blanco', () {
      expect(() => MusicIdentity('   ', '1'), throwsArgumentError);
      expect(() => MusicIdentity('local', '   '), throwsArgumentError);
      expect(() => MusicIdentity('local', '\t\n'), throwsArgumentError);
    });

    test('el error nombra el parámetro inválido', () {
      expect(
        () => MusicIdentity('', '1'),
        throwsA(isA<ArgumentError>().having((e) => e.name, 'name', 'source')),
      );
      expect(
        () => MusicIdentity('x', ''),
        throwsA(
          isA<ArgumentError>().having((e) => e.name, 'name', 'externalId'),
        ),
      );
    });
  });

  test('toString incluye fuente e id (solo depuración)', () {
    expect(
      MusicIdentity('local', '1').toString(),
      'MusicIdentity(source: local, externalId: 1)',
    );
  });
}
