import 'package:flutter/material.dart';

import '../theme/taki_colors.dart';
import '../theme/taki_icon_size.dart';
import '../theme/taki_motion.dart';
import 'taki_icon_button.dart';
import 'taki_interaction.dart';

/// Modo de repetición que muestran los controles. Quien los usa traduce el
/// suyo (p. ej. el del reproductor) a este.
enum TakiRepeatMode {
  off('desactivado'),
  all('todas'),
  one('una');

  const TakiRepeatMode(this.semanticValue);

  /// Valor que anuncia el lector de pantalla.
  final String semanticValue;
}

/// Controles de transporte de Taki (docs/DESIGN_SYSTEM.md §11, §17):
/// aleatorio · anterior · **play/pausa** · siguiente · repetir.
///
/// Solo presentación: recibe el estado y avisa por callbacks; no sabe qué
/// suena ni cómo. Un callback `null` deja su control deshabilitado (38 %).
///
/// - Play/pausa: círculo de 72 en `primary`, icono de 40 en `onPrimary`,
///   `primaryPressed` al pulsar; con [isLoading], spinner en lugar del icono.
///   El cambio play ↔ pausa es un fundido con escala (§18).
/// - Aleatorio y repetir activos: icono en `primary` sobre un círculo
///   `primaryContainer` (forma **y** color); "repetir una" usa además su
///   propio icono. Se anuncian como interruptores; repetir, con su modo.
class TakiPlaybackControls extends StatelessWidget {
  const TakiPlaybackControls({
    super.key,
    required this.isPlaying,
    required this.onPlayPause,
    required this.onPrevious,
    required this.onNext,
    this.isLoading = false,
    this.isShuffleEnabled = false,
    this.repeatMode = TakiRepeatMode.off,
    this.onShuffle,
    this.onRepeat,
  });

  final bool isPlaying;
  final bool isLoading;
  final bool isShuffleEnabled;
  final TakiRepeatMode repeatMode;
  final VoidCallback? onPlayPause;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final VoidCallback? onShuffle;
  final VoidCallback? onRepeat;

  static const String shuffleLabel = 'Aleatorio';
  static const String repeatLabel = 'Repetir';
  static const String previousLabel = 'Anterior';
  static const String nextLabel = 'Siguiente';
  static const String playLabel = 'Reproducir';
  static const String pauseLabel = 'Pausar';
  static const String loadingValue = 'Cargando';

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: TakiPlayPauseButton.size,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _ToggleControl(
            icon: Icons.shuffle_rounded,
            label: shuffleLabel,
            active: isShuffleEnabled,
            onPressed: onShuffle,
          ),
          TakiIconButton(
            icon: Icons.skip_previous_rounded,
            semanticLabel: previousLabel,
            iconSize: TakiIconSize.xl,
            onPressed: onPrevious,
          ),
          TakiPlayPauseButton(
            isPlaying: isPlaying,
            isLoading: isLoading,
            onPressed: onPlayPause,
          ),
          TakiIconButton(
            icon: Icons.skip_next_rounded,
            semanticLabel: nextLabel,
            iconSize: TakiIconSize.xl,
            onPressed: onNext,
          ),
          _ToggleControl(
            icon: repeatMode == TakiRepeatMode.one
                ? Icons.repeat_one_rounded
                : Icons.repeat_rounded,
            label: repeatLabel,
            value: repeatMode.semanticValue,
            active: repeatMode != TakiRepeatMode.off,
            onPressed: onRepeat,
          ),
        ],
      ),
    );
  }
}

/// Botón principal de reproducción (§11): círculo de 72 en `primary`.
///
/// Es el único control de la app con fondo naranja y el más grande: la acción
/// principal de Reproduciendo.
class TakiPlayPauseButton extends StatelessWidget {
  const TakiPlayPauseButton({
    super.key,
    required this.isPlaying,
    required this.onPressed,
    this.isLoading = false,
  });

  final bool isPlaying;
  final bool isLoading;
  final VoidCallback? onPressed;

