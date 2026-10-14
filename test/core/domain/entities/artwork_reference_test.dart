import 'package:flutter_test/flutter_test.dart';
import 'package:taki/core/domain/entities/artwork_reference.dart';
import 'package:taki/core/domain/entities/music_identity.dart';

void main() {
  group('LocalArtworkReference', () {
    test('igualdad y hashCode por albumId', () {
      expect(const LocalArtworkReference(7), const LocalArtworkReference(7));
      expect(
        const LocalArtworkReference(7).hashCode,
        const LocalArtworkReference(7).hashCode,
      );
      expect(
        const LocalArtworkReference(7) == const LocalArtworkReference(8),
        isFalse,
      );
    });

    test('albumId 0 es un valor válido distinto de otro', () {
      expect(const LocalArtworkReference(0), const LocalArtworkReference(0));
      expect(
        const LocalArtworkReference(0) == const LocalArtworkReference(1),
        isFalse,
      );
    });
  });

  group('RemoteArtworkReference', () {
    test('igualdad y hashCode por url, width y height', () {
      final a = RemoteArtworkReference('https://x/a.jpg', width: 300, height: 300);
      final b = RemoteArtworkReference('https://x/a.jpg', width: 300, height: 300);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('el hash distingue URL y tamaños (no solo cumple el contrato)', () {
      final base = RemoteArtworkReference('https://x/a.jpg', width: 1, height: 2);
      expect(
        base.hashCode,
        isNot(RemoteArtworkReference('https://x/b.jpg', width: 1, height: 2)
            .hashCode),
      );
      expect(
        base.hashCode,
        isNot(RemoteArtworkReference('https://x/a.jpg', width: 3, height: 2)
            .hashCode),
      );
      expect(
        base.hashCode,
        isNot(RemoteArtworkReference('https://x/a.jpg', width: 1, height: 3)
            .hashCode),
      );
    });

    test('URLs distintas son referencias distintas', () {
      expect(
        RemoteArtworkReference('https://x/a.jpg') ==
            RemoteArtworkReference('https://x/b.jpg'),
        isFalse,
      );
    });

    test('misma URL con distinto tamaño declarado es otra referencia', () {
      expect(
        RemoteArtworkReference('u', width: 300) ==
            RemoteArtworkReference('u', width: 600),
        isFalse,
      );
      expect(
        RemoteArtworkReference('u', height: 300) ==
            RemoteArtworkReference('u', height: 600),
        isFalse,
      );
      expect(
        RemoteArtworkReference('u') == RemoteArtworkReference('u', width: 1),
        isFalse,
      );
    });

    test('la URL es texto opaco: no se recorta, normaliza ni interpreta', () {
      expect(
        RemoteArtworkReference(' https://x/A.jpg ').url,
        ' https://x/A.jpg ',
      );
      expect(
        RemoteArtworkReference('https://x/A.jpg') ==
            RemoteArtworkReference('https://x/a.jpg'),
        isFalse,
      );
      // Ni siquiera tiene que parecer una URL.
      expect(RemoteArtworkReference('no es una url').url, 'no es una url');
    });

    test('rechaza URL vacía o en blanco', () {
      expect(() => RemoteArtworkReference(''), throwsArgumentError);
      expect(() => RemoteArtworkReference('   '), throwsArgumentError);
    });

    test('rechaza tamaños no positivos', () {
      expect(() => RemoteArtworkReference('u', width: 0), throwsArgumentError);
      expect(() => RemoteArtworkReference('u', width: -1), throwsArgumentError);
      expect(() => RemoteArtworkReference('u', height: 0), throwsArgumentError);
      expect(() => RemoteArtworkReference('u', height: -5), throwsArgumentError);
    });

    test('tamaño desconocido (null) es válido', () {
      final ref = RemoteArtworkReference('u');
      expect(ref.width, isNull);
      expect(ref.height, isNull);
    });

    test('es inmutable: los campos son final', () {
      // Inmutabilidad garantizada por el compilador (campos `final`); se
      // comprueba que la lectura es estable y que un valor igual no es mutado.
      final ref = RemoteArtworkReference('u', width: 10, height: 20);
      expect([ref.url, ref.width, ref.height], ['u', 10, 20]);
      expect([ref.url, ref.width, ref.height], ['u', 10, 20]);
    });
  });

  group('UnavailableArtworkReference', () {
    test('todas las instancias son iguales', () {
      expect(
        const UnavailableArtworkReference(),
        const UnavailableArtworkReference(),
      );
      expect(
        const UnavailableArtworkReference().hashCode,
        const UnavailableArtworkReference().hashCode,
      );
    });
  });

  group('entre variantes', () {
    test('local, remota y no disponible nunca son iguales entre sí', () {
      final values = <ArtworkReference>[
        const LocalArtworkReference(1),
        RemoteArtworkReference('1'),
        const UnavailableArtworkReference(),
      ];
      for (var i = 0; i < values.length; i++) {
        for (var j = 0; j < values.length; j++) {
          expect(values[i] == values[j], i == j, reason: '$i vs $j');
        }
      }
    });

    test('una remota con url «7» no se confunde con el albumId local 7', () {
      expect(
        RemoteArtworkReference('7') == const LocalArtworkReference(7),
        isFalse,
      );
      expect({RemoteArtworkReference('7'), const LocalArtworkReference(7)},
          hasLength(2));
    });

    test('el switch sobre la jerarquía sellada es exhaustivo', () {
      String describe(ArtworkReference r) => switch (r) {
            LocalArtworkReference() => 'local',
            RemoteArtworkReference() => 'remote',
            UnavailableArtworkReference() => 'unavailable',
          };
      expect(describe(const LocalArtworkReference(1)), 'local');
      expect(describe(RemoteArtworkReference('u')), 'remote');
      expect(describe(const UnavailableArtworkReference()), 'unavailable');
    });
  });

  group('localArtworkReference', () {
    test('albumId → local; null → no disponible', () {
      expect(localArtworkReference(5), const LocalArtworkReference(5));
      expect(localArtworkReference(null), const UnavailableArtworkReference());
    });
  });

  test('una referencia no es una identidad musical', () {
    // MusicIdentity sigue sin saber de artwork: dos canciones distintas pueden
    // compartir carátula, y la referencia no sustituye a la identidad.
    final ref = RemoteArtworkReference('https://x/a.jpg');
    final a = MusicIdentity('s', '1');
    final b = MusicIdentity('s', '2');
    expect(a == b, isFalse);
    expect(ref, RemoteArtworkReference('https://x/a.jpg'));
  });
}
