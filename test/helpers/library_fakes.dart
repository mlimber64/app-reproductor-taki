import 'dart:typed_data';

import 'package:taki/features/library/domain/services/local_song_lookup.dart';
import 'package:taki/core/domain/services/source_song_lookup.dart';
import 'package:taki/core/domain/ports/song_lookup.dart';
import 'package:taki/core/domain/entities/local_music_identity.dart';
import 'package:taki/app/song_lookup_wiring.dart';
import 'package:taki/core/catalog/catalog_sources_providers.dart';
import 'package:taki/core/domain/ports/catalog_sources.dart';
import 'package:taki/core/domain/services/source_catalog_sources.dart';
import 'package:taki/core/domain/entities/artwork_reference.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:taki/core/artwork/artwork_providers.dart';
import 'package:taki/core/domain/entities/local_song.dart';
import 'package:taki/core/domain/ports/artwork_repository.dart';
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

LocalSong buildSong({
  int id = 1,
  String title = 'Canción',
  String? artist = 'Artista',
  int durationMs = 180000,
  int? albumId = 10,
  ArtworkReference? artwork,
  String folder = 'Music/',
}) {
  return LocalSong(
    id: id,
    title: title,
    artist: artist,
    album: 'Álbum',
    albumId: albumId,
    // Como el repositorio local: sale del albumId salvo que el test fije otra.
    artwork: artwork ?? localArtworkReference(albumId),
    durationMs: durationMs,
    path: '/storage/emulated/0/$folder$title.mp3',
    contentUri: 'content://media/external/audio/media/$id',
    folder: folder,
  );
}

/// Lookup solo local sobre una biblioteca en memoria (como el cableado real,
/// pero sin providers): para probar los casos de uso.
SongLookup localLookupOver(List<LocalSong> library) => SourceSongLookup({
      localMusicSource: LocalSongLookup(() async => library),
    });

/// Overrides de la biblioteca con dobles de prueba (sin canales nativos).
List<Override> libraryOverrides({
  required MediaPermissionPort permission,
  required SongRepository songs,
  AudioPlayerPort? player,
  NotificationPermissionPort? notifications,
  FavoritesRepository? favorites,
  PlaylistsRepository? playlists,

  /// Por defecto, sin catálogo: la navegación conserva sus 4 pestañas.
  CatalogSources? catalogSources,
}) {
  return [
    catalogSourcesProvider.overrideWithValue(
      catalogSources ?? SourceCatalogSources(const []),
    ),
    mediaPermissionProvider.overrideWithValue(permission),
    songLookupOverride(),
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