  /// Diámetro del círculo (§11).
  static const double size = 72;

  @override
  Widget build(BuildContext context) {
    final iconSize = TakiIconSize.hero.value;
    final label = isPlaying
        ? TakiPlaybackControls.pauseLabel
        : TakiPlaybackControls.playLabel;

    return Semantics(
      container: true,
      button: true,
      enabled: onPressed != null && !isLoading,
      label: label,
      value: isLoading ? TakiPlaybackControls.loadingValue : null,
      child: Tooltip(
        message: label,
        excludeFromSemantics: true,
        child: TakiPressable(
          // Mientras carga no se puede pulsar (evita toques repetidos).
          onPressed: isLoading ? null : onPressed,
          builder: (context, states) {
            final disabled = onPressed == null;
            final background = disabled
                ? TakiColors.disabledContainer
                : states.contains(WidgetState.pressed)
                    ? TakiColors.primaryPressed
                    : TakiColors.primary;
            final foreground =
                disabled ? TakiColors.disabledContent : TakiColors.onPrimary;

            return TakiFocusRing(
              visible: states.contains(WidgetState.focused),
              shape: const CircleBorder(),
              color: TakiColors.focusRingOnPrimary,
              child: Container(
                width: size,
                height: size,
                decoration: ShapeDecoration(
                  shape: const CircleBorder(),
                  color: background,
                ),
                alignment: Alignment.center,
                child: ExcludeSemantics(
                  child: AnimatedSwitcher(
                    duration: TakiMotion.short,
                    switchInCurve: TakiMotion.change,
                    switchOutCurve: TakiMotion.change,
                    transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: ScaleTransition(scale: animation, child: child),
                    ),
                    child: isLoading
                        ? SizedBox.square(
                            key: const ValueKey('loading'),
                            dimension: iconSize,
                            child: CircularProgressIndicator(color: foreground),
                          )
                        : Icon(
                            isPlaying
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            key: ValueKey(isPlaying),
                            size: iconSize,
                            color: foreground,
                          ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Interruptor de aleatorio o repetir: 48 táctil, círculo de 40
/// `primaryContainer` solo cuando está activo.
class _ToggleControl extends StatelessWidget {
  const _ToggleControl({
    required this.icon,
    required this.label,
    required this.active,
    required this.onPressed,
    this.value,
  });

  final IconData icon;
  final String label;
  final String? value;
  final bool active;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      button: true,
      enabled: onPressed != null,
      toggled: active,
      label: label,
      value: value,
      child: Tooltip(
        message: label,
        excludeFromSemantics: true,
        child: TakiPressable(
          onPressed: onPressed,
          builder: (context, states) {
            final disabled = states.contains(WidgetState.disabled);
            final color = active ? TakiColors.active : TakiColors.iconSecondary;

            return SizedBox.square(
              dimension: TakiInteraction.minTouchTarget,
              child: Center(
                child: TakiFocusRing(
                  visible: states.contains(WidgetState.focused),
                  shape: const CircleBorder(),
                  child: AnimatedContainer(
                    duration: TakiMotion.short,
                    curve: TakiMotion.change,
                    width: TakiIconButton.containerSize,
                    height: TakiIconButton.containerSize,
                    decoration: ShapeDecoration(
                      shape: const CircleBorder(),
                      color: active
                          ? (disabled
                              ? TakiColors.disabledContainer
                              : TakiColors.primaryContainer)
                          : Colors.transparent,
                    ),
                    foregroundDecoration: ShapeDecoration(
                      shape: const CircleBorder(),
                      color: states.contains(WidgetState.pressed)
                          ? TakiColors.pressedOverlay
                          : null,
                    ),
                    child: ExcludeSemantics(
                      child: Icon(
                        icon,
                        size: TakiIconSize.md.value,
                        color: disabled
                            ? color.withValues(
                                alpha: TakiColors.disabledContentOpacity,
                              )
                            : color,
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
