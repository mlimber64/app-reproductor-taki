import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Los bytes de una carátula tal como los entrega `AlbumArtworkBuilder`:
/// `ResizeImage(MemoryImage(bytes), …)`. Falla si el proveedor no tiene esa
/// forma, para que un cambio en la decodificación no pase desapercibido.
MemoryImage memoryImageOf(ImageProvider image) {
  expect(image, isA<ResizeImage>());
  final inner = (image as ResizeImage).imageProvider;
  expect(inner, isA<MemoryImage>());
  return inner as MemoryImage;
}

/// Primer byte de los bytes de [image] (las pruebas usan `[albumId]`), o
/// `null` si no hay imagen.
int? firstByteOf(ImageProvider? image) =>
    image == null ? null : memoryImageOf(image).bytes.first;
