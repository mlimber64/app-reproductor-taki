import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:taki/features/library/domain/usecases/favorites_usecases.dart';
import 'package:taki/features/library/domain/usecases/get_songs.dart';
import 'package:taki/features/playlists/domain/usecases/playlist_usecases.dart';
import 'package:taki/core/domain/entities/local_music_identity.dart';

import '../../../helpers/favorites_fakes.dart';
import '../../../helpers/library_fakes.dart';
import '../../../helpers/playlists_fakes.dart';

/// Favoritos y playlists cruzan con la biblioteca ya filtrada: lo que ahora
/// queda fuera (p. ej. una nota de voz) se oculta pero sigue guardado.
void main() {
  final song = buildSong(id: 1, title: 'Canción');
  final voiceNote = buildSong(
    id: 2,
    title: 'PTT-20260901-WA0001',
    folder: 'Android/media/com.whatsapp/WhatsApp/Media/WhatsApp Voice Notes/'
        '202609/',
  );

  late List<Object> library;

  setUp(() async {
    final repository = MockSongRepository();
    when(repository.getSongs).thenAnswer((_) async => [song, voiceNote]);
    library = await GetSongs(repository)();
  });

  test('la biblioteca filtrada ya no incluye la nota de voz', () {
    expect(library, [song]);
  });

  test('un favorito filtrado se oculta y sigue guardado', () async {
    final favorites = FakeFavoritesRepository();
    favorites
      ..seed(favorites.entryFor(song))
      ..seed(favorites.entryFor(voiceNote));

    final visible = await GetFavoriteSongs(favorites, localLookupOver([song]))([song]);

    expect(visible, [song]);
    expect(favorites.entries.keys, containsAll([localMusicIdentity(1), localMusicIdentity(2)]));
    expect(favorites.relinks, isEmpty);
  });

  test('una entrada de playlist filtrada se oculta y sigue guardada',
      () async {
    final playlists = FakePlaylistsRepository();
    final id = playlists.seed('Mix', songs: [voiceNote, song]);

    final items = await GetPlaylistSongs(playlists, localLookupOver([song]))(id, [song]);

    expect(items.map((i) => i.song), [song]);
    expect(playlists.entriesOf(id).map((e) => e.musicIdentity), [localMusicIdentity(2), localMusicIdentity(1)]);
    expect(playlists.relinks, isEmpty);
  });
}
