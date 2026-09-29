import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';

import '../../../core/domain/ports/artwork_repository.dart';
import 'artwork_file_cache.dart';
import 'just_audio_player_adapter.dart';
import 'taki_audio_handler.dart';

/// Resultado de inicializar la reproducción: el motor y su handler de sistema.
typedef PlayerBootstrap = ({
  JustAudioPlayerAdapter player,
  TakiAudioHandler handler,
});

/// Configura la sesión de audio e inicia audio_service. Llamar una vez, antes
/// de `runApp`.
///
/// Con `AudioSessionConfiguration.music()` just_audio pausa ante llamadas y
/// otras apps (y reanuda si la interrupción era temporal), deja que Android
/// baje el volumen cuando corresponde (ducking) y pausa al desconectar los
/// auriculares.
Future<PlayerBootstrap> initPlayer({required ArtworkRepository artwork}) async {
  final session = await AudioSession.instance;
  await session.configure(const AudioSessionConfiguration.music());

  final player = JustAudioPlayerAdapter();
  final handler = await AudioService.init(
    builder: () => TakiAudioHandler(
      player,
      ArtworkFileCache(artwork),
    ),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.limbermendoza.taki.playback',
      androidNotificationChannelName: 'Reproducción de Taki',
      androidNotificationChannelDescription:
          'Controles de la música que está sonando',
      androidNotificationIcon: 'drawable/ic_stat_taki',
      androidStopForegroundOnPause: true,
    ),
  );

  return (player: player, handler: handler);
}
