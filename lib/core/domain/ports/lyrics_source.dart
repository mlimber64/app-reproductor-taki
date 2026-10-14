import '../entities/lyrics.dart';

/// Finds the lyrics of a song.
///
/// Contract:
/// - Returns `null` when the provider has nothing for the song.
/// - Throws [LyricsLookupFailure] when it could not be asked (network, bad
///   answer). A failure is never turned into `null`.
/// - It sends the song's title, artist and duration to a third party, so it is
///   only called when the user asks for the lyrics.
abstract interface class LyricsSource {
  Future<Lyrics?> find(LyricsQuery query);
}
