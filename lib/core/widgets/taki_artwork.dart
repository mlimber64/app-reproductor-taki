import 'package:flutter/material.dart';

import '../theme/taki_colors.dart';
import '../theme/taki_elevation.dart';
import '../theme/taki_motion.dart';
import '../theme/taki_radius.dart';

/// Tipo de contenido de un artwork: decide el icono del placeholder y, para
/// artistas, la forma (docs/DESIGN_SYSTEM.md §7).
enum TakiArtworkKind {
  song(Icons.music_note_rounded),
  playlist(Icons.queue_music_rounded),
  artist(Icons.person_rounded),
  genre(Icons.category_rounded);

  const TakiArtworkKind(this.placeholderIcon);

  final IconData placeholderIcon;
}

/// Carátula cuadrada de Taki (docs/DESIGN_SYSTEM.md §7). Solo presentación.
///
/// Recibe la imagen como [ImageProvider] y no sabe de dónde sale: una carátula
/// local (la que resuelve `AlbumArtworkBuilder`) o, en el futuro, una remota se
/// ven igual.
///
/// - Sin [image], mientras carga y si falla: placeholder (fondo `surface` e
///   icono del [kind] al 45 % del lado). Una carátula que falta no es un error.
/// - Al cargar: fundido de 150 ms, salvo que ya estuviera en caché.
/// - Radio según el tamaño ([TakiRadius.forArtwork]); artistas en círculo.
/// - [hero]: la sombra del artwork grande (Reproduciendo, cabeceras hero).
/// - Con [semanticLabel] se anuncia como imagen; sin él es decorativa.
class TakiArtwork extends StatelessWidget {
  const TakiArtwork({
    super.key,
    required this.size,
    this.image,
    this.kind = TakiArtworkKind.song,
    this.hero = false,
    this.semanticLabel,
  }) : mosaic = null;

  /// Portada de una colección (§7.3): con 4 imágenes o más, mosaico 2×2 de las
  /// cuatro primeras (radio en el contenedor, 0 en cada pieza); con menos, la
  /// primera; sin ninguna, la colección está vacía: placeholder con borde
  /// `outline`. Elegir qué imágenes (p. ej. álbumes distintos) es cosa de
  /// quien la usa; una entrada `null` es una pieza sin carátula.
  const TakiArtwork.mosaic({
    super.key,
    required this.size,
    required List<ImageProvider?> images,
    this.kind = TakiArtworkKind.playlist,
    this.hero = false,
    this.semanticLabel,
  })  : mosaic = images,
        image = null;

  /// Lado en píxeles lógicos.
  final double size;
  final ImageProvider? image;

  /// Imágenes de [TakiArtwork.mosaic]; `null` con el constructor normal.
  final List<ImageProvider?>? mosaic;
  final TakiArtworkKind kind;
  final bool hero;
  final String? semanticLabel;

  /// Proporción del lado que ocupa el icono del placeholder.
  static const double placeholderIconFactor = 0.45;

  /// Piezas del mosaico 2×2.
  static const int mosaicCount = 4;

  @override
  Widget build(BuildContext context) {
    final isArtist = kind == TakiArtworkKind.artist;
    final radius = BorderRadius.all(
      Radius.circular(TakiRadius.forArtwork(size)),
    );

    Widget content = SizedBox.square(
      dimension: size,
      child: isArtist
          ? ClipOval(child: _content())
          : ClipRRect(borderRadius: radius, child: _content()),
    );

    // Colección vacía: el borde la distingue de una sin carátulas.
    if (mosaic case final images? when images.isEmpty) {
      content = DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: ShapeDecoration(
          shape: RoundedRectangleBorder(
            borderRadius: radius,
            side: const BorderSide(
              color: TakiColors.outline,
              width: TakiElevation.borderWidth,
            ),
          ),
        ),
        child: content,
      );
    }

    if (hero) {
      content = DecoratedBox(
        decoration: BoxDecoration(
          shape: isArtist ? BoxShape.circle : BoxShape.rectangle,
          borderRadius: isArtist ? null : radius,
          boxShadow: const [TakiElevation.artworkShadow],
        ),
        child: content,
      );
    }

    final label = semanticLabel;
    return label == null
        ? ExcludeSemantics(child: content)
        : Semantics(image: true, label: label, child: content);
  }

  Widget _content() {
    final images = mosaic;
    if (images == null) return _Picture(image: image, kind: kind, size: size);
    if (images.length < mosaicCount) {
      return _Picture(image: images.firstOrNull, kind: kind, size: size);
    }

    final tile = size / 2;
    return Column(
      children: [
        for (var row = 0; row < 2; row++)
          Row(
            children: [
              for (var column = 0; column < 2; column++)
                _Picture(
                  image: images[row * 2 + column],
                  kind: kind,
                  size: tile,
                ),
            ],
          ),
      ],
    );
  }
}

/// Una imagen cuadrada con su placeholder y el fundido de entrada.
class _Picture extends StatelessWidget {
  const _Picture({required this.image, required this.kind, required this.size});

  final ImageProvider? image;
  final TakiArtworkKind kind;
  final double size;

  @override
  Widget build(BuildContext context) {
    final placeholder = _Placeholder(kind: kind, size: size);
    final image = this.image;
    if (image == null) return SizedBox.square(dimension: size, child: placeholder);

    return Image(
      image: image,
      width: size,
      height: size,
      fit: BoxFit.cover,
      gaplessPlayback: true,
      excludeFromSemantics: true,
      filterQuality: FilterQuality.medium,
      errorBuilder: (_, _, _) =>
          SizedBox.square(dimension: size, child: placeholder),
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded) return child;
        return SizedBox.square(
          dimension: size,
          child: Stack(
            fit: StackFit.expand,
            children: [
              placeholder,
              AnimatedOpacity(
                opacity: frame == null ? 0 : 1,
                duration: TakiMotion.short,
                curve: TakiMotion.enter,
                child: child,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.kind, required this.size});

  final TakiArtworkKind kind;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: TakiColors.surface,
      child: Center(
        child: Icon(
          kind.placeholderIcon,
          size: size * TakiArtwork.placeholderIconFactor,
          color: TakiColors.iconSecondary,
        ),
      ),
    );
  }
}
