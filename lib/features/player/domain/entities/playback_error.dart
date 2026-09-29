import 'package:equatable/equatable.dart';

import '../../../../core/domain/entities/song.dart';

/// Una canción de la cola no se pudo reproducir (archivo borrado, corrupto…).
class PlaybackError extends Equatable {
  const PlaybackError({this.song, this.index, this.message});

  final Song? song;
  final int? index;
  final String? message;

  @override
  List<Object?> get props => [song, index, message];
}
