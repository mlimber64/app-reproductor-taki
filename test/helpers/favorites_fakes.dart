import 'dart:async';

import 'package:taki/core/domain/entities/local_song.dart';
import 'package:mocktail/mocktail.dart';
import 'package:taki/core/domain/entities/music_identity.dart';
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
  final Map<MusicIdentity, FavoriteEntry> entries = {};
  final List<(MusicIdentity, MusicIdentity)> relinks = [];
  final _changes = StreamController<void>.broadcast();
  var _minutes = 0;

  /// Guarda un favorito directamente (p. ej. con datos de respaldo viejos).
  void seed(FavoriteEntry entry) => entries[entry.musicIdentity] = entry;

  FavoriteEntry entryFor(Song song, {MusicIdentity? identity, DateTime? addedAt}) {
    return FavoriteEntry(
      musicIdentity: identity ?? song.musicIdentity,
      addedAt: addedAt ?? DateTime(2026, 9, 1).add(Duration(minutes: _minutes++)),
      title: song.title,
      artist: song.artist,
      album: song.album,
      durationMs: song.durationMs,
      path: localPathOf(song),
    );
  }

  @override
  Stream<Set<MusicIdentity>> watchFavoriteIdentities() {
    StreamSubscription<void>? subscription;
    late final StreamController<Set<MusicIdentity>> controller;
    void emit() {
      if (failing) {
        controller.addError(StateError('Base no disponible'));
      } else {
        controller.add(entries.keys.toSet());
      }
    }

    controller = StreamController<Set<MusicIdentity>>(
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
    entries.putIfAbsent(song.musicIdentity, () => entryFor(song));
    _changes.add(null);
  }

  @override
  Future<void> remove(MusicIdentity identity) async {
    _check();
    entries.remove(identity);
    _changes.add(null);
  }

  @override
  Future<void> relink(MusicIdentity oldIdentity, Song song) async {
    _check();
    relinks.add((oldIdentity, song.musicIdentity));
    final old = entries.remove(oldIdentity);
    if (old != null && !entries.containsKey(song.musicIdentity)) {
      entries[song.musicIdentity] = entryFor(song, addedAt: old.addedAt);
    }
    _changes.add(null);
  }

  void _check() {
    if (failing) throw StateError('Base no disponible');
  }
}
