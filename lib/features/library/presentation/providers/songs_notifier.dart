import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/artwork/artwork_providers.dart';
import '../../../../core/domain/entities/song.dart';
import 'library_providers.dart';

/// Estados de la biblioteca. "Cargando" y "error" los cubre [AsyncValue].
sealed class LibraryState extends Equatable {
  const LibraryState();

  @override
  List<Object?> get props => [];
}

final class LibraryNeedsPermission extends LibraryState {
  const LibraryNeedsPermission({required this.permanentlyDenied});

  final bool permanentlyDenied;

  @override
  List<Object?> get props => [permanentlyDenied];
}

final class LibraryEmpty extends LibraryState {
  const LibraryEmpty();
}

final class LibraryLoaded extends LibraryState {
  const LibraryLoaded(this.songs);

  final List<Song> songs;

  Duration get totalDuration => songs.fold(
        Duration.zero,
        (total, song) => total + song.duration,
      );

  @override
  List<Object?> get props => [songs];
}

final songsProvider = AsyncNotifierProvider<SongsNotifier, LibraryState>(
  SongsNotifier.new,
);

class SongsNotifier extends AsyncNotifier<LibraryState> {
  @override
  Future<LibraryState> build() => _load();

  Future<LibraryState> _load() async {
    final permission = ref.read(mediaPermissionProvider);
    if (!await permission.isGranted()) {
      return LibraryNeedsPermission(
        permanentlyDenied: await permission.isPermanentlyDenied(),
      );
    }

    final songs = await ref.read(getSongsProvider).call();
    return songs.isEmpty ? const LibraryEmpty() : LibraryLoaded(songs);
  }

  /// Pide el permiso o, si quedó denegado para siempre, abre los ajustes.
  Future<void> requestPermission() async {
    final permission = ref.read(mediaPermissionProvider);
    final current = state.valueOrNull;

    if (current is LibraryNeedsPermission && current.permanentlyDenied) {
      await permission.openSettings();
      return; // Al volver a la app se revisa de nuevo (ver [recheckPermission]).
    }

    if (await permission.request()) {
      await retry();
    } else {
      state = AsyncData(
        LibraryNeedsPermission(
          permanentlyDenied: await permission.isPermanentlyDenied(),
        ),
      );
    }
  }

  /// Revisa el permiso al volver a la app (p. ej. desde Ajustes).
  Future<void> recheckPermission() async {
    if (state.valueOrNull is! LibraryNeedsPermission) return;
    state = await AsyncValue.guard(_load);
  }

  /// Vuelve a cargar mostrando el estado de carga.
  Future<void> retry() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_load);
  }

  /// Vuelve a escanear sin ocultar la lista actual (pull-to-refresh).
  Future<void> rescan() async {
    ref.read(artworkCacheProvider).clear();
    state = await AsyncValue.guard(_load);
  }
}
