import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/ports/song_lookup.dart';

// Resolución de identidades compartida por favoritos y playlists. Se compone
// fuera de `core` (en `lib/app/song_lookup_wiring.dart`) porque necesita la
// biblioteca local, que es de una feature; se inyecta con un override en
// `main.dart` y en los tests, como `artworkRepositoryProvider`.
final songLookupProvider = Provider<SongLookup>(
  (ref) => throw UnimplementedError(
    'songLookupProvider se sobrescribe en main.dart',
  ),
);
