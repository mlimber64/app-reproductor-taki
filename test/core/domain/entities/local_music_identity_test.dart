import 'package:flutter_test/flutter_test.dart';
import 'package:taki/core/domain/entities/local_music_identity.dart';
import 'package:taki/core/domain/entities/music_identity.dart';
import 'package:taki/features/library/domain/entities/favorite_entry.dart';
import 'package:taki/features/playlists/domain/entities/playlist_entry.dart';

import '../../../helpers/library_fakes.dart';

void main() {
  group('localMusicIdentity', () {
    test('fuente "local" y el id local en decimal', () {
      final id = localMusicIdentity(12345);

      expect(id.source, localMusicSource);
      expect(localMusicSource, 'local');
      expect(id.externalId, '12345');
      expect(id, MusicIdentity('local', '12345'));
    });

    test('ids distintos dan identidades distintas; el mismo, iguales', () {
      expect(localMusicIdentity(1), localMusicIdentity(1));
      expect(localMusicIdentity(1), isNot(localMusicIdentity(2)));
      expect(localMusicIdentity(1), isNot(localMusicIdentity(10)));
    });

    test('id 0 y ids grandes son válidos', () {
      expect(localMusicIdentity(0).externalId, '0');
      expect(localMusicIdentity(9007199254740991).externalId,
          '9007199254740991');
    });

    test('un id local no coincide con la misma cadena de otra fuente', () {
      expect(localMusicIdentity(7), isNot(MusicIdentity('otra', '7')));
    });
  });

  group('Song.musicIdentity', () {
    test('se deriva de Song.id', () {
      final song = buildSong(id: 42);

      expect(song.musicIdentity, localMusicIdentity(42));
      expect(song.musicIdentity.externalId, song.id.toString());
    });

    test('dos canciones con el mismo id local comparten identidad aunque '
        'cambie su metadata', () {
      final a = buildSong(id: 5, title: 'Uno');
      final b = buildSong(id: 5, title: 'Otro título');

      expect(a, isNot(b)); // Song sigue comparando todos sus campos
      expect(a.musicIdentity, b.musicIdentity);
    });

    test('ids distintos: identidades distintas', () {
      expect(buildSong(id: 1).musicIdentity,
          isNot(buildSong(id: 2).musicIdentity));
    });

    test('forma parte de las props y de la igualdad de Song (desde 2.9)', () {
      final song = buildSong(id: 3);

      expect(song.props, contains(song.musicIdentity));
      // En LocalSong sale de `id`, que además es un campo local.
      expect(song, isNot(buildSong(id: 4)));
    });
  });

  group('referencias guardadas (Fase 2.4)', () {
    test('favoritos y entradas de playlist se identifican por MusicIdentity '
        '(cada entrada de playlist conserva su propio id)', () {
      final identity = buildSong(id: 9).musicIdentity;
      final favorite = FavoriteEntry(
        musicIdentity: identity,
        addedAt: DateTime(2026),
      );
      final first = PlaylistEntry(
        id: 1,
        playlistId: 1,
        position: 0,
        musicIdentity: identity,
      );
      final second = PlaylistEntry(
        id: 2,
        playlistId: 1,
        position: 1,
        musicIdentity: identity,
      );

      expect(favorite.musicIdentity, localMusicIdentity(9));
      expect(first.musicIdentity, favorite.musicIdentity);
      expect(second.musicIdentity, first.musicIdentity);
      expect(first, isNot(second));
    });

    test('una referencia puede tener una identidad que no es local', () {
      final remote = FavoriteEntry(
        musicIdentity: MusicIdentity('otra', 'abc123'),
        addedAt: DateTime(2026),
      );

      expect(remote.musicIdentity.source, 'otra');
      expect(remote.musicIdentity.externalId, 'abc123');
      expect(remote.musicIdentity, isNot(localMusicIdentity(123)));
    });

    test('la identidad forma parte de la igualdad de la entrada', () {
      final at = DateTime(2026);

      expect(
        FavoriteEntry(musicIdentity: MusicIdentity('a', '1'), addedAt: at),
        FavoriteEntry(musicIdentity: MusicIdentity('a', '1'), addedAt: at),
      );
      expect(
        FavoriteEntry(musicIdentity: MusicIdentity('a', '1'), addedAt: at),
        isNot(FavoriteEntry(musicIdentity: MusicIdentity('b', '1'), addedAt: at)),
      );
    });
  });
}
