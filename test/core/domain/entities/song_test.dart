import 'package:flutter_test/flutter_test.dart';
import 'package:taki/core/domain/entities/artwork_reference.dart';
import 'package:taki/core/domain/entities/local_music_identity.dart';
import 'package:taki/core/domain/entities/local_song.dart';
import 'package:taki/core/domain/entities/music_identity.dart';
import 'package:taki/core/domain/entities/song.dart';

import '../../../helpers/library_fakes.dart';
import '../../../helpers/universal_song.dart';

void main() {
  final id = MusicIdentity('otra', 'x1');
  final remote = RemoteArtworkReference('https://cdn.example/a.jpg');

  group('Song universal', () {
    test('representa una fuente no local sin ningún campo local', () {
      final song = buildUniversalSong(
        id,
        title: 'Tema',
        artist: 'Artista',
        album: 'Disco',
        durationMs: 61500,
        artwork: remote,
      );

      expect(song.musicIdentity, id);
      expect(song.title, 'Tema');
      expect(song.artist, 'Artista');
      expect(song.album, 'Disco');
      expect(song.durationMs, 61500);
      expect(song.artwork, remote);
      expect(song, isNot(isA<LocalSong>()));
    });

    test('artista y álbum pueden ser null', () {
      final song = buildUniversalSong(id, artist: null, album: null);
      expect(song.artist, isNull);
      expect(song.album, isNull);
    });

    test('duration se deriva de durationMs', () {
      expect(buildUniversalSong(id, durationMs: 61500).duration,
          const Duration(minutes: 1, seconds: 1, milliseconds: 500));
    });

    test('la API universal es exactamente identidad, metadata y artwork', () {
      expect(buildUniversalSong(id).props, hasLength(6));
    });

    group('igualdad por valor', () {
      Song base() => buildUniversalSong(id, artwork: remote);

      test('mismos datos → iguales y mismo hashCode', () {
        expect(base(), base());
        expect(base().hashCode, base().hashCode);
      });

      test('cada campo forma parte de la igualdad', () {
        expect(
          base(),
          isNot(buildUniversalSong(MusicIdentity('otra', 'x2'), artwork: remote)),
          reason: 'identidad',
        );
        expect(
          base(),
          isNot(buildUniversalSong(MusicIdentity('b', 'x1'), artwork: remote)),
          reason: 'fuente',
        );
        expect(base(),
            isNot(buildUniversalSong(id, artwork: remote, title: 'Otro')),
            reason: 'título');
        expect(base(),
            isNot(buildUniversalSong(id, artwork: remote, artist: 'Otro')),
            reason: 'artista');
        expect(base(),
            isNot(buildUniversalSong(id, artwork: remote, album: 'Otro')),
            reason: 'álbum');
        expect(base(),
            isNot(buildUniversalSong(id, artwork: remote, durationMs: 1)),
            reason: 'duración');
        expect(base(), isNot(buildUniversalSong(id)), reason: 'artwork');
      });

      test('URLs de carátula distintas → canciones distintas', () {
        expect(
          buildUniversalSong(id, artwork: remote),
          isNot(buildUniversalSong(
            id,
            artwork: RemoteArtworkReference('https://cdn.example/b.jpg'),
          )),
        );
      });
    });

    test('una Song base nunca es igual a una LocalSong, aunque compartan datos',
        () {
      final local = buildSong(id: 5, albumId: null);
      final base = buildUniversalSong(
        local.musicIdentity,
        title: local.title,
        artist: local.artist,
        album: local.album,
        durationMs: local.durationMs,
        artwork: local.artwork,
      );
      expect(base.props, isNot(local.props));
      expect(base, isNot(local));
      expect(local, isNot(base));
    });

    test('puede tener identidad local sin ser una LocalSong', () {
      final base = buildUniversalSong(localMusicIdentity(9));
      expect(base.musicIdentity.source, localMusicSource);
      expect(base, isNot(isA<LocalSong>()));
    });
  });

  group('artwork', () {
    test('es un campo explícito: no se deriva de la identidad', () {
      expect(buildUniversalSong(id).artwork, const UnavailableArtworkReference());
      expect(buildUniversalSong(id, artwork: remote).artwork, remote);
    });

    test('la identidad no depende de la carátula', () {
      expect(
        buildUniversalSong(id, artwork: remote).musicIdentity,
        buildUniversalSong(id).musicIdentity,
      );
    });
  });
}
