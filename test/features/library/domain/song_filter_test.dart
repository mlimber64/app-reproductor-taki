import 'package:flutter_test/flutter_test.dart';
import 'package:taki/core/constants/library_constants.dart';
import 'package:taki/core/domain/entities/song.dart';
import 'package:taki/features/library/domain/services/song_filter.dart';

import '../../../helpers/library_fakes.dart';

void main() {
  final filter = SongFilter();

  bool accepts({String folder = 'Music/', int durationMs = 180000}) =>
      filter.accepts(buildSong(folder: folder, durationMs: durationMs));

  test('una canción normal pasa', () {
    expect(accepts(), isTrue);
    expect(accepts(folder: 'Music/Rock/Queen/'), isTrue);
  });

  test('descarta los audios de menos de 30 s', () {
    final min = LibraryConstants.minSongDuration.inMilliseconds;
    expect(accepts(durationMs: min - 1), isFalse);
    expect(accepts(durationMs: min), isTrue);
  });

  test('descarta las carpetas excluidas, también anidadas', () {
    for (final folder in [
      'Recordings/',
      'Music/Recordings/',
      'Media/WhatsApp Voice Notes/2026-09/',
      'Android/media/com.whatsapp/WhatsApp/Media/WhatsApp Audio/',
      'WhatsApp Business/Media/WhatsApp Business Voice Notes/202609',
      'Ringtones/',
      'Notifications',
      'Alarms/',
      'Podcasts/Mi podcast/',
      'Audiobooks/',
      'Call/',
      '/storage/emulated/0/Call Recordings',
    ]) {
      expect(accepts(folder: folder), isFalse, reason: folder);
    }
  });

  test('compara por carpeta completa, no por subcadena', () {
    expect(accepts(folder: 'Music/Live Recordings Vol1/'), isTrue);
    expect(accepts(folder: 'Music/Recordings Live/'), isTrue);
    expect(accepts(folder: 'Music/Callejeros/'), isTrue);
    expect(accepts(folder: 'Music/Voice Notes Remix/'), isTrue);
  });

  test('no distingue mayúsculas', () {
    expect(accepts(folder: 'media/whatsapp voice notes/'), isFalse);
    expect(accepts(folder: 'MUSIC/RECORDINGS/'), isFalse);
  });

  test('sin carpeta de la fuente, usa la de la ruta del archivo', () {
    Song withPath(String path) => Song(
          id: 1,
          title: 'T',
          artist: null,
          album: null,
          albumId: null,
          durationMs: 180000,
          path: path,
          contentUri: 'content://x/1',
          dateAdded: null,
        );

    expect(
      filter.accepts(withPath('/storage/emulated/0/Recordings/nota.m4a')),
      isFalse,
    );
    expect(
      filter.accepts(withPath('/storage/emulated/0/Music/Recordings.mp3')),
      isTrue,
      reason: 'el nombre del archivo no es una carpeta',
    );
  });

  test('la lista de carpetas se puede cambiar', () {
    final custom = SongFilter(excludedFolders: ['Demos']);
    expect(custom.accepts(buildSong(folder: 'Music/Demos/')), isFalse);
    expect(custom.accepts(buildSong(folder: 'Recordings/')), isTrue);
  });
}
