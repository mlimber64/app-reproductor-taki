import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/taki_database_provider.dart';
import '../../../../core/domain/entities/music_identity.dart';
import '../../../../core/domain/entities/song.dart';
import '../../../../core/lookup/song_lookup_providers.dart';
import '../../domain/ports/play_history_repository.dart';
import '../../domain/usecases/recent_songs_usecases.dart';
import '../../infrastructure/sqflite_play_history_repository.dart';

/// How many recent songs the library shows.
const int recentSongsLimit = 20;

final playHistoryRepositoryProvider = Provider<PlayHistoryRepository>((ref) {
  final repository = SqflitePlayHistoryRepository(
    () => ref.read(takiDatabaseProvider.future),
  );
  ref.onDispose(repository.dispose);
  return repository;
});

/// Recently played identities; updates after every recorded play.
final recentIdentitiesProvider = StreamProvider<List<MusicIdentity>>(
  (ref) => ref
      .watch(playHistoryRepositoryProvider)
      .watchRecent(limit: recentSongsLimit),
);

final getRecentSongsProvider = Provider<GetRecentSongs>(
  (ref) => GetRecentSongs(ref.watch(songLookupProvider)),
);

/// Recently played songs that can still be resolved, newest first.
final recentSongsProvider = FutureProvider<List<Song>>((ref) async {
  final identities = await ref.watch(recentIdentitiesProvider.future);
  return ref.read(getRecentSongsProvider).call(identities);
});
