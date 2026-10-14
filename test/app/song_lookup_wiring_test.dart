import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:taki/core/constants/library_constants.dart';
import 'package:taki/core/domain/entities/local_music_identity.dart';
import 'package:taki/core/domain/entities/music_identity.dart';
import 'package:taki/core/domain/entities/song_lookup_failure.dart';
import 'package:taki/core/lookup/song_lookup_providers.dart';

import '../helpers/library_fakes.dart';

/// El cableado real de la resolución de identidades: providers → biblioteca
/// (ya filtrada) → `LocalSongLookup` dentro de `SourceSongLookup`.
void main() {
  late MockMediaPermission permission;
  late MockSongRepository songs;

  setUp(() {
    permission = MockMediaPermission();
    when(permission.isGranted).thenAnswer((_) async => true);
    when(permission.isPermanentlyDenied).thenAnswer((_) async => false);
    songs = MockSongRepository();
  });

  ProviderContainer container() {
    final c = ProviderContainer(
      overrides: libraryOverrides(permission: permission, songs: songs),
    );
    addTearDown(c.dispose);
    return c;
  }

  test('resuelve una identidad local de la biblioteca', () async {
    final song = buildSong(id: 5);
    when(songs.getSongs).thenAnswer((_) async => [song]);

    final result = await container()
        .read(songLookupProvider)
        .findAll([localMusicIdentity(5)]);

    expect(result.found[localMusicIdentity(5)], song);
  });

  test('usa la biblioteca filtrada: un audio corto no se resuelve', () async {
    final tooShort = buildSong(
      id: 6,
      durationMs: LibraryConstants.minSongDuration.inMilliseconds - 1,
    );
    when(songs.getSongs).thenAnswer((_) async => [tooShort, buildSong(id: 7)]);

    final result = await container()
        .read(songLookupProvider)
        .findAll([localMusicIdentity(6), localMusicIdentity(7)]);

    expect(result.missing, {localMusicIdentity(6)});
    expect(result.found.keys, [localMusicIdentity(7)]);
  });

  test('una identidad de una fuente no registrada es unsupported', () async {
    when(songs.getSongs).thenAnswer((_) async => [buildSong(id: 5)]);
    final remote = MusicIdentity('proveedor', '5');

    final result = await container().read(songLookupProvider).findAll([remote]);

    expect(result.unsupported, {remote});
    expect(result.found, isEmpty);
  });

  test('sin permiso la biblioteca está vacía: las locales son missing',
      () async {
    when(permission.isGranted).thenAnswer((_) async => false);

    final result = await container()
        .read(songLookupProvider)
        .findAll([localMusicIdentity(5)]);

    expect(result.missing, {localMusicIdentity(5)});
  });

  test('si la biblioteca falla, el lookup falla (no devuelve «ausente»)',
      () async {
    when(songs.getSongs).thenAnswer((_) async => throw StateError('MediaStore'));

    await expectLater(
      container().read(songLookupProvider).findAll([localMusicIdentity(5)]),
      throwsA(isA<SongLookupFailure>()),
    );
  });

  test('sin override, el provider avisa de que falta el cableado', () {
    final bare = ProviderContainer();
    addTearDown(bare.dispose);

    expect(
      () => bare.read(songLookupProvider),
      throwsA(anything),
    );
  });
}
