import 'package:flutter_test/flutter_test.dart';
import 'package:taki/core/domain/entities/music_identity.dart';
import 'package:taki/core/domain/entities/playback_resolution_exception.dart';
import 'package:taki/core/domain/entities/playback_resource.dart';

void main() {
  group('LocalUriResource', () {
    test('conserva la URI tal cual', () {
      expect(LocalUriResource('content://media/external/audio/media/1').uri,
          'content://media/external/audio/media/1');
    });

    test('igualdad por valor y hashCode', () {
      expect(LocalUriResource('a'), LocalUriResource('a'));
      expect(LocalUriResource('a').hashCode, LocalUriResource('a').hashCode);
      expect(LocalUriResource('a'), isNot(LocalUriResource('b')));
    });

    test('no se normaliza: mayúsculas y espacios laterales cuentan', () {
      expect(LocalUriResource('A'), isNot(LocalUriResource('a')));
      expect(LocalUriResource(' a').uri, ' a');
    });

    test('URI vacía o en blanco: inválida', () {
      expect(() => LocalUriResource(''), throwsArgumentError);
      expect(() => LocalUriResource('  '), throwsArgumentError);
    });
  });

  group('RemoteUriResource', () {
    test('conserva URI y caducidad', () {
      final expires = DateTime.utc(2030);
      final resource = RemoteUriResource('https://x/a', expiresAt: expires);

      expect(resource.uri, 'https://x/a');
      expect(resource.expiresAt, expires);
      expect(RemoteUriResource('https://x/a').expiresAt, isNull);
    });

    test('igualdad incluye la caducidad', () {
      final t = DateTime.utc(2030);

      expect(RemoteUriResource('u', expiresAt: t),
          RemoteUriResource('u', expiresAt: t));
      expect(RemoteUriResource('u', expiresAt: t).hashCode,
          RemoteUriResource('u', expiresAt: t).hashCode);
      expect(RemoteUriResource('u', expiresAt: t), isNot(RemoteUriResource('u')));
      expect(RemoteUriResource('u'), RemoteUriResource('u'));
    });

    test('URI vacía: inválida', () {
      expect(() => RemoteUriResource(''), throwsArgumentError);
      expect(() => RemoteUriResource(' \t'), throwsArgumentError);
    });

    test('la caducidad no se infiere: null no significa "no caduca"', () {
      expect(RemoteUriResource('u').expiresAt, isNull);
    });
  });

  group('ProviderPlaybackResource', () {
    test('motor opaco y referencia opcional', () {
      final resource = ProviderPlaybackResource('motor-a', reference: 'r1');

      expect(resource.engine, 'motor-a');
      expect(resource.reference, 'r1');
      expect(ProviderPlaybackResource('motor-a').reference, isNull);
    });

    test('igualdad por motor y referencia', () {
      expect(ProviderPlaybackResource('a', reference: 'r'),
          ProviderPlaybackResource('a', reference: 'r'));
      expect(ProviderPlaybackResource('a'), ProviderPlaybackResource('a'));
      expect(ProviderPlaybackResource('a'), isNot(ProviderPlaybackResource('b')));
      expect(ProviderPlaybackResource('a', reference: 'r'),
          isNot(ProviderPlaybackResource('a')));
      expect(ProviderPlaybackResource('a').hashCode,
          ProviderPlaybackResource('a').hashCode);
    });

    test('motor vacío o referencia en blanco: inválidos', () {
      expect(() => ProviderPlaybackResource(''), throwsArgumentError);
      expect(() => ProviderPlaybackResource('  '), throwsArgumentError);
      expect(() => ProviderPlaybackResource('a', reference: ''),
          throwsArgumentError);
    });
  });

  group('UnavailableResource', () {
    test('se puede crear sin motivo y con motivo', () {
      expect(const UnavailableResource().reason, isNull);
      expect(const UnavailableResource(reason: 'x').reason, 'x');
    });

    test('igualdad por motivo', () {
      expect(const UnavailableResource(), const UnavailableResource());
      expect(const UnavailableResource(reason: 'x'),
          const UnavailableResource(reason: 'x'));
      expect(const UnavailableResource(reason: 'x'),
          isNot(const UnavailableResource(reason: 'y')));
      expect(const UnavailableResource().hashCode,
          const UnavailableResource().hashCode);
    });
  });

  group('casos distintos', () {
    test('misma cadena en tipos distintos no es igual', () {
      final values = <PlaybackResource>[
        LocalUriResource('x'),
        RemoteUriResource('x'),
        ProviderPlaybackResource('x'),
        const UnavailableResource(reason: 'x'),
      ];

      for (var i = 0; i < values.length; i++) {
        for (var j = 0; j < values.length; j++) {
          expect(values[i] == values[j], i == j, reason: '$i vs $j');
        }
      }
    });

    test('el switch sobre la jerarquía sellada es exhaustivo', () {
      String describe(PlaybackResource resource) => switch (resource) {
            LocalUriResource() => 'local',
            RemoteUriResource() => 'remote',
            ProviderPlaybackResource() => 'provider',
            UnavailableResource() => 'unavailable',
          };

      expect(describe(LocalUriResource('a')), 'local');
      expect(describe(RemoteUriResource('a')), 'remote');
      expect(describe(ProviderPlaybackResource('a')), 'provider');
      expect(describe(const UnavailableResource()), 'unavailable');
    });
  });

  group('PlaybackResolutionException', () {
    test('IdentityNotFound conserva la identidad', () {
      final identity = MusicIdentity('otra', '1');
      final error = IdentityNotFound(identity);

      expect(error.identity, identity);
      expect(error, isA<PlaybackResolutionException>());
      expect(error, isA<Exception>());
    });

    test('PlaybackResolutionError conserva mensaje y causa opaca', () {
      final cause = StateError('x');
      final error = PlaybackResolutionError('falló', cause: cause);

      expect(error.message, 'falló');
      expect(error.cause, cause);
      expect(const PlaybackResolutionError('m').cause, isNull);
    });

    test('los dos tipos son distinguibles', () {
      final List<PlaybackResolutionException> errors = [
        IdentityNotFound(MusicIdentity('a', '1')),
        const PlaybackResolutionError('m'),
      ];

      expect(
        [
          for (final e in errors)
            switch (e) {
              IdentityNotFound() => 'not-found',
              PlaybackResolutionError() => 'error',
            },
        ],
        ['not-found', 'error'],
      );
    });
  });
}
