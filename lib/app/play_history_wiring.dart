import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/domain/entities/song.dart';
import '../features/library/presentation/providers/history_providers.dart';
import '../features/player/presentation/providers/player_providers.dart';

/// Writes every song that starts playing to the play history.
///
/// Watched once from the app root, which is the only place that knows both the
/// player and the library. A song counts when it becomes the current one; the
/// history is best effort and a failure to write it never reaches playback.
final playHistoryRecorderProvider = Provider<void>((ref) {
  ref.listen<AsyncValue<Song?>>(currentSongProvider, (previous, next) {
    final identity = next.valueOrNull?.musicIdentity;
    if (identity == null) return;
    if (identity == previous?.valueOrNull?.musicIdentity) return;
    ref
        .read(playHistoryRepositoryProvider)
        .record(identity)
        .catchError((Object _) {});
  });
});
