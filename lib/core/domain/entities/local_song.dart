import 'local_music_identity.dart';
import 'song.dart';

/// Canción de la **biblioteca local** del dispositivo (hoy, MediaStore).
///
/// Es una [Song] universal más los datos que solo tiene la fuente local:
/// - [id]: el `_ID` de MediaStore. Representación local; **no** es la identidad
///   (eso es `musicIdentity`) ni se persiste.
/// - [albumId]: álbum de MediaStore, del que sale la carátula local. No es una
///   identidad.
/// - [path]: ruta del archivo. Solo informativa: en Android 10+ no se garantiza
///   acceso directo; para reproducir se usa [contentUri].
/// - [contentUri]: URI con la que se abre el audio (`content://media/...`). Lo
///   lee `LocalPlaybackResolver` para producir un `PlaybackResource`.
/// - [folder]: carpeta que contiene el archivo; vacía si la fuente no la conoce.
///
/// **La identidad sale de [id]** (`localMusicIdentity(id)`) y no se puede pasar:
/// así es imposible una `LocalSong` con `id = 42` e identidad `local/43`.
///
/// [artwork] es explícito (como en `Song`): el repositorio local lo construye a
/// partir de [albumId] (`localArtworkReference`). Se mantiene explícito para que
/// la UI nunca tenga que leer [albumId].
///
/// Dart puro: no importa MediaStore ni Flutter. Vive en `core/domain` junto a
/// `localMusicIdentity`, `LocalPlaybackResolver` y `LocalArtworkResolver`, que
/// son quienes la leen y no pueden depender de una feature.
class LocalSong extends Song {
  LocalSong({
    required this.id,
    required super.title,
    required super.artist,
    required super.album,
    required super.artwork,
    required super.durationMs,
    required this.albumId,
    required this.path,
    required this.contentUri,
    this.folder = '',
  }) : super(musicIdentity: localMusicIdentity(id));

  final int id;
  final int? albumId;
  final String path;
  final String contentUri;
  final String folder;

  @override
  List<Object?> get props => [
        ...super.props,
        id,
        albumId,
        path,
        contentUri,
        folder,
      ];
}

/// Ruta de archivo de [song] **si es local**, o `null`.
///
/// Es el único punto donde la persistencia (respaldo de favoritos y playlists)
/// lee un dato local de una `Song` universal: la ruta solo sirve para
/// reencontrar canciones de la biblioteca local (`SongMatcher`). Las canciones
/// de otras fuentes no tienen ruta y se guardan sin ella.
String? localPathOf(Song song) => song is LocalSong ? song.path : null;
