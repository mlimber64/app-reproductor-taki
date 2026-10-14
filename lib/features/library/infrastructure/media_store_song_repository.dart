import 'package:flutter/services.dart';

import '../../../core/domain/entities/artwork_reference.dart';
import '../../../core/domain/entities/local_song.dart';
import '../domain/ports/song_repository.dart';
import 'media_store_channel.dart';

/// Lee las canciones del MediaStore de Android mediante nuestro canal nativo.
///
/// Adapter intercambiable: la app solo conoce [SongRepository]. Evitamos
/// plugins de terceros para esto porque se abandonan con facilidad; si hiciera
/// falta otra fuente (otro plugin, Navidrome…), basta con otro adapter.
class MediaStoreSongRepository implements SongRepository {
  MediaStoreSongRepository({MethodChannel channel = mediaStoreChannel})
      : _channel = channel;

  final MethodChannel _channel;

  /// Valor que MediaStore usa cuando no conoce artista o álbum.
  static const String _unknown = '<unknown>';

  @override
  Future<List<LocalSong>> getSongs() async {
    final raw = await _channel.invokeListMethod<Map<Object?, Object?>>(
      'querySongs',
    );
    return (raw ?? const []).map(_toSong).toList();
  }

  LocalSong _toSong(Map<Object?, Object?> map) {
    final path = map['data'] as String? ?? '';
    final albumId = (map['albumId'] as num?)?.toInt();

    return LocalSong(
      id: (map['id'] as num).toInt(),
      title: _clean(map['title']) ?? _fileNameWithoutExtension(path),
      artist: _clean(map['artist']),
      album: _clean(map['album']),
      albumId: albumId,
      // La fuente local entrega su carátula como referencia local.
      artwork: localArtworkReference(albumId),
      durationMs: (map['duration'] as num?)?.toInt() ?? 0,
      path: path,
      contentUri: map['contentUri'] as String,
      folder: map['folder'] as String? ?? '',
    );
  }

  static String? _clean(Object? value) {
    final text = (value as String?)?.trim();
    if (text == null || text.isEmpty || text == _unknown) return null;
    return text;
  }

  static String _fileNameWithoutExtension(String path) {
    final name = path.split('/').last;
    final dot = name.lastIndexOf('.');
    return dot > 0 ? name.substring(0, dot) : name;
  }
}
