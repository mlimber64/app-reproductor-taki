import 'dart:async';

import 'package:taki/core/domain/entities/local_song.dart';
import 'package:mocktail/mocktail.dart';
import 'package:taki/core/domain/entities/music_identity.dart';
import 'package:taki/core/domain/entities/song.dart';
import 'package:taki/features/playlists/domain/entities/playlist.dart';
import 'package:taki/features/playlists/domain/entities/playlist_entry.dart';
import 'package:taki/features/playlists/domain/ports/playlists_repository.dart';
import 'package:taki/features/playlists/domain/usecases/playlist_usecases.dart';

class MockMovePlaylistSong extends Mock implements MovePlaylistSong {}

/// Playlists en memoria con las mismas reglas que la base: posiciones
/// contiguas y `updatedAt` en cada cambio del usuario. Con [failing] todo
/// falla, como si la base no estuviera disponible.
class FakePlaylistsRepository implements PlaylistsRepository {
  FakePlaylistsRepository({this.failing = false});

  bool failing;
  final List<_FakePlaylist> _playlists = [];
  final List<(int, MusicIdentity)> relinks = [];
  final _changes = StreamController<void>.broadcast();
  var _nextId = 1;
  var _nextEntryId = 1;
  var _tick = 0;

  /// Crea una playlist con [songs] (o entradas de respaldo) sin notificar.
  int seed(String name, {List<Song> songs = const []}) {
    final playlist = _FakePlaylist(_nextId++, name, _now());
    _playlists.add(playlist);
    _append(playlist, songs);
    return playlist.id;
  }

  /// Añade una entrada con datos de respaldo arbitrarios (p. ej. id viejo).
  void seedEntry(int playlistId, PlaylistEntry Function(int id, int position) build) {
    final playlist = _find(playlistId)!;
    playlist.entries.add(build(_nextEntryId++, playlist.entries.length));
  }

  List<PlaylistEntry> entriesOf(int playlistId) =>
      List.unmodifiable(_find(playlistId)!.entries);

  List<String> namesInOrder() => [for (final p in _snapshot()) p.name];

  @override
  Stream<List<Playlist>> watchPlaylists() {
    StreamSubscription<void>? subscription;
    late final StreamController<List<Playlist>> controller;
    void emit() {
      if (failing) {
        controller.addError(StateError('Base no disponible'));
      } else {
        controller.add(_snapshot());
      }
    }

    controller = StreamController<List<Playlist>>(
      onListen: () {
        subscription = _changes.stream.listen((_) => emit());
        emit();
      },
      onCancel: () {
        subscription?.cancel();
      },
    );
    return controller.stream;
  }

  @override
  Future<List<PlaylistEntry>> getEntries(int playlistId) async {
    _check();
    return List.of(_find(playlistId)?.entries ?? const <PlaylistEntry>[]);
  }

  @override
  Future<int> create(String name) async {
    _check();
    final id = seed(name);
    _notify();
    return id;
  }

  @override
  Future<void> rename(int playlistId, String name) async {
    _check();
    final playlist = _find(playlistId);
    if (playlist == null) return;
    playlist
      ..name = name
      ..updatedAt = _now();
    _notify();
  }

  @override
  Future<void> delete(int playlistId) async {
    _check();
    _playlists.removeWhere((p) => p.id == playlistId);
    _notify();
  }

  @override
  Future<void> addSongs(int playlistId, List<Song> songs) async {
    _check();
    final playlist = _find(playlistId);
    if (playlist == null) return;
    _append(playlist, songs);
    playlist.updatedAt = _now();
    _notify();
  }

  @override
  Future<void> removeEntry(int entryId) async {
    _check();
    for (final playlist in _playlists) {
      final before = playlist.entries.length;
      playlist.entries.removeWhere((e) => e.id == entryId);
      if (playlist.entries.length != before) {
        _renumber(playlist);
        playlist.updatedAt = _now();
      }
    }
    _notify();
  }

  @override
  Future<void> reinsertEntry(PlaylistEntry entry) async {
    _check();
    final playlist = _find(entry.playlistId);
    if (playlist == null) return;
    final position = entry.position.clamp(0, playlist.entries.length);
    playlist.entries.insert(position, entry);
    _renumber(playlist);
    playlist.updatedAt = _now();
    _notify();
  }

  @override
  Future<void> move(int playlistId, int oldIndex, int newIndex) async {
    _check();
    final playlist = _find(playlistId);
    if (playlist == null) return;
    final entries = playlist.entries;
    if (oldIndex < 0 ||
        newIndex < 0 ||
        oldIndex >= entries.length ||
        newIndex >= entries.length) {
      return;
    }
    entries.insert(newIndex, entries.removeAt(oldIndex));
    _renumber(playlist);
    playlist.updatedAt = _now();
    _notify();
  }

  @override
  Future<void> relink(int entryId, Song song) async {
    _check();
    relinks.add((entryId, song.musicIdentity));
    for (final playlist in _playlists) {
      final index = playlist.entries.indexWhere((e) => e.id == entryId);
      if (index == -1) continue;
      final old = playlist.entries[index];
      playlist.entries[index] = _entry(playlist.id, old.position, song, id: old.id);
    }
    _notify();
  }

  DateTime _now() => DateTime(2026, 9, 1).add(Duration(minutes: _tick++));

  _FakePlaylist? _find(int id) =>
      _playlists.where((p) => p.id == id).firstOrNull;

  void _append(_FakePlaylist playlist, List<Song> songs) {
    for (final song in songs) {
      playlist.entries
          .add(_entry(playlist.id, playlist.entries.length, song));
    }
  }

  PlaylistEntry _entry(int playlistId, int position, Song song, {int? id}) {
    return PlaylistEntry(
      id: id ?? _nextEntryId++,
      playlistId: playlistId,
      position: position,
      musicIdentity: song.musicIdentity,
      title: song.title,
      artist: song.artist,
      album: song.album,
      durationMs: song.durationMs,
      path: localPathOf(song),
    );
  }

  static void _renumber(_FakePlaylist playlist) {
    final entries = playlist.entries;
    for (var i = 0; i < entries.length; i++) {
      final e = entries[i];
      entries[i] = PlaylistEntry(
        id: e.id,
        playlistId: e.playlistId,
        position: i,
        musicIdentity: e.musicIdentity,
        title: e.title,
        artist: e.artist,
        album: e.album,
        durationMs: e.durationMs,
        path: e.path,
      );
    }
  }

  List<Playlist> _snapshot() {
    final list = [
      for (final p in _playlists)
        Playlist(
          id: p.id,
          name: p.name,
          songCount: p.entries.length,
          totalDurationMs:
              p.entries.fold(0, (sum, e) => sum + (e.durationMs ?? 0)),
          createdAt: p.createdAt,
          updatedAt: p.updatedAt,
          coverIdentities: [for (final e in p.entries.take(4)) e.musicIdentity],
        ),
    ]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return list;
  }

  void _notify() => _changes.add(null);

  void _check() {
    if (failing) throw StateError('Base no disponible');
  }
}

class _FakePlaylist {
  _FakePlaylist(this.id, this.name, this.createdAt) : updatedAt = createdAt;

  final int id;
  String name;
  final DateTime createdAt;
  DateTime updatedAt;
  final List<PlaylistEntry> entries = [];
}
