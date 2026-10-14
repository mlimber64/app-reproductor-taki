import 'music_identity.dart';

/// Etiqueta de fuente de las canciones de la biblioteca local del dispositivo.
///
/// Es una etiqueta más, igual de opaca que cualquier otra: el dominio solo la
/// compara. La usan las canciones que hoy identifica el `_ID` de MediaStore.
const String localMusicSource = 'local';

/// Identidad de una canción local a partir de su id local (hoy, el `_ID` de
/// MediaStore).
///
/// Es **el único sitio** donde un entero local se convierte en [MusicIdentity]:
/// `externalId` es el entero en decimal (`42` → `"42"`). Esa conversión no
/// forma parte de [MusicIdentity], que no sabe de enteros ni de MediaStore.
MusicIdentity localMusicIdentity(int localId) =>
    MusicIdentity(localMusicSource, localId.toString());
