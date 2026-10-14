import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';

import '../../../core/domain/ports/artwork_repository.dart';
import '../../../core/domain/ports/playback_resolver.dart';
import '../../../core/domain/ports/remote_artwork_loader.dart';
import '../domain/ports/equalizer_port.dart';
import 'artwork_file_cache.dart';
import 'just_audio_equalizer.dart';
import 'just_audio_player_adapter.dart';
import 'taki_audio_handler.dart';

/// Resultado de inicializar la reproducción: el motor y su handler de sistema.
typedef PlayerBootstrap = ({
  JustAudioPlayerAdapter player,
  TakiAudioHandler handler,
  EqualizerPort equalizer,
});

/// Configura la sesión de audio e inicia audio_service. Llamar una vez, antes
/// de `runApp`.
///
/// Con `AudioSessionConfiguration.music()` just_audio pausa ante llamadas y
/// otras apps (y reanuda si la interrupción era temporal), deja que Android
/// baje el volumen cuando corresponde (ducking) y pausa al desconectar los
/// auriculares.
Future<PlayerBootstrap> initPlayer({
  required ArtworkRepository artwork,
  PlaybackResolver? resolver,
  RemoteArtworkLoader? remoteArtworkLoader,
}) async {
  final session = await AudioSession.instance;
  await session.configure(const AudioSessionConfiguration.music());

  // The equalizer lives in the player's audio pipeline, so it has to exist
  // before the player does.
  final androidEqualizer = AndroidEqualizer();
  final player = JustAudioPlayerAdapter(
    player: AudioPlayer(
      useLazyPreparation: true,
      audioPipeline: AudioPipeline(androidAudioEffects: [androidEqualizer]),
    ),
    resolver: resolver,
  );
  final handler = await AudioService.init(
    builder: () => TakiAudioHandler(
      player,
      ArtworkFileCache(artwork, remoteArtworkLoader: remoteArtworkLoader),
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

  return (
    player: player,
    handler: handler,
    equalizer: JustAudioEqualizer(androidEqualizer),
  );
}
