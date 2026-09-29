import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../providers/artwork_cache.dart';
import '../providers/library_providers.dart';

/// Carátula de álbum con esquinas redondeadas.
///
/// Se pide de forma asíncrona (el trabajo nativo corre fuera del hilo de UI) y
/// se guarda en una caché LRU; mientras tanto, o si no hay carátula, muestra un
/// ícono de nota.
class ArtworkImage extends ConsumerStatefulWidget {
  const ArtworkImage({
    super.key,
    required this.albumId,
    this.size = 48,
    this.borderRadius = 10,
  });

  final int? albumId;
  final double size;
  final double borderRadius;

  @override
  ConsumerState<ArtworkImage> createState() => _ArtworkImageState();
}

class _ArtworkImageState extends ConsumerState<ArtworkImage> {
  ArtworkKey? _key;
  Uint8List? _bytes;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolve();
  }

  @override
  void didUpdateWidget(ArtworkImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.albumId != widget.albumId || oldWidget.size != widget.size) {
      _resolve();
    }
  }

  int get _pixelSize =>
      (widget.size * MediaQuery.devicePixelRatioOf(context)).round();

  void _resolve() {
    final albumId = widget.albumId;
    if (albumId == null) {
      _key = null;
      _bytes = null;
      return;
    }

    final key = (albumId: albumId, size: _pixelSize);
    if (key == _key) return;
    _key = key;

    final cache = ref.read(artworkCacheProvider);
    if (cache.contains(key)) {
      _bytes = cache.peek(key);
      return;
    }

    _bytes = null;
    cache.load(key).then((bytes) {
      if (mounted && _key == key) setState(() => _bytes = bytes);
    });
  }

  @override
  Widget build(BuildContext context) {
    final bytes = _bytes;

    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.borderRadius),
      child: SizedBox.square(
        dimension: widget.size,
        child: bytes == null
            ? _Fallback(size: widget.size)
            : Image.memory(
                bytes,
                fit: BoxFit.cover,
                gaplessPlayback: true,
                cacheWidth: _pixelSize,
                filterQuality: FilterQuality.medium,
                errorBuilder: (_, _, _) => _Fallback(size: widget.size),
              ),
      ),
    );
  }
}

class _Fallback extends StatelessWidget {
  const _Fallback({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.surfaceElevated,
      child: Icon(
        Icons.music_note_rounded,
        size: size * 0.5,
        color: AppColors.textSecondary,
      ),
    );
  }
}
