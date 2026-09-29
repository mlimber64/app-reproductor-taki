import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:taki/core/constants/library_constants.dart';
import 'package:taki/features/library/domain/usecases/get_songs.dart';

import '../../../helpers/library_fakes.dart';

void main() {
  late MockSongRepository repository;
  late GetSongs getSongs;

  setUp(() {
    repository = MockSongRepository();
    getSongs = GetSongs(repository);
  });

  test('ordena por título sin distinguir mayúsculas', () async {
    when(repository.getSongs).thenAnswer(
      (_) async => [
        buildSong(id: 1, title: 'zeta'),
        buildSong(id: 2, title: 'Alfa'),
        buildSong(id: 3, title: 'beta'),
        buildSong(id: 4, title: 'ALFA'),
      ],
    );

    final songs = await getSongs();

    expect(songs.map((s) => s.title), ['Alfa', 'ALFA', 'beta', 'zeta']);
    // A igual título, desempata por id para que el orden sea estable.
    expect(songs.take(2).map((s) => s.id), [2, 4]);
  });

  test('descarta audios de menos de 30 segundos', () async {
    final minMs = LibraryConstants.minSongDuration.inMilliseconds;
    when(repository.getSongs).thenAnswer(
      (_) async => [
        buildSong(id: 1, title: 'Nota de voz', durationMs: 5000),
        buildSong(id: 2, title: 'Casi', durationMs: minMs - 1),
        buildSong(id: 3, title: 'Justo', durationMs: minMs),
        buildSong(id: 4, title: 'Larga', durationMs: 240000),
      ],
    );

    final songs = await getSongs();

    expect(songs.map((s) => s.id), [3, 4]);
  });

  test('la duración mínima es de 30 segundos', () {
    expect(LibraryConstants.minSongDuration, const Duration(seconds: 30));
  });

  test('devuelve lista vacía si el repositorio no tiene canciones', () async {
    when(repository.getSongs).thenAnswer((_) async => []);

    expect(await getSongs(), isEmpty);
  });

  test('aplica el filtro de carpetas y mantiene el orden', () async {
    when(repository.getSongs).thenAnswer(
      (_) async => [
        buildSong(id: 1, title: 'zeta'),
        buildSong(
          id: 2,
          title: 'PTT-20260901',
          folder: 'Android/media/com.whatsapp/WhatsApp/Media/'
              'WhatsApp Voice Notes/202609/',
        ),
        buildSong(id: 3, title: 'Alfa', folder: 'Music/Live Recordings Vol1/'),
        buildSong(id: 4, title: 'Grabación', folder: 'Recordings/'),
        buildSong(id: 5, title: 'beta', durationMs: 10000),
      ],
    );

    final songs = await getSongs();

    expect(songs.map((s) => s.title), ['Alfa', 'zeta']);
  });
}
