import '../entities/music_identity.dart';
import '../entities/song_lookup_failure.dart';
import '../entities/song_lookup_result.dart';
import '../ports/song_lookup.dart';

/// Enruta cada identidad al [SongLookup] **de su fuente** (`identity.source`).
///
/// Es el punto donde una fuente nueva se registra sin tocar favoritos,
/// playlists ni la UI: basta añadir su etiqueta al mapa.
///
/// - Identidad de una fuente **sin lookup registrado** → `unsupported` (no se
///   inventa nada, no se trata como local y no se confunde con `missing`).
/// - Los lookups se consultan una vez por fuente, en paralelo.
/// - Si un lookup falla (`SongLookupFailure`), el fallo se **propaga**: el
///   lote entero falla. Aislar fallos por fuente exigiría que la UI sepa
///   mostrar resultados parciales; se decidirá con la segunda fuente real.
/// - Hace cumplir el contrato: una identidad que el lookup no contabilizó pasa a
///   `missing`; una canción devuelta bajo una identidad que no es la suya es un
///   error (`SongLookupFailure`).
class SourceSongLookup implements SongLookup {
  SourceSongLookup(Map<String, SongLookup> bySource)
      : _bySource = Map.unmodifiable(bySource);

  final Map<String, SongLookup> _bySource;

  @override
  Future<SongLookupResult> findAll(Iterable<MusicIdentity> identities) async {
    final bySource = <String, Set<MusicIdentity>>{};
    for (final identity in identities) {
      (bySource[identity.source] ??= {}).add(identity);
    }

    final unsupported = <MusicIdentity>{};
    final pending = <Future<SongLookupResult>>[];
    for (final MapEntry(key: source, value: group) in bySource.entries) {
      final lookup = _bySource[source];
      if (lookup == null) {
        unsupported.addAll(group);
        continue;
      }
      pending.add(_resolve(source, lookup, group));
    }

    var result = SongLookupResult(unsupported: unsupported);
    for (final partial in await Future.wait(pending)) {
      result = result.merge(partial);
    }
    return result;
  }

  Future<SongLookupResult> _resolve(
    String source,
    SongLookup lookup,
    Set<MusicIdentity> group,
  ) async {
    final SongLookupResult raw;
    try {
      raw = await lookup.findAll(group);
    } on SongLookupFailure {
      rethrow;
    } catch (error) {
      throw SongLookupFailure(
        'el lookup de la fuente falló',
        source: source,
        cause: error,
      );
    }

    for (final MapEntry(key: identity, value: song) in raw.found.entries) {
      if (song.musicIdentity != identity) {
        throw SongLookupFailure(
          'devolvió una canción con otra identidad '
          '(${song.musicIdentity}) para $identity',
          source: source,
        );
      }
    }

    // Solo cuentan las identidades pedidas; las no contabilizadas son `missing`.
    final found = {
      for (final identity in group) identity: ?raw.found[identity],
    };
    final unsupported = {
      for (final identity in group)
        if (!found.containsKey(identity) && raw.unsupported.contains(identity))
          identity,
    };
    final missing = {
      for (final identity in group)
        if (!found.containsKey(identity) && !unsupported.contains(identity))
          identity,
    };
    return SongLookupResult(
      found: found,
      missing: missing,
      unsupported: unsupported,
    );
  }
}
