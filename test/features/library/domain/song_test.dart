import 'package:flutter_test/flutter_test.dart';
import 'package:taki/features/library/domain/entities/song.dart';

import '../../../helpers/library_fakes.dart';

void main() {
  test('dos canciones con los mismos datos son iguales', () {
    expect(buildSong(), buildSong());
  });

  test('contentUri forma parte de la igualdad', () {
    final song = buildSong(id: 7);
    final other = buildSong(id: 7);

    expect(song.contentUri, 'content://media/external/audio/media/7');
    expect(song.props, contains(song.contentUri));
    expect(song, other);
  });

  test('duration se deriva de durationMs', () {
    expect(buildSong(durationMs: 61500).duration,
        const Duration(minutes: 1, seconds: 1, milliseconds: 500));
  });

  test('folder forma parte de la igualdad y por defecto está vacía', () {
    expect(buildSong(folder: 'Music/'), isNot(buildSong(folder: 'Podcasts/')));
    expect(buildSong().folder, 'Music/');

    final withoutFolder = Song(
      id: 1,
      title: 'T',
      artist: null,
      album: null,
      albumId: null,
      durationMs: 1000,
      path: '',
      contentUri: 'content://x/1',
      dateAdded: null,
    );
    expect(withoutFolder.folder, '');
  });
}
