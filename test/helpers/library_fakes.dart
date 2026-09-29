import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:taki/features/library/domain/entities/song.dart';
import 'package:taki/features/library/domain/ports/artwork_repository.dart';
import 'package:taki/features/library/domain/ports/media_permission_port.dart';
import 'package:taki/features/library/domain/ports/song_repository.dart';
import 'package:taki/features/library/domain/ports/favorites_repository.dart';
import 'package:taki/features/library/presentation/providers/favorites_providers.dart';
import 'package:taki/features/library/presentation/providers/library_providers.dart';
import 'package:taki/features/player/domain/ports/audio_player_port.dart';
import 'package:taki/features/player/domain/ports/notification_permission_port.dart';
import 'package:taki/features/player/presentation/providers/player_providers.dart';
import 'package:taki/features/playlists/domain/ports/playlists_repository.dart';
import 'package:taki/features/playlists/presentation/providers/playlists_providers.dart';

import 'favorites_fakes.dart';
import 'player_fakes.dart';
import 'playlists_fakes.dart';

class MockSongRepository extends Mock implements SongRepository {}

class MockMediaPermission extends Mock implements MediaPermissionPort {}

class NoArtworkRepository implements ArtworkRepository {
  @override
  Future<Uint8List?> getAlbumArtwork(int albumId, {required int size}) async =>
      null;
}

Song buildSong({
  int id = 1,
  String title = 'Canción',
  String? artist = 'Artista',
  int durationMs = 180000,
  int? albumId = 10,
  String folder = 'Music/',
}) {
  return Song(
    id: id,
    title: title,
    artist: artist,
    album: 'Álbum',
    albumId: albumId,
    durationMs: durationMs,
    path: '/storage/emulated/0/$folder$title.mp3',
    contentUri: 'content://media/external/audio/media/$id',
    dateAdded: DateTime(2026, 9, 1),
    folder: folder,
  );
}

/// Overrides de la biblioteca con dobles de prueba (sin canales nativos).
List<Override> libraryOverrides({
  required MediaPermissionPort permission,
  required SongRepository songs,
  AudioPlayerPort? player,
  NotificationPermissionPort? notifications,
  FavoritesRepository? favorites,
  PlaylistsRepository? playlists,
}) {
  return [
    mediaPermissionProvider.overrideWithValue(permission),
    songRepositoryProvider.overrideWithValue(songs),
    artworkRepositoryProvider.overrideWithValue(NoArtworkRepository()),
    audioPlayerPortProvider.overrideWithValue(player ?? FakeAudioPlayerPort()),
    notificationPermissionProvider.overrideWithValue(
      notifications ?? FakeNotificationPermission(),
    ),
    favoritesRepositoryProvider.overrideWithValue(
      favorites ?? FakeFavoritesRepository(),
    ),
    playlistsRepositoryProvider.overrideWithValue(
      playlists ?? FakePlaylistsRepository(),
    ),
  ];
}

/// Permiso concedido y biblioteca vacía: la configuración neutra para tests.
List<Override> grantedEmptyLibraryOverrides() {
  final permission = MockMediaPermission();
  when(permission.isGranted).thenAnswer((_) async => true);
  final songs = MockSongRepository();
  when(songs.getSongs).thenAnswer((_) async => []);
  return libraryOverrides(permission: permission, songs: songs);
}
