import 'package:flutter/animation.dart';

/// Duraciones y curvas de Taki (docs/DESIGN_SYSTEM.md §18).
///
/// Una animación existe solo si explica un cambio. Si el sistema pide
/// reducir animaciones, los desplazamientos pasan a ser fundidos.
abstract final class TakiMotion {
  /// Respuesta al pulsar (capa, escala).
  static const Duration instant = Duration(milliseconds: 100);

  /// Fundidos de icono, aparición de artwork.
  static const Duration short = Duration(milliseconds: 150);

  /// Bottom sheets, SnackBars, aparición del mini player.
  static const Duration medium = Duration(milliseconds: 250);

  /// Un ciclo del indicador "sonando"; solo se repite mientras suena.
  static const Duration playingLoop = Duration(milliseconds: 900);

  /// Pantallas completas que suben (Reproduciendo, Cola): entrada y salida.
  static const Duration longEnter = Duration(milliseconds: 320);
  static const Duration longExit = Duration(milliseconds: 260);

  /// Algo aparece o llega.
  static const Curve enter = Curves.easeOutCubic;

  /// Algo se va.
  static const Curve exit = Curves.easeInCubic;

  /// Cambia el estado de un elemento que permanece.
  static const Curve change = Curves.easeInOutCubic;

  /// Escala del botón primario y de las tarjetas mientras se pulsan (§17).
  static const double pressedScale = 0.98;
}
