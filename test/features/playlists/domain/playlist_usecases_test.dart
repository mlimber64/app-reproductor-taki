import 'package:flutter_test/flutter_test.dart';
import 'package:taki/features/playlists/domain/entities/playlist_entry.dart';
import 'package:taki/features/playlists/domain/entities/playlist_name.dart';
import 'package:taki/features/playlists/domain/usecases/playlist_usecases.dart';

import '../../../helpers/library_fakes.dart';
import '../../../helpers/playlists_fakes.dart';

void main() {
  late FakePlaylistsRepository playlists;

  final a = buildSong(id: 1, title: 'A');
  final b = buildSong(id: 2, title: 'B');
  final c = buildSong(id: 3, title: 'C');

  setUp(() => playlists = FakePlaylistsRepository());

  group('nombre', () {
    test('se recorta y no puede quedar vacío', () async {
      final id = await CreatePlaylist(playlists)('  Para correr  ');
      expect(playlists.namesInOrder(), ['Para correr']);

      await expectLater(
        CreatePlaylist(playlists)('   '),
        throwsA(isA<InvalidPlaylistNameException>()
            .having((e) => e.error, 'error', PlaylistNameError.empty)),
      );
      await expectLater(
        RenamePlaylist(playlists)(id, ''),
        throwsA(isA<InvalidPlaylistNameException>()),
      );
    });

    test('máximo 60 caracteres (tras recortar)', () async {
      await CreatePlaylist(playlists)('${'x' * 60}   ');
      await expectLater(
        CreatePlaylist(playlists)('x' * 61),
        throwsA(isA<InvalidPlaylistNameException>()
            .having((e) => e.error, 'error', PlaylistNameError.tooLong)),
      );
    });

    test('se permiten nombres repetidos', () async {
      await CreatePlaylist(playlists)('Mix');
      await CreatePlaylist(playlists)('Mix');
      expect(playlists.namesInOrder(), ['Mix', 'Mix']);
    });
  });

  test('renombrar y borrar delegan en el repositorio', () async {
    final id = await CreatePlaylist(playlists)('Vieja');
    await RenamePlaylist(playlists)(id, ' Nueva ');
    expect(playlists.namesInOrder(), ['Nueva']);

    await DeletePlaylist(playlists)(id);
    expect(playlists.namesInOrder(), isEmpty);
  });

  test('AddSongsToPlaylist añade al final y avisa si ya estaba', () async {
    final id = playlists.seed('Mix', songs: [a]);
    final add = AddSongsToPlaylist(playlists);

    expect(await add(id, [b]), isFalse);
    expect(await add(id, [a]), isTrue);
    expect(playlists.entriesOf(id).map((e) => e.songId), [1, 2, 1]);
  });

  test('RemoveFromPlaylist quita y undo la vuelve a su sitio', () async {
    final id = playlists.seed('Mix', songs: [a, b, c]);
    final entry = playlists.entriesOf(id)[1];
    final remove = RemoveFromPlaylist(playlists);

    await remove(entry);
    expect(playlists.entriesOf(id).map((e) => e.songId), [1, 3]);

    await remove.undo(entry);
    expect(playlists.entriesOf(id).map((e) => e.songId), [1, 2, 3]);
  });

  test('MovePlaylistSong delega e ignora movimientos nulos', () async {
    final id = playlists.seed('Mix', songs: [a, b, c]);
    final move = MovePlaylistSong(playlists);

    await move(id, 0, 2);
    await move(id, 1, 1);
    await move(id, -1, 0);

    expect(playlists.entriesOf(id).map((e) => e.songId), [2, 3, 1]);
  });

  group('GetPlaylistSongs', () {
    test('cruza con la biblioteca, en orden y con duplicados', () async {
      final id = playlists.seed('Mix', songs: [b, a, b]);

      final items = await GetPlaylistSongs(playlists)(id, [a, b, c]);

      expect(items.map((i) => i.song), [b, a, b]);
      expect(items.map((i) => i.entry.position), [0, 1, 2]);
    });

    test('reencuentra por ruta y guarda el id nuevo', () async {
      final id = playlists.seed('Mix');
      final moved = buildSong(id: 50, title: 'A');
      playlists.seedEntry(
        id,
        (entryId, position) => PlaylistEntry(
          id: entryId,
          playlistId: id,
          position: position,
          songId: 1,
          path: moved.path,
        ),
      );

      final items = await GetPlaylistSongs(playlists)(id, [moved]);

      expect(items.single.song, moved);
      expect(items.single.entry.songId, 50);
      expect(playlists.relinks, [(items.single.entry.id, 50)]);
      expect(playlists.entriesOf(id).single.songId, 50);
    });

    test('oculta las ausentes pero no las borra', () async {
      final id = playlists.seed('Mix', songs: [a, b, c]);

      final items = await GetPlaylistSongs(playlists)(id, [a, c]);

      expect(items.map((i) => i.song), [a, c]);
      expect(items.map((i) => i.entry.position), [0, 2]);
      expect(playlists.entriesOf(id), hasLength(3));
    });
  });
}
