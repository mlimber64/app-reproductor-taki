/// Constantes de la biblioteca musical.
abstract final class LibraryConstants {
  /// Los audios más cortos que esto (notas de voz, tonos) no se muestran.
  static const Duration minSongDuration = Duration(seconds: 30);

  /// Carpetas cuyos audios no son canciones. Se comparan por nombre completo
  /// de carpeta (segmento de la ruta), sin distinguir mayúsculas: "Recordings"
  /// excluye "Music/Recordings" pero no "Live Recordings Vol1".
  static const List<String> excludedFolders = [
    'WhatsApp Voice Notes',
    'WhatsApp Audio',
    'WhatsApp Business Voice Notes',
    'WhatsApp Business Audio',
    'Recordings',
    'Voice Recorder',
    'Sound Recorder',
    'Call',
    'Call Recordings',
    'Voice Notes',
    'Notifications',
    'Ringtones',
    'Alarms',
    'Podcasts',
    'Audiobooks',
  ];
}
