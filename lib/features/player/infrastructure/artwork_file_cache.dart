import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/domain/entities/artwork_reference.dart';
import '../../../core/domain/entities/song.dart';
import '../../../core/domain/ports/artwork_repository.dart';
import '../../../core/domain/ports/remote_artwork_loader.dart';

/// Guarda carátulas como archivos en la caché de la app para la notificación
/// y la pantalla de bloqueo, que necesitan una URI (`file://…`), no bytes.
///
/// Lee la referencia que la propia canción trae (`Song.artwork`):
/// - [LocalArtworkReference]: la pide al [ArtworkRepository] por `albumId`
///   (`album_<id>_<size>.jpg`).
/// - [RemoteArtworkReference]: los bytes salen **solo** del [RemoteArtworkLoader]
///   (el que ya valida esquema, tamaño, tiempo y formato); aquí solo se guardan.
///   Sin loader, o con una carátula no disponible, no hay archivo.
class ArtworkFileCache {
  ArtworkFileCache(
    this._artwork, {
    RemoteArtworkLoader? remoteArtworkLoader,
    Future<Directory> Function()? cacheDirectory,
    this.size = 512,
  })  : _remoteLoader = remoteArtworkLoader,
        _cacheDirectory = cacheDirectory ?? getTemporaryDirectory;

  final ArtworkRepository _artwork;
  final RemoteArtworkLoader? _remoteLoader;
  final Future<Directory> Function() _cacheDirectory;

  /// Lado en px de la imagen guardada (de las locales; para las remotas es solo
  /// la pista que recibe el loader).
  final int size;

  /// Álbumes que sabemos que no tienen carátula (durante esta sesión).
  final Set<int> _withoutArtwork = {};

  /// Descargas remotas **en vuelo**, por URL. Solo evita pedir lo mismo dos
  /// veces a la vez: no es una caché (el archivo es la caché) y se vacía al
  /// terminar, también si falla.
  final Map<String, Future<Uri?>> _inFlight = {};

  static int _tempCounter = 0;

  /// URI del archivo de carátula de [song], o `null` si no tiene.
  ///
  /// Nunca lanza: «sin carátula antes que sin notificación».
  Future<Uri?> artUriFor(Song song) async {
    return switch (song.artwork) {
      final LocalArtworkReference local => _localUri(local),
      final RemoteArtworkReference remote => _remoteUri(remote),
      UnavailableArtworkReference() => null,
    };
  }

  Future<Uri?> _localUri(LocalArtworkReference artwork) async {
    final albumId = artwork.albumId;
    if (_withoutArtwork.contains(albumId)) return null;

    try {
      final directory = Directory('${(await _cacheDirectory()).path}/artwork');
      final file = File('${directory.path}/album_${albumId}_$size.jpg');
      if (await file.exists()) return file.uri;

      final bytes = await _artwork.getAlbumArtwork(albumId, size: size);
      if (bytes == null || bytes.isEmpty) {
        _withoutArtwork.add(albumId);
        return null;
      }

      await directory.create(recursive: true);
      await file.writeAsBytes(bytes, flush: true);
      return file.uri;
    } catch (_) {
      return null; // Sin carátula antes que sin notificación.
    }
  }

  Future<Uri?> _remoteUri(RemoteArtworkReference reference) {
    final loader = _remoteLoader;
    if (loader == null) return Future.value(null);

    final url = reference.url;
    return _inFlight[url] ??= _resolveRemote(loader, reference).whenComplete(() {
      _inFlight.remove(url);
    });
  }

  Future<Uri?> _resolveRemote(
    RemoteArtworkLoader loader,
    RemoteArtworkReference reference,
  ) async {
    try {
      final directory = Directory('${(await _cacheDirectory()).path}/artwork');
      final file = File('${directory.path}/${remoteFileName(reference.url)}');
      if (await file.exists()) return file.uri;

      final bytes = await loader.load(reference, size: size);
      if (bytes == null || bytes.isEmpty) return null;

      await directory.create(recursive: true);
      await _writeAtomically(file, bytes);
      return file.uri;
    } catch (_) {
      return null; // Un fallo (red, disco) no se memoiza: se reintentará.
    }
  }

  /// Escribe en un temporal del mismo directorio y lo renombra: quien lea el
  /// archivo final nunca lo ve a medias. Si falla, limpia el temporal y relanza.
  static Future<void> _writeAtomically(File file, List<int> bytes) async {
    final temp = File('${file.path}.${_tempCounter++}'
        '_${DateTime.now().microsecondsSinceEpoch}.tmp');
    try {
      await temp.writeAsBytes(bytes, flush: true);
      await temp.rename(file.path);
    } catch (_) {
      try {
        if (await temp.exists()) await temp.delete();
      } catch (_) {}
      rethrow;
    }
  }

  /// Nombre del archivo de una carátula remota: `remote_<fnv1a64(url)>.img`.
  ///
  /// La clave es la URL **completa** (no `externalId` ni `MusicIdentity`). Se usa
  /// FNV-1a de 64 bits sobre su UTF-8 porque `String.hashCode` no es estable
  /// entre ejecuciones. La extensión `.img` es deliberada: los bytes pueden ser
  /// JPEG, PNG, GIF o WebP.
  @visibleForTesting
  static String remoteFileName(String url) =>
      'remote_${fnv1a64(url)}.img';

  /// FNV-1a de 64 bits sobre el UTF-8 de [text], en hexadecimal de 16 cifras.
  @visibleForTesting
  static String fnv1a64(String text) {
    var hash = 0xcbf29ce484222325;
    for (final byte in utf8.encode(text)) {
      hash ^= byte;
      hash *= 0x100000001b3;
    }
    // `int.toUnsigned(64)` no cambia el signo en la VM: se pasa por BigInt.
    return BigInt.from(hash).toUnsigned(64).toRadixString(16).padLeft(16, '0');
  }
}
