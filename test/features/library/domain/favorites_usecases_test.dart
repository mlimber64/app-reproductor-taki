import 'package:flutter_test/flutter_test.dart';
import 'package:taki/features/library/domain/entities/favorite_entry.dart';
import 'package:taki/features/library/domain/usecases/favorites_usecases.dart';

import '../../../helpers/favorites_fakes.dart';
import '../../../helpers/library_fakes.dart';

void main() {
  late FakeFavoritesRepository favorites;

  setUp(() => favorites = FakeFavoritesRepository());

  group('ToggleFavorite', () {
    test('añade si no era favorita y quita si lo era', () async {
      final song = buildSong(id: 7);
      final toggle = ToggleFavorite(favorites);

      expect(await toggle(song), isTrue);
      expect(favorites.entries.keys, [7]);

      expect(await toggle(song), isFalse);
      expect(favorites.entries, isEmpty);
    });
  });

  group('GetFavoriteSongs', () {
    FavoriteEntry stored({
      required int songId,
      required int minute,
      String? title,
      String? artist,
      int? durationMs,
      String? path,
    }) {
      return FavoriteEntry(
        songId: songId,
        addedAt: DateTime(2026, 9, 1, 12, minute),
        title: title,
        artist: artist,
        durationMs: durationMs,
        path: path,
      );
    }

    test('coincide por id, en orden de añadido (más recientes primero)',
        () async {
      final a = buildSong(id: 1, title: 'A');
      final b = buildSong(id: 2, title: 'B');
      favorites
        ..seed(stored(songId: 1, minute: 1))
        ..seed(stored(songId: 2, minute: 2));

      final songs = await GetFavoriteSongs(favorites)([a, b]);

      expect(songs, [b, a]);
      expect(favorites.relinks, isEmpty);
    });

    test('si el id cambió, coincide por ruta y guarda el id nuevo', () async {
      final song = buildSong(id: 50, title: 'Otra etiqueta');
      favorites.seed(stored(songId: 5, minute: 1, path: song.path));

      final songs = await GetFavoriteSongs(favorites)([song]);

      expect(songs, [song]);
      expect(favorites.relinks, [(5, 50)]);
      expect(favorites.entries.keys, [50]);
    });

    test('si tampoco hay ruta, coincide por título + artista + duración',
        () async {
      final song = buildSong(
        id: 60,
        title: 'Mi Canción',
        artist: 'Mi Artista',
        durationMs: 200400,
      );
      favorites.seed(stored(
        songId: 6,
        minute: 1,
        title: '  mi canción ',
        artist: 'MI ARTISTA',
        durationMs: 200000,
        path: '/sdcard/antes/mi_cancion.mp3',
      ));

      final songs = await GetFavoriteSongs(favorites)([song]);

      expect(songs, [song]);
      expect(favorites.relinks, [(6, 60)]);
    });

    test('no coincide si la duración difiere más de 1 s', () async {
      final song = buildSong(id: 60, title: 'T', artist: 'X', durationMs: 5000);
      favorites.seed(stored(
        songId: 6,
        minute: 1,
        title: 'T',
        artist: 'X',
        durationMs: 7000,
      ));

      expect(await GetFavoriteSongs(favorites)([song]), isEmpty);
    });

    test('los ausentes de la biblioteca se ocultan pero siguen guardados',
        () async {
      final present = buildSong(id: 1, title: 'Presente');
      favorites
        ..seed(stored(songId: 1, minute: 1))
        ..seed(stored(
          songId: 9,
          minute: 2,
          title: 'En la SD',
          durationMs: 1000,
          path: '/storage/sd/en_la_sd.mp3',
        ));

      final songs = await GetFavoriteSongs(favorites)([present]);

      expect(songs, [present]);
      expect(favorites.entries.keys, containsAll([1, 9]));
      expect(favorites.relinks, isEmpty);
    });

    test('dos registros que apuntan a la misma canción no la duplican',
        () async {
      final song = buildSong(id: 1, title: 'A');
      favorites
        ..seed(stored(songId: 1, minute: 1))
        ..seed(stored(songId: 2, minute: 2, path: song.path));

      expect(await GetFavoriteSongs(favorites)([song]), [song]);
    });

    test('sin favoritos devuelve una lista vacía', () async {
      expect(await GetFavoriteSongs(favorites)([buildSong()]), isEmpty);
    });
  });
}
