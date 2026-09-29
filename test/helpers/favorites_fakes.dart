import 'dart:async';

import 'package:mocktail/mocktail.dart';
import 'package:taki/features/library/domain/entities/favorite_entry.dart';
import 'package:taki/core/domain/entities/song.dart';
import 'package:taki/features/library/domain/ports/favorites_repository.dart';
import 'package:taki/features/library/domain/usecases/favorites_usecases.dart';

class MockToggleFavorite extends Mock implements ToggleFavorite {}

/// Favoritos en memoria. Con [failing] todas las operaciones fallan, como si
/// la base no estuviera disponible.
class FakeFavoritesRepository implements FavoritesRepository {
  FakeFavoritesRepository({this.failing = false});

  bool failing;
  final Map<int, FavoriteEntry> entries = {};
  final List<(int, int)> relinks = [];
  final _changes = StreamController<void>.broadcast();
  var _minutes = 0;

  /// Guarda un favorito directamente (p. ej. con datos de respaldo viejos).
  void seed(FavoriteEntry entry) => entries[entry.songId] = entry;

  FavoriteEntry entryFor(Song song, {int? songId, DateTime? addedAt}) {
    return FavoriteEntry(
      songId: songId ?? song.id,
      addedAt: addedAt ?? DateTime(2026, 9, 1).add(Duration(minutes: _minutes++)),
      title: song.title,
      artist: song.artist,
      album: song.album,
      durationMs: song.durationMs,
      path: song.path,
    );
  }

  @override
  Stream<Set<int>> watchFavoriteIds() {
    StreamSubscription<void>? subscription;
    late final StreamController<Set<int>> controller;
    void emit() {
      if (failing) {
        controller.addError(StateError('Base no disponible'));
      } else {
        controller.add(entries.keys.toSet());
      }
    }

    controller = StreamController<Set<int>>(
      onListen: () {
        subscription = _changes.stream.listen((_) => emit());
        emit();
      },
      // Sin esperar la cancelación interna: así `first` termina enseguida.
      onCancel: () {
        subscription?.cancel();
      },
    );
    return controller.stream;
  }

  @override
  Future<List<FavoriteEntry>> getFavorites() async {
    _check();
    return entries.values.toList()
      ..sort((a, b) => b.addedAt.compareTo(a.addedAt));
  }

  @override
  Future<void> add(Song song) async {
    _check();
    entries.putIfAbsent(song.id, () => entryFor(song));
    _changes.add(null);
  }

  @override
  Future<void> remove(int songId) async {
    _check();
    entries.remove(songId);
    _changes.add(null);
  }

  @override
  Future<void> relink(int oldSongId, Song song) async {
    _check();
    relinks.add((oldSongId, song.id));
    final old = entries.remove(oldSongId);
    if (old != null && !entries.containsKey(song.id)) {
      entries[song.id] = entryFor(song, addedAt: old.addedAt);
    }
    _changes.add(null);
  }

  void _check() {
    if (failing) throw StateError('Base no disponible');
  }
}
