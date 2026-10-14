import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/playback_error.dart';
import '../providers/player_providers.dart';

/// Textos del aviso cuando una canción no se puede reproducir. Breves y sin
/// detalles técnicos (ni URL, ni HTTP, ni nombres de excepciones, ni de
/// proveedor).
abstract final class PlaybackErrorTexts {
  static const String failed = 'No se pudo reproducir esta canción';
  static const String skipping = 'No se pudo reproducir. Pasando a la siguiente.';
}

/// Aviso para [error], o `null` si no corresponde mostrar nada.
///
/// - Sin canción **ni** posición en la cola el error no está ligado a ninguna
///   canción que el usuario intentara reproducir (evento interno): no hay aviso.
/// - [willSkip]: el reproductor va a pasar a la siguiente (ya existe y se
///   conserva: aquí solo se informa).
String? playbackErrorMessage(PlaybackError error, {required bool willSkip}) {
  if (error.song == null && error.index == null) return null;
  return willSkip ? PlaybackErrorTexts.skipping : PlaybackErrorTexts.failed;
}

/// Muestra un aviso discreto (SnackBar) cuando el reproductor no puede
/// reproducir una canción. Solo **consume** `AudioPlayerPort.errors`: no toca la
/// cola, favoritos, playlists ni identidades, y no reintenta.
///
/// - Cada error es un intento de reproducción: se muestra uno por evento (la
///   misma canción dos veces en la cola da dos avisos, uno por intento).
/// - Una cascada (varias canciones seguidas) no encola avisos: cada uno
///   **reemplaza** al anterior, y queda el más reciente.
/// Se coloca en el `builder` de la app, sobre el navegador.
class PlaybackErrorListener extends ConsumerStatefulWidget {
  const PlaybackErrorListener({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<PlaybackErrorListener> createState() =>
      _PlaybackErrorListenerState();
}

class _PlaybackErrorListenerState extends ConsumerState<PlaybackErrorListener> {
  StreamSubscription<PlaybackError>? _subscription;

  @override
  void initState() {
    super.initState();
    // Suscripción directa al stream (no a un provider): un provider descartaría
    // dos eventos iguales seguidos, y cada intento fallido cuenta.
    final player = ref.read(audioPlayerPortProvider);
    _subscription = player.errors.listen(_onError);
  }

  void _onError(PlaybackError error) {
    if (!mounted) return;
    final willSkip = ref.read(audioPlayerPortProvider).state.hasNext;
    final message = playbackErrorMessage(error, willSkip: willSkip);
    if (message == null) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
