import 'package:flutter_test/flutter_test.dart';
import 'package:taki/features/library/domain/entities/favorite_entry.dart';
import 'package:taki/core/domain/services/song_matcher.dart';
import 'package:taki/features/playlists/domain/entities/playlist_entry.dart';
import 'package:taki/core/domain/entities/local_music_identity.dart';

import '../../../helpers/library_fakes.dart';

void main() {
  final song = buildSong(
    id: 10,
    title: 'Mi Canción',
    artist: 'Mi Artista',
    durationMs: 200400,
  );
  final matcher = SongMatcher([song, buildSong(id: 11, title: 'Otra')]);

  FavoriteEntry reference({
    int songId = 99,
    String? title,
    String? artist,
    int? durationMs,
    String? path,
  }) {
    return FavoriteEntry(
      musicIdentity: localMusicIdentity(songId),
      addedAt: DateTime(2026),
      title: title,
      artist: artist,
      durationMs: durationMs,
      path: path,
    );
  }

  test('coincide por id aunque el respaldo sea distinto', () {
    expect(matcher.match(reference(songId: 10, title: 'Nada que ver')), song);
  });

  test('si el id no existe, coincide por ruta', () {
    expect(matcher.match(reference(path: song.path)), song);
  });

  test('si tampoco hay ruta, por título + artista + duración ±1 s', () {
    expect(
      matcher.match(reference(
        title: ' mi canción ',
        artist: 'MI ARTISTA',
        durationMs: 199500,
        path: '/otra/ruta.mp3',
      )),
      song,
    );
    expect(
      matcher.match(reference(
        title: 'Mi Canción',
        artist: 'Mi Artista',
        durationMs: 198000,
      )),
      isNull,
      reason: 'fuera de la tolerancia',
    );
  });

  test('sin coincidencias devuelve null', () {
    expect(matcher.match(reference(title: 'Borrada', durationMs: 1000)), isNull);
    expect(matcher.match(reference()), isNull);
  });

  test('funciona igual con entradas de playlist', () {
    final entry = PlaylistEntry(
      id: 1,
      playlistId: 1,
      position: 0,
      musicIdentity: localMusicIdentity(99),
      title: 'Mi Canción',
      artist: 'Mi Artista',
      durationMs: 200000,
    );
    expect(matcher.match(entry), song);
  });
}
