import 'package:flutter_test/flutter_test.dart';
import 'package:taki/core/domain/entities/artwork_exception.dart';
import 'package:taki/core/domain/entities/artwork_reference.dart';
import 'package:taki/core/domain/entities/local_music_identity.dart';
import 'package:taki/core/domain/entities/local_song.dart';
import 'package:taki/core/domain/entities/music_identity.dart';
import 'package:taki/core/domain/entities/song.dart';
import 'package:taki/core/domain/ports/artwork_resolver.dart';
import 'package:taki/core/domain/services/artwork_resolvers.dart';

import '../../../helpers/library_fakes.dart';
import '../../../helpers/universal_song.dart';

class _FixedResolver implements ArtworkResolver {
  _FixedResolver(this.result);

  final ArtworkReference result;
  final songs = <Song>[];

  @override
  Future<ArtworkReference> resolve(Song song) async {
    songs.add(song);
    return result;
  }
}

void main() {
  group('LocalArtworkResolver', () {
    const resolver = LocalArtworkResolver();

    test('canción local con albumId → LocalArtworkReference', () async {
      expect(
        await resolver.resolve(buildSong(albumId: 42)),
        const LocalArtworkReference(42),
      );
    });

    test('sin albumId → Unavailable', () async {
      expect(
        await resolver.resolve(buildSong(albumId: null)),
        const UnavailableArtworkReference(),
      );
    });

    test('no necesita la identidad para el albumId: dos canciones del mismo '
        'álbum dan la misma referencia', () async {
      expect(
        await resolver.resolve(buildSong(id: 1, albumId: 9)),
        await resolver.resolve(buildSong(id: 2, albumId: 9)),
      );
    });

    test('identidad de otra fuente → ArtworkResolutionException', () async {
      await expectLater(
        resolver.resolve(buildUniversalSong(MusicIdentity('x', '1'))),
        throwsA(isA<ArtworkResolutionException>()),
      );
    });

    test('canción local sin datos locales (Song base) → Unavailable, no lee '
        'su artwork', () async {
      final base = buildUniversalSong(
        localMusicIdentity(5),
        artwork: RemoteArtworkReference('https://x/a.jpg'),
      );
      expect(base, isNot(isA<LocalSong>()));
      expect(
        await resolver.resolve(base),
        const UnavailableArtworkReference(),
      );
    });

    test('lee albumId de LocalSong, no su artwork', () async {
      final song = buildSong(
        albumId: 5,
        artwork: const UnavailableArtworkReference(),
      );
      expect(await resolver.resolve(song), const LocalArtworkReference(5));
    });

    test('la referencia no es la identidad', () async {
      final song = buildSong(id: 5, albumId: 5);
      final reference = await resolver.resolve(song);
      expect(reference, isNot(equals(song.musicIdentity)));
      expect(song.musicIdentity, localMusicIdentity(5));
    });
  });

  group('SourceArtworkResolver', () {
    test('enruta por la fuente de la identidad', () async {
      final remote = RemoteArtworkReference('https://x/a.jpg');
      final remoteResolver = _FixedResolver(remote);
      final router = SourceArtworkResolver({
        localMusicSource: const LocalArtworkResolver(),
        'otra': remoteResolver,
      });

      expect(
        await router.resolve(buildSong(albumId: 3)),
        const LocalArtworkReference(3),
      );
      expect(remoteResolver.songs, isEmpty);

      final foreign = buildUniversalSong(MusicIdentity('otra', 'a'));
      expect(await router.resolve(foreign), remote);
      expect(remoteResolver.songs, [foreign]);
    });

    test('fuente sin resolvedor → Unavailable (sin inventar nada)', () async {
      final router = SourceArtworkResolver({
        localMusicSource: const LocalArtworkResolver(),
      });
      expect(
        await router.resolve(buildUniversalSong(MusicIdentity('desconocida', '1'))),
        const UnavailableArtworkReference(),
      );
    });

    test('un resolvedor remoto puede devolver Unavailable', () async {
      final router = SourceArtworkResolver({
        'otra': _FixedResolver(const UnavailableArtworkReference()),
      });
      expect(
        await router.resolve(buildUniversalSong(MusicIdentity('otra', '1'))),
        const UnavailableArtworkReference(),
      );
    });

    test('los errores del resolvedor se propagan', () async {
      // El router no traga la excepción de un resolvedor registrado mal.
      final bad = SourceArtworkResolver({
        'otra': const LocalArtworkResolver(),
      });
      await expectLater(
        bad.resolve(buildUniversalSong(MusicIdentity('otra', '1'))),
        throwsA(isA<ArtworkResolutionException>()),
      );
    });

    test('el mapa recibido no se puede mutar desde fuera', () async {
      final map = <String, ArtworkResolver>{};
      final router = SourceArtworkResolver(map);
      map[localMusicSource] = const LocalArtworkResolver();
      expect(
        await router.resolve(buildSong(albumId: 1)),
        const UnavailableArtworkReference(),
      );
    });
  });
}
