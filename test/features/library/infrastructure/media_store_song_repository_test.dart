import 'package:flutter/services.dart';
import 'package:taki/core/domain/entities/artwork_reference.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taki/features/library/infrastructure/media_store_song_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('taki/media_store_test');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  void answerQuerySongs(List<Map<String, Object?>> rows) {
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'querySongs');
      return rows;
    });
  }

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('mapea las filas de MediaStore a Song, incluido contentUri', () async {
    answerQuerySongs([
      {
        'id': 42,
        'title': 'Canción',
        'artist': 'Artista',
        'album': 'Álbum',
        'albumId': 7,
        'duration': 215000,
        'dateAdded': 1767225600, // 2026-01-01 00:00:00 UTC, en segundos.
        'data': '/storage/emulated/0/Music/cancion.mp3',
        'folder': 'Music/',
        'contentUri': 'content://media/external/audio/media/42',
      },
    ]);

    final songs = await MediaStoreSongRepository(channel: channel).getSongs();

    expect(songs, hasLength(1));
    final song = songs.single;
    expect(song.id, 42);
    expect(song.title, 'Canción');
    expect(song.artist, 'Artista');
    expect(song.album, 'Álbum');
    expect(song.albumId, 7);
    expect(song.artwork, const LocalArtworkReference(7));
    expect(song.durationMs, 215000);
    expect(song.path, '/storage/emulated/0/Music/cancion.mp3');
    expect(song.contentUri, 'content://media/external/audio/media/42');
    expect(song.folder, 'Music/');
  });

  test('normaliza valores desconocidos y título vacío', () async {
    answerQuerySongs([
      {
        'id': 1,
        'title': '  ',
        'artist': '<unknown>',
        'album': null,
        'albumId': null,
        'duration': null,
        'dateAdded': 0,
        'data': '/storage/emulated/0/Download/mi.tema.flac',
        'contentUri': 'content://media/external/audio/media/1',
      },
    ]);

    final song =
        (await MediaStoreSongRepository(channel: channel).getSongs()).single;

    expect(song.title, 'mi.tema');
    expect(song.artist, isNull);
    expect(song.album, isNull);
    expect(song.albumId, isNull);
    expect(song.artwork, const UnavailableArtworkReference());
    expect(song.durationMs, 0);
    expect(song.folder, '', reason: 'sin carpeta de la fuente');
  });
}
