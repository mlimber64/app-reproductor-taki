import '../entities/music_identity.dart';
import '../entities/song_lookup_failure.dart';
import '../entities/song_lookup_result.dart';
import '../ports/song_lookup.dart';

/// Resultado de resolver identidades **aislando el fallo de cada fuente**.
///
/// [result] contiene solo lo que sí se resolvió (`found`/`missing`/
/// `unsupported`). [failed] son las identidades de las fuentes que lanzaron
/// `SongLookupFailure`: **no** están en `missing` (un fallo no es ausencia) y
/// quien las recibe no debe reencontrarlas ni borrarlas.
final class IsolatedSongLookupResult {
  const IsolatedSongLookupResult(this.result, this.failed);

  final SongLookupResult result;
  final Set<MusicIdentity> failed;
}

/// Resuelve [identities] con [lookup] **una fuente a la vez** (en paralelo), de
/// modo que el fallo de una fuente no inutilice las identidades de otra.
///
/// - Cada fuente (`identity.source`) se consulta con solo sus identidades.
/// - Si una fuente lanza [SongLookupFailure], sus identidades quedan en
///   [IsolatedSongLookupResult.failed]; las demás se resuelven normalmente.
/// - Si **todas** las fuentes consultadas fallan, no hay nada que mostrar y se
///   relanza el primer fallo (como antes con un fallo del lote).
/// - No cambia el contrato de [SongLookup]; no convierte fallos en `missing`.
Future<IsolatedSongLookupResult> findAllIsolatingSources(
  SongLookup lookup,
  Iterable<MusicIdentity> identities,
) async {
  final bySource = <String, Set<MusicIdentity>>{};
  for (final identity in identities) {
    (bySource[identity.source] ??= {}).add(identity);
  }
  if (bySource.isEmpty) {
    return const IsolatedSongLookupResult(SongLookupResult.empty, {});
  }

  final outcomes = await Future.wait([
    for (final group in bySource.values) _attempt(lookup, group),
  ]);

  var merged = SongLookupResult.empty;
  final failed = <MusicIdentity>{};
  SongLookupFailure? firstFailure;
  for (final outcome in outcomes) {
    if (outcome.failure case final failure?) {
      firstFailure ??= failure;
      failed.addAll(outcome.group);
    } else {
      merged = merged.merge(outcome.result!);
    }
  }
  // Todas las fuentes fallaron: no hay nada que mostrar.
  if (firstFailure != null && outcomes.every((o) => o.failure != null)) {
    throw firstFailure;
  }
  return IsolatedSongLookupResult(merged, failed);
}

Future<_Outcome> _attempt(SongLookup lookup, Set<MusicIdentity> group) async {
  try {
    return _Outcome(group, result: await lookup.findAll(group));
  } on SongLookupFailure catch (failure) {
    return _Outcome(group, failure: failure);
  }
}

final class _Outcome {
  const _Outcome(this.group, {this.result, this.failure});

  final Set<MusicIdentity> group;
  final SongLookupResult? result;
  final SongLookupFailure? failure;
}
