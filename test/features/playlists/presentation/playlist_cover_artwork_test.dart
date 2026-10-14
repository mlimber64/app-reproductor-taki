import 'package:flutter_test/flutter_test.dart';
import 'package:taki/core/domain/entities/artwork_reference.dart';
import 'package:taki/features/playlists/presentation/playlist_cover_albums.dart';

void main() {
  final a = RemoteArtworkReference('https://cdn.example/a.jpg');
  final b = RemoteArtworkReference('https://cdn.example/b.jpg');
  const local = LocalArtworkReference(7);
  const none = UnavailableArtworkReference();

  test('sin canciones → []', () {
    expect(playlistCoverArtwork(const []), isEmpty);
  });

  test('ninguna con carátula → [Unavailable] (distinto de [])', () {
    expect(playlistCoverArtwork(const [null, none, null]), [none]);
    expect(playlistCoverArtwork(const [none]), [none]);
  });

  test('carátulas remotas distintas, en orden de aparición', () {
    expect(playlistCoverArtwork([a, b, a]), [a, b]);
  });

  test('misma URL es la misma carátula; otro tamaño declarado, otra', () {
    final same = RemoteArtworkReference('https://cdn.example/a.jpg');
    final sized = RemoteArtworkReference('https://cdn.example/a.jpg', width: 300);
    expect(playlistCoverArtwork([a, same]), [a]);
    expect(playlistCoverArtwork([a, sized]), [a, sized]);
  });

  test('mezcla local y remota; una remota «7» no se confunde con el álbum 7',
      () {
    expect(
      playlistCoverArtwork([local, RemoteArtworkReference('7'), local]),
      [local, RemoteArtworkReference('7')],
    );
  });

  test('las no disponibles y los null no ocupan hueco', () {
    expect(playlistCoverArtwork([none, a, null, b]), [a, b]);
  });

  test('solo cuentan las 4 primeras canciones', () {
    final c = RemoteArtworkReference('https://cdn.example/c.jpg');
    final d = RemoteArtworkReference('https://cdn.example/d.jpg');
    final e = RemoteArtworkReference('https://cdn.example/e.jpg');
    expect(playlistCoverArtwork([a, a, b, c, d, e]), [a, b, c]);
    expect(playlistCoverArtwork([a, b, c, d, e]), [a, b, c, d]);
  });

  test('el resultado no es modificable y no toca la entrada', () {
    final input = <ArtworkReference?>[a, b];
    final result = playlistCoverArtwork(input);
    expect(() => result.add(a), throwsUnsupportedError);
    expect(input, [a, b]);
  });

  test('solo consume las 4 primeras entradas de un Iterable perezoso', () {
    var consumed = 0;
    final lazy = Iterable<ArtworkReference?>.generate(1000, (i) {
      consumed++;
      return RemoteArtworkReference('https://cdn.example/$i.jpg');
    });
    expect(playlistCoverArtwork(lazy), hasLength(4));
    expect(consumed, 4);
  });
}
