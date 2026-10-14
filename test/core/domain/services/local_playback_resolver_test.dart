import 'package:flutter_test/flutter_test.dart';
import 'package:taki/core/domain/entities/artwork_reference.dart';
import 'package:taki/core/domain/entities/local_music_identity.dart';
import 'package:taki/core/domain/entities/music_identity.dart';
import 'package:taki/core/domain/entities/playback_resolution_exception.dart';
import 'package:taki/core/domain/entities/playback_resource.dart';
import 'package:taki/core/domain/entities/local_song.dart';
import 'package:taki/core/domain/ports/playback_resolver.dart';
import 'package:taki/core/domain/services/local_playback_resolver.dart';

import '../../../helpers/library_fakes.dart';
import '../../../helpers/universal_song.dart';

LocalSong _songWithUri(String uri) => LocalSong(
      id: 1,
      title: 't',
      artist: null,
      album: null,
      albumId: null,
      artwork: localArtworkReference(null),
      durationMs: 1000,
      path: '',
      contentUri: uri,
    );
void main() {
  const PlaybackResolver resolver = LocalPlaybackResolver();

  test('canción local → LocalUriResource con su contentUri', () async {
    final song = buildSong(id: 42);

    final resource = await resolver.resolve(song);

    expect(resource, LocalUriResource(song.contentUri));
    expect(resource, LocalUriResource('content://media/external/audio/media/42'));
  });

  test('la resolución solo depende de la canción, no de otras', () async {
    final a = await resolver.resolve(buildSong(id: 1));
    final b = await resolver.resolve(buildSong(id: 2));

    expect(a, isNot(b));
    expect(a, await resolver.resolve(buildSong(id: 1)));
  });

  test('la identidad local usada es la de la canción', () async {
    final song = buildSong(id: 7);

    expect(song.musicIdentity, localMusicIdentity(7));
    expect(await resolver.resolve(song), isA<LocalUriResource>());
  });

  test('identidad de otra fuente → IdentityNotFound (sin leer sus datos)',
      () async {
    final song = buildUniversalSong(MusicIdentity('otra', 'abc'));

    await expectLater(
      resolver.resolve(song),
      throwsA(
        isA<IdentityNotFound>().having(
          (e) => e.identity,
          'identity',
          MusicIdentity('otra', 'abc'),
        ),
      ),
    );
  });

  test('identidad local pero Song base (sin datos locales) → UnavailableResource',
      () async {
    final base = buildUniversalSong(localMusicIdentity(9));
    expect(base, isNot(isA<LocalSong>()));
    expect(await resolver.resolve(base), isA<UnavailableResource>());
  });

  test('contentUri vacío → UnavailableResource (existe, sin recurso)',
      () async {
    final resource = await resolver.resolve(_songWithUri(''));

    expect(resource, isA<UnavailableResource>());
  });

  test('contentUri en blanco → UnavailableResource', () async {
    expect(await resolver.resolve(_songWithUri('   ')),
        isA<UnavailableResource>());
  });

  test('un fallo de la canción no se convierte en excepción de red', () async {
    // Ningún caso del resolvedor local lanza PlaybackResolutionError.
    final resource = await resolver.resolve(_songWithUri(''));

    expect(resource, isNot(isA<ProviderPlaybackResource>()));
    expect(resource, isNot(isA<RemoteUriResource>()));
  });
}
