import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/entities/song.dart';

/// Acción adicional propia de una pantalla (p. ej. "Quitar de la playlist").
class ExtraSongAction {
  const ExtraSongAction({
    required this.icon,
    required this.label,
    required this.onSelected,
  });

  final IconData icon;
  final String label;
  final Future<void> Function() onSelected;
}

/// Abre el menú de acciones de una canción (pulsación larga o menú "⋯").
///
/// El menú combina varias features (cola, favoritos, playlists), así que lo
/// implementa `app/` y las páginas lo reciben por constructor: las features
/// no dependen de `app/`.
typedef ShowSongActions = Future<void> Function(
  BuildContext context,
  WidgetRef ref,
  Song song, {
  List<ExtraSongAction> extraActions,
});
