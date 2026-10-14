import 'package:flutter_test/flutter_test.dart';
import 'package:taki/core/domain/entities/artwork_reference.dart';
import 'package:taki/core/domain/entities/local_music_identity.dart';
import 'package:taki/core/domain/entities/local_song.dart';
import 'package:taki/core/domain/entities/music_identity.dart';
import 'package:taki/core/domain/entities/song.dart';

import '../../../helpers/library_fakes.dart';
import '../../../helpers/universal_song.dart';

LocalSong make({
  int id = 42,
  String title = 'Tema',
  String? artist = 'Artista',
  String? album = 'Disco',
  ArtworkReference artwork = const LocalArtworkReference(7),
  int durationMs = 215000,
  int? albumId = 7,
  String path = '/storage/emulated/0/Music/tema.mp3',
  String contentUri = 'content://media/external/audio/media/42',
  String folder = 'Music/',
}) =>
    LocalSong(
      id: id,
      title: title,
      artist: artist,
      album: album,
      artwork: artwork,
      durationMs: durationMs,
      albumId: albumId,
      path: path,
      contentUri: contentUri,
      folder: folder,
    );

void main() {
  group('construcción', () {
    test('conserva todos los campos', () {
      final song = make();
      expect(song.id, 42);
      expect(song.title, 'Tema');
      expect(song.artist, 'Artista');
      expect(song.album, 'Disco');
      expect(song.albumId, 7);
      expect(song.artwork, const LocalArtworkReference(7));
      expect(song.durationMs, 215000);
      expect(song.duration, const Duration(milliseconds: 215000));
      expect(song.path, '/storage/emulated/0/Music/tema.mp3');
      expect(song.contentUri, 'content://media/external/audio/media/42');
      expect(song.folder, 'Music/');
    });

    test('folder por defecto es vacía; artista, álbum y albumId pueden ser null',
        () {
      final song = LocalSong(
        id: 1,
        title: 'T',
        artist: null,
        album: null,
        artwork: const UnavailableArtworkReference(),
        durationMs: 1000,
        albumId: null,
        path: '',
        contentUri: 'content://x/1',
      );
      expect(song.folder, '');
      expect(song.artist, isNull);
      expect(song.album, isNull);
      expect(song.albumId, isNull);
    });

    test('es una Song universal', () {
      final Song song = make();
      expect(song, isA<Song>());
      expect(song.title, 'Tema');
    });
  });

  group('MusicIdentity', () {
    test('se deriva de id: local + id en decimal', () {
      expect(make(id: 42).musicIdentity, MusicIdentity('local', '42'));
      expect(make(id: 42).musicIdentity, localMusicIdentity(42));
      expect(make(id: 42).musicIdentity.source, localMusicSource);
      expect(make(id: 42).musicIdentity.externalId, '42');
    });

    test('cambia con el id y solo con el id', () {
      expect(make(id: 43).musicIdentity, MusicIdentity('local', '43'));
      expect(make(id: 42).musicIdentity,
          make(id: 42, albumId: 99, path: '/otra', title: 'Otro').musicIdentity);
    });

    test('no se puede construir una identidad inconsistente con el id', () {
      // El constructor no recibe identidad: la única fuente es `id`.
      for (final id in [0, 1, 42, 123456]) {
        final song = make(id: id);
        expect(song.musicIdentity, localMusicIdentity(id));
        expect(int.parse(song.musicIdentity.externalId), song.id);
      }
    });

    test('albumId no es la identidad ni su externalId', () {
      final song = make(id: 42, albumId: 7);
      expect(song.musicIdentity.externalId, isNot('7'));
      expect(song.musicIdentity.externalId, isNot(song.albumId.toString()));
    });
  });

  group('igualdad por valor', () {
    test('mismos datos → iguales y mismo hashCode', () {
      expect(make(), make());
      expect(make().hashCode, make().hashCode);
    });

    test('cada campo, universal o local, forma parte de la igualdad', () {
      final variants = <String, LocalSong>{
        'id': make(id: 43),
        'título': make(title: 'Otro'),
        'artista': make(artist: 'Otro'),
        'álbum': make(album: 'Otro'),
        'artwork': make(artwork: RemoteArtworkReference('https://x/a.jpg')),
        'duración': make(durationMs: 1),
        'albumId': make(albumId: 8),
        'path': make(path: '/otra'),
        'contentUri': make(contentUri: 'content://otro/42'),
        'folder': make(folder: 'Otra/'),
      };
      for (final entry in variants.entries) {
        expect(make(), isNot(entry.value), reason: entry.key);
      }
    });

    test('props contiene los campos universales y los locales', () {
      final song = make();
      for (final value in [
        song.musicIdentity,
        song.title,
        song.artwork,
        song.id,
        song.albumId,
        song.path,
        song.contentUri,
        song.folder,
      ]) {
        expect(song.props, contains(value));
      }
    });

    test('una LocalSong no es igual a una Song base con los mismos datos', () {
      final local = make();
      final base = buildUniversalSong(
        local.musicIdentity,
        title: local.title,
        artist: local.artist,
        album: local.album,
        durationMs: local.durationMs,
        artwork: local.artwork,
      );
      expect(local, isNot(base));
    });
  });

  group('artwork', () {
    test('es explícito: no se deriva de albumId', () {
      final song = make(albumId: 5, artwork: const UnavailableArtworkReference());
      expect(song.albumId, 5);
      expect(song.artwork, const UnavailableArtworkReference());
    });

    test('el helper de pruebas lo construye como el repositorio local', () {
      expect(buildSong(albumId: 10).artwork, const LocalArtworkReference(10));
      expect(
          buildSong(albumId: null).artwork, const UnavailableArtworkReference());
    });
  });

  group('localPathOf', () {
    test('LocalSong → su ruta', () {
      expect(localPathOf(make(path: '/a/b.mp3')), '/a/b.mp3');
    });

    test('Song de otra fuente → null (no tiene ruta)', () {
      expect(localPathOf(buildUniversalSong(MusicIdentity('otra', '1'))), isNull);
    });

    test('Song base con identidad local → null', () {
      expect(localPathOf(buildUniversalSong(localMusicIdentity(1))), isNull);
    });
  });
}
