import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/entities/artwork_reference.dart';
import 'artwork_cache.dart';
import 'artwork_providers.dart';

// Resolución compartida de carátulas: `ArtworkReference` + tamaño lógico →
// [ArtworkCache] → bytes → `ResizeImage(MemoryImage)`. Solo resuelve; no
// dibuja (eso lo hace `TakiArtwork`, que recibe el `ImageProvider?`) ni decide
// qué carátulas mostrar (eso es de quien lo usa). No sabe si la referencia es
// local o remota: eso lo despacha la caché.
//
// Sustituye a los adaptadores privados de cada pantalla. No usa la caché de
// imágenes de Flutter como fuente de verdad: la clave del `MemoryImage` son
// los bytes de la [ArtworkCache] (su identidad) y la del `ResizeImage` añade
// el ancho de decodificación. Tras `ArtworkCache.clear()` unos bytes nuevos
// dan una clave nueva, así que no se reutiliza una imagen decodificada vieja.
//
// Dos tamaños distintos, aunque hoy valgan lo mismo: el que se **pide** a la
// fuente (`ArtworkKey.size`) y el ancho al que se **decodifica**. La fuente
// puede devolver más píxeles de los pedidos; el `ResizeImage` limita la
// decodificación a ese ancho, nunca amplía y conserva la relación de aspecto
// (el recorte a cuadrado es de `TakiArtwork`).

/// Carátula de una [ArtworkReference] (normalmente `song.artwork`) como
/// `ImageProvider?`.
///
/// - [size] es el lado **lógico** con que se va a mostrar; la petición a la
///   caché es `(size × dpr).round()`. Si el llamador necesita un lado entero
///   (p. ej. Reproduciendo), lo redondea antes de pasarlo.
/// - Entrega `null` al [builder] mientras carga y si no hay carátula
///   (`Unavailable`, sin imagen, bytes vacíos o fallo de lectura):
///   `TakiArtwork` pinta entonces su placeholder.
/// - Vuelve a resolver si cambian [reference], [size] o el dpr. No reacciona a
///   `ArtworkCache.clear()` mientras la clave sea la misma.
class AlbumArtworkBuilder extends StatelessWidget {
  const AlbumArtworkBuilder.reference({
    super.key,
    required this.reference,
    required this.size,
    required this.builder,
  });

  final ArtworkReference reference;
  final double size;
  final Widget Function(BuildContext context, ImageProvider? image) builder;

  @override
  Widget build(BuildContext context) {
    return _AlbumImages(
      references: [reference],
      size: size,
      builder: (context, images) => builder(context, images.first),
    );
  }
}

/// Carátulas de varias referencias para un mosaico, como
/// `List<ImageProvider?>`.
///
/// - [references] las elige el llamador (distintas, máximo 4, en el orden que
///   quiera); aquí solo se resuelven, una a una y **sin reordenar ni quitar
///   duplicados**: la lista entregada al [builder] tiene la misma longitud y
///   orden.
/// - [size] es el lado lógico del **mosaico completo**; cada tesela se pide a
///   `floor(size / 2)` lógico × dpr (redondeado), como el `PlaylistCover`
///   anterior.
/// - `Unavailable`, sin imagen o bytes vacíos dan `null` en su posición. Vuelve
///   a resolver si cambian [references], [size] o el dpr.
class AlbumArtworkMosaicBuilder extends StatelessWidget {
  const AlbumArtworkMosaicBuilder({
    super.key,
    required this.references,
    required this.size,
    required this.builder,
  });

  final List<ArtworkReference> references;
  final double size;
  final Widget Function(BuildContext context, List<ImageProvider?> images)
      builder;

  @override
  Widget build(BuildContext context) {
    return _AlbumImages(
      references: references,
      size: (size / 2).floorToDouble(),
      builder: builder,
    );
  }
}

/// Resuelve una lista de álbumes al mismo tamaño lógico [size] cada uno.
class _AlbumImages extends ConsumerStatefulWidget {
  const _AlbumImages({
    required this.references,
    required this.size,
    required this.builder,
  });

  final List<ArtworkReference> references;
  final double size;
  final Widget Function(BuildContext context, List<ImageProvider?> images)
      builder;

  @override
  ConsumerState<_AlbumImages> createState() => _AlbumImagesState();
}

class _AlbumImagesState extends ConsumerState<_AlbumImages> {
  /// Clave de cada posición (`null` si el id es `null`).
  List<ArtworkKey?> _keys = const [];

  /// Ancho físico máximo de decodificación de cada imagen.
  int _decodeWidth = 1;
  final Map<ArtworkKey, Uint8List?> _bytes = {};
  final Set<ArtworkKey> _loading = {};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // También cuando cambia el dpr.
    _resolve();
  }

  @override
  void didUpdateWidget(_AlbumImages oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(oldWidget.references, widget.references) ||
        oldWidget.size != widget.size) {
      _resolve();
    }
  }

  void _resolve() {
    final pixels =
        (widget.size * MediaQuery.devicePixelRatioOf(context)).round();
    final keys = <ArtworkKey?>[
      for (final reference in widget.references)
        if (reference is UnavailableArtworkReference)
          null
        else
          (reference: reference, size: pixels),
    ];
    if (listEquals(keys, _keys)) return;
    _keys = keys;
    _decodeWidth = math.max(1, pixels);

    final wanted = {for (final key in keys) ?key};
    _bytes.removeWhere((key, _) => !wanted.contains(key));

    final cache = ref.read(artworkCacheProvider);
    for (final key in wanted) {
      if (_bytes.containsKey(key) || _loading.contains(key)) continue;
      if (cache.contains(key)) {
        _bytes[key] = cache.peek(key);
        continue;
      }

      _loading.add(key);
      cache.load(key).then((bytes) {
        _loading.remove(key);
        // Si mientras tanto cambió lo que se pide, el resultado sobra.
        if (mounted && _keys.contains(key)) {
          setState(() => _bytes[key] = bytes);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(context, [
      for (final key in _keys)
        switch (key == null ? null : _bytes[key]) {
          final bytes? when bytes.isNotEmpty => ResizeImage(
              MemoryImage(bytes),
              width: _decodeWidth,
              allowUpscaling: false,
            ),
          _ => null,
        },
    ]);
  }
}
