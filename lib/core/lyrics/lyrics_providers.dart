import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/entities/lyrics.dart';
import '../domain/ports/lyrics_source.dart';

/// A source that never has lyrics: the default until `main.dart` injects the
/// real one, and what tests get unless they override it.
class NoLyricsSource implements LyricsSource {
  const NoLyricsSource();

  @override
  Future<Lyrics?> find(LyricsQuery query) async => null;
}

final lyricsSourceProvider = Provider<LyricsSource>(
  (ref) => const NoLyricsSource(),
);

/// Lyrics of one song, asked for the first time somebody watches it and kept
/// while the lyrics screen is open. `null`: the provider has none. Failures
/// surface as [LyricsLookupFailure] in the `AsyncValue`.
final lyricsProvider =
    FutureProvider.autoDispose.family<Lyrics?, LyricsQuery>(
  (ref, query) => ref.watch(lyricsSourceProvider).find(query),
);
