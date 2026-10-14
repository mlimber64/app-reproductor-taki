import '../../../../core/domain/entities/music_identity.dart';

/// What the user has played, most recent first.
///
/// One entry per song (its [MusicIdentity]): playing it again moves it to the
/// front and counts one more play. Only identities are stored; the songs
/// themselves are resolved with the `SongLookup` when they are shown.
abstract interface class PlayHistoryRepository {
  /// Notes that [identity] has just started playing.
  Future<void> record(MusicIdentity identity);

  /// The [limit] most recently played identities, newest first.
  Future<List<MusicIdentity>> recent({int limit = 20});

  /// Emits the recent identities on subscription and after every [record].
  Stream<List<MusicIdentity>> watchRecent({int limit = 20});

  /// Forgets everything.
  Future<void> clear();
}
