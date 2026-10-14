import '../../../helpers/artwork_reference_ext.dart';
import 'package:flutter_test/flutter_test.dart';


void main() {
  group('sin canciones y sin álbumes: [] frente a [null]', () {
    test('sin canciones → []', () {
      expect(playlistCoverAlbumIds(const []), <int?>[]);
    });

    test('con canciones pero ninguna con álbum → [null]', () {
      expect(playlistCoverAlbumIds(const [null]), <int?>[null]);
      expect(playlistCoverAlbumIds(const [null, null, null]), <int?>[null]);
    });

    test('[] y [null] son distintos (vacía frente a sin carátulas)', () {
      expect(playlistCoverAlbumIds(const []), isEmpty);
      expect(playlistCoverAlbumIds(const [null]), hasLength(1));
      expect(playlistCoverAlbumIds(const [null]).single, isNull);
    });
  });

  group('álbumes', () {
    test('una canción con álbum → [álbum]', () {
      expect(playlistCoverAlbumIds(const [7]), [7]);
    });

    test('varias canciones del mismo álbum → [álbum]', () {
      expect(playlistCoverAlbumIds(const [7, 7, 7]), [7]);
    });

    test('varios álbumes: mantiene el orden de aparición', () {
      expect(playlistCoverAlbumIds(const [30, 10, 20]), [30, 10, 20]);
    });

    test('un álbum repetido después de otros no se duplica', () {
      expect(playlistCoverAlbumIds(const [1, 2, 1, 3]), [1, 2, 3]);
      expect(playlistCoverAlbumIds(const [1, 2, 3, 2]), [1, 2, 3]);
    });

    test('cuatro álbumes distintos → los cuatro (mosaico completo)', () {
      expect(playlistCoverAlbumIds(const [1, 2, 3, 4]), [1, 2, 3, 4]);
    });

    test('más de 4 canciones con álbumes distintos → solo los primeros 4',
        () {
      expect(playlistCoverAlbumIds(const [1, 2, 3, 4, 5, 6]), [1, 2, 3, 4]);
    });
  });

  group('solo cuentan las primeras 4 canciones (no los primeros 4 álbumes)',
      () {
    // Es el comportamiento que ya tenían la lista, el detalle y el antiguo
    // PlaylistCover (ya eliminado):
    // las canciones repetidas gastan huecos.
    test('[A, A, B, C, D] → [A, B, C]; el 4.º álbum queda fuera', () {
      expect(playlistCoverAlbumIds(const [1, 1, 2, 3, 4]), [1, 2, 3]);
    });

    test('la 5.ª canción no cambia nada', () {
      expect(playlistCoverAlbumIds(const [1, 2, 3, 4]),
          playlistCoverAlbumIds(const [1, 2, 3, 4, 9]));
      expect(playlistCoverAlbumIds(const [1, 1, 1, 1, 9]), [1]);
    });
  });

  group('null (canción sin álbum o no disponible)', () {
    test('mezcla: los null se descartan y conserva el orden', () {
      expect(playlistCoverAlbumIds(const [null, 5, null, 6]), [5, 6]);
      expect(playlistCoverAlbumIds(const [5, null, 6]), [5, 6]);
    });

    test('los null ocupan un hueco de las 4 canciones', () {
      // Las 4 primeras no tienen álbum: la 5.ª (con álbum) no se mira.
      expect(playlistCoverAlbumIds(const [null, null, null, null, 7]), [null]);
      // Con 3 nulls y un álbum en la 4.ª sí entra.
      expect(playlistCoverAlbumIds(const [null, null, null, 7, 8]), [7]);
    });

    test('duplicados y null a la vez', () {
      expect(playlistCoverAlbumIds(const [3, null, 3, null]), [3]);
      expect(playlistCoverAlbumIds(const [null, 3, null, 3]), [3]);
    });

    test('un null entre álbumes no rompe la deduplicación', () {
      expect(playlistCoverAlbumIds(const [1, null, 2, null]), [1, 2]);
    });
  });

  group('las dos fuentes de las pantallas', () {
    test('lista: las entradas guardadas ausentes cuentan como null y gastan '
        'hueco', () {
      // coverSongIds = 4 entradas; la 1.ª y la 3.ª ya no están en la biblioteca.
      final fromCoverSongIds = <int?>[null, 10, null, 20];
      expect(playlistCoverAlbumIds(fromCoverSongIds), [10, 20]);
    });

    test('detalle: las ausentes ni aparecen, así que entran más canciones',
        () {
      // Mismas 6 entradas guardadas [ausente, 10, ausente, 20, 30, 40]: el
      // detalle solo ve las visibles [10, 20, 30, 40].
      expect(playlistCoverAlbumIds(const [10, 20, 30, 40]), [10, 20, 30, 40]);
      // La lista, con las 4 primeras entradas guardadas, ve menos álbumes.
      expect(playlistCoverAlbumIds(const [null, 10, null, 20]), [10, 20]);
    });

    test('todas ausentes: la lista da [null] (hay entradas) y el detalle []'
        ' (no hay visibles)', () {
      expect(playlistCoverAlbumIds(const [null, null]), <int?>[null]);
      expect(playlistCoverAlbumIds(const []), <int?>[]);
    });
  });

  group('pureza', () {
    test('no modifica una lista de entrada modificable', () {
      final input = <int?>[3, null, 3, 5, 6, 7];
      final copy = List<int?>.of(input);

      final result = playlistCoverAlbumIds(input);

      expect(input, copy);
      // Solo cuentan las 4 primeras entradas: 3, null, 3, 5.
      expect(result, [3, 5]);
    });

    test('admite una lista no modificable', () {
      final input = List<int?>.unmodifiable([1, 2, 1, 3, 4, 5]);

      expect(() => playlistCoverAlbumIds(input), returnsNormally);
      expect(playlistCoverAlbumIds(input), [1, 2, 3]);
      expect(input, [1, 2, 1, 3, 4, 5]);
    });

    test('el resultado no comparte estado con la entrada ni es modificable',
        () {
      final input = <int?>[1, 2];
      final result = playlistCoverAlbumIds(input);

      input.add(3);
      expect(result, [1, 2]);
      expect(() => result.add(9), throwsUnsupportedError);
      expect(() => playlistCoverAlbumIds(const []).add(9),
          throwsUnsupportedError);
      expect(() => playlistCoverAlbumIds(const [null]).add(9),
          throwsUnsupportedError);
    });

    test('solo consume las primeras 4 entradas de un Iterable perezoso', () {
      var consumed = 0;
      final lazy = Iterable<int?>.generate(1000, (i) {
        consumed++;
        return i;
      });

      final result = playlistCoverAlbumIds(lazy);

      expect(result, [0, 1, 2, 3]);
      expect(consumed, 4);
    });

    test('es determinista: la misma entrada da el mismo resultado', () {
      const input = <int?>[null, 4, 4, 9, null, 1];
      expect(playlistCoverAlbumIds(input), playlistCoverAlbumIds(input));
      expect(playlistCoverAlbumIds(input), [4, 9]);
    });
  });
}
