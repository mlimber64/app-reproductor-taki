import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/domain/entities/local_music_identity.dart';
import '../core/domain/entities/local_song.dart';
import '../core/domain/ports/song_lookup.dart';
import '../core/domain/services/source_song_lookup.dart';
import '../core/lookup/song_lookup_providers.dart';
import '../features/audius/domain/entities/audius_track.dart';
import '../features/jamendo/domain/entities/jamendo_track.dart';
import '../features/library/domain/services/local_song_lookup.dart';
import '../features/library/presentation/providers/songs_notifier.dart';
import 'audius_wiring.dart';
import 'jamendo_wiring.dart';

SongLookup buildSongLookup(Ref ref) {
  final jamendo = ref.read(jamendoServicesProvider);
  final audius = ref.read(audiusServicesProvider);
  return SourceSongLookup({
    localMusicSource: LocalSongLookup(() async {
      final library = await ref.read(songsProvider.future);
      return library is LibraryLoaded ? library.songs : const <LocalSong>[];
    }),
    if (jamendo != null) jamendoSource: jamendo.lookup,
    if (audius != null) audiusSource: audius.lookup,
  });
}

Override songLookupOverride() =>
    songLookupProvider.overrideWith(buildSongLookup);
