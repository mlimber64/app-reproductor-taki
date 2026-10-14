import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taki/core/artwork/album_artwork_builder.dart';
import 'package:taki/core/artwork/artwork_cache.dart';
import 'package:taki/core/artwork/artwork_providers.dart';
import 'package:taki/core/domain/entities/artwork_reference.dart';
import 'package:taki/core/domain/ports/artwork_repository.dart';
import 'package:taki/core/domain/ports/remote_artwork_loader.dart';
import '../../helpers/artwork_image.dart';

/// Repositorio de prueba: bytes `[albumId]` por defecto; cuenta las peticiones.
class _FakeRepository implements ArtworkRepository {
  /// Álbumes que no tienen carátula.
  final missing = <int>{};

  /// Álbumes con carátula de bytes vacíos.
  final empty = <int>{};

  /// Álbumes cuya lectura falla.
  final failing = <int>{};

  /// Bytes concretos (p. ej. un PNG real) en lugar de `[albumId]`.
  final artwork = <int, Uint8List>{};

  /// Álbumes cuya respuesta se retiene hasta completar el `Completer`.
  final gates = <int, Completer<void>>{};

  final requests = <ArtworkKey>[];

  @override
  Future<Uint8List?> getAlbumArtwork(int albumId, {required int size}) async {
    requests.add((reference: LocalArtworkReference(albumId), size: size));
    final gate = gates[albumId];
    if (gate != null) await gate.future;
    if (failing.contains(albumId)) throw StateError('lectura fallida');
    if (missing.contains(albumId)) return null;
    if (empty.contains(albumId)) return Uint8List(0);
    return artwork[albumId] ?? Uint8List.fromList([albumId]);
  }

  List<int> get sizes => [for (final r in requests) r.size];

  List<int> get albumIds => [
        for (final r in requests) (r.reference as LocalArtworkReference).albumId,
      ];
}

/// Parámetros del widget bajo prueba; `tick` fuerza una reconstrucción con
/// los mismos valores.
class _Params {
  const _Params({
    this.albumId,
    this.albumIds = const [],
    this.size = 48,
    this.dpr = 2,
    this.tick = 0,
  });

  final int? albumId;
  final List<int?> albumIds;
  final double size;
  final double dpr;
  final int tick;

  _Params copyWith({
    int? albumId,
    List<int?>? albumIds,
    double? size,
    double? dpr,
    int? tick,
  }) =>
      _Params(
        albumId: albumId ?? this.albumId,
        albumIds: albumIds ?? this.albumIds,
        size: size ?? this.size,
        dpr: dpr ?? this.dpr,
        tick: tick ?? this.tick,
      );
}

/// Lo último (y todo lo) que entregó el builder.
class _Probe {
  ImageProvider? image;
  List<ImageProvider?> images = const [];
  final imageHistory = <ImageProvider?>[];
  final imagesHistory = <List<ImageProvider?>>[];
}

int? _firstByte(ImageProvider? image) => firstByteOf(image);

List<int?> _firstBytes(List<ImageProvider?> images) =>
    [for (final image in images) _firstByte(image)];

/// PNG liso de [width]×[height] (hay que llamarlo dentro de `runAsync`).
Future<Uint8List> _png(int width, int height, Color color) async {
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawRect(
    Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    Paint()..color = color,
  );
  final image = await recorder.endRecording().toImage(width, height);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return data!.buffer.asUint8List();
}

/// Dimensiones con que Flutter decodifica [provider] (dentro de `runAsync`).
Future<Size> _decodedSize(ImageProvider provider) async {
  final done = Completer<ImageInfo>();
  final stream = provider.resolve(ImageConfiguration.empty);
  late ImageStreamListener listener;
  listener = ImageStreamListener(
    (info, _) {
      if (!done.isCompleted) done.complete(info);
      stream.removeListener(listener);
    },
    onError: (Object e, StackTrace? s) {
      if (!done.isCompleted) done.completeError(e, s);
    },
  );
  stream.addListener(listener);
  final info = await done.future;
  return Size(info.image.width.toDouble(), info.image.height.toDouble());
}

extension on ImageProvider? {
  ResizeImage get asResize => this as ResizeImage;
}

void main() {
  late _FakeRepository repository;
  late ArtworkCache cache;
  late ValueNotifier<_Params> params;
  late _Probe probe;

  setUp(() {
    repository = _FakeRepository();
    cache = ArtworkCache(repository);
    probe = _Probe();
  });

  Future<void> pumpIndividual(WidgetTester tester, _Params initial) async {
    params = ValueNotifier(initial);
    addTearDown(params.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [artworkCacheProvider.overrideWithValue(cache)],
        child: ValueListenableBuilder<_Params>(
          valueListenable: params,
          builder: (context, p, _) => MediaQuery(
            data: MediaQueryData(devicePixelRatio: p.dpr),
            child: AlbumArtworkBuilder.reference(
              reference: localArtworkReference(p.albumId),
              size: p.size,
              builder: (context, image) {
                probe.image = image;
                probe.imageHistory.add(image);
                return const SizedBox();
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> pumpMosaic(WidgetTester tester, _Params initial) async {
    params = ValueNotifier(initial);
    addTearDown(params.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [artworkCacheProvider.overrideWithValue(cache)],
        child: ValueListenableBuilder<_Params>(
          valueListenable: params,
          builder: (context, p, _) => MediaQuery(
            data: MediaQueryData(devicePixelRatio: p.dpr),
            child: AlbumArtworkMosaicBuilder(
              references: [for (final id in p.albumIds) localArtworkReference(id)],
              size: p.size,
              builder: (context, images) {
                probe.images = images;
                probe.imagesHistory.add(images);
                return const SizedBox();
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> update(WidgetTester tester, _Params next) async {
    params.value = next;
    await tester.pumpAndSettle();
  }

  group('AlbumArtworkBuilder (individual)', () {
    testWidgets('artwork disponible: ResizeImage sobre MemoryImage con los '
        'bytes del álbum', (tester) async {
      await pumpIndividual(tester, const _Params(albumId: 7));

      expect(probe.image, isA<ResizeImage>());
      expect(probe.image.asResize.imageProvider, isA<MemoryImage>());
      expect(memoryImageOf(probe.image!).bytes, [7]);
    });

    testWidgets('ResizeImage: ancho = (size × dpr).round(), sin alto y sin '
        'ampliar', (tester) async {
      await pumpIndividual(
        tester,
        const _Params(albumId: 7, size: 56, dpr: 2.625),
      );

      final resize = probe.image.asResize;
      expect(resize.width, 147); // (56 × 2,625).round()
      expect(resize.height, isNull);
      expect(resize.allowUpscaling, isFalse);
      expect(resize.policy, ResizeImagePolicy.exact);
      // Lo pedido al repositorio y el ancho de decodificación coinciden hoy,
      // pero son dos valores: aquí se comprueba cada uno.
      expect(repository.sizes, [147]);
    });

    testWidgets('cambio de size o dpr: el ancho de decodificación sigue al '
        'tamaño nuevo', (tester) async {
      await pumpIndividual(tester, const _Params(albumId: 7));
      expect(probe.image.asResize.width, 96);

      await update(tester, params.value.copyWith(size: 64));
      expect(probe.image.asResize.width, 128);

      await update(tester, params.value.copyWith(dpr: 3));
      expect(probe.image.asResize.width, 192);
    });

    testWidgets('MemoryImage sobre los mismos bytes de la caché',
        (tester) async {
      await pumpIndividual(tester, const _Params(albumId: 7));

      expect(
        identical(
          memoryImageOf(probe.image!).bytes,
          cache.peek((reference: const LocalArtworkReference(7), size: 96)),
        ),
        isTrue,
      );
    });

    testWidgets('mientras carga entrega null y luego la imagen (cache miss)',
        (tester) async {
      await pumpIndividual(tester, const _Params(albumId: 7));

      expect(probe.imageHistory.first, isNull);
      expect(_firstByte(probe.imageHistory.last), 7);
      expect(repository.requests, hasLength(1));
    });

    testWidgets('cache hit: la primera construcción ya trae la imagen',
        (tester) async {
      await cache.load((reference: const LocalArtworkReference(7), size: 96));
      repository.requests.clear();

      await pumpIndividual(tester, const _Params(albumId: 7));

      expect(_firstByte(probe.imageHistory.first), 7);
      expect(repository.requests, isEmpty);
    });

    testWidgets('artwork ausente: null, sin excepción', (tester) async {
      repository.missing.add(7);
      await pumpIndividual(tester, const _Params(albumId: 7));

      expect(probe.image, isNull);
      expect(tester.takeException(), isNull);
      expect(repository.requests, hasLength(1));
    });

    testWidgets('bytes vacíos: null', (tester) async {
      repository.empty.add(7);
      await pumpIndividual(tester, const _Params(albumId: 7));

      expect(probe.image, isNull);
      expect(tester.takeException(), isNull);
    });

    testWidgets('lectura fallida: null, sin excepción', (tester) async {
      repository.failing.add(7);
      await pumpIndividual(tester, const _Params(albumId: 7));

      expect(probe.image, isNull);
      expect(tester.takeException(), isNull);
    });

    testWidgets('albumId null: null y ninguna petición', (tester) async {
      await pumpIndividual(tester, const _Params());

      expect(probe.image, isNull);
      expect(repository.requests, isEmpty);
    });

    testWidgets('no repite la carga con la misma clave al reconstruir',
        (tester) async {
      await pumpIndividual(tester, const _Params(albumId: 7));

      await update(tester, params.value.copyWith(tick: 1));
      await update(tester, params.value.copyWith(tick: 2));

      expect(repository.requests, hasLength(1));
      expect(_firstByte(probe.image), 7);
    });

    testWidgets('dos widgets con el mismo álbum y tamaño comparten la lectura',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [artworkCacheProvider.overrideWithValue(cache)],
          child: MediaQuery(
            data: const MediaQueryData(devicePixelRatio: 2),
            child: Column(
              textDirection: TextDirection.ltr,
              children: [
                for (var i = 0; i < 2; i++)
                  AlbumArtworkBuilder.reference(
                    reference: const LocalArtworkReference(7),
                    size: 48,
                    builder: (context, image) => const SizedBox(),
                  ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(repository.requests, hasLength(1));
    });

    testWidgets('cambio de albumId: vuelve a resolver', (tester) async {
      await pumpIndividual(tester, const _Params(albumId: 7));

      await update(tester, params.value.copyWith(albumId: 8));

      expect(_firstByte(probe.image), 8);
      expect(repository.albumIds, [7, 8]);
    });

    testWidgets('cambio de albumId a null: entrega null', (tester) async {
      await pumpIndividual(tester, const _Params(albumId: 7));

      params.value = const _Params(albumId: null);
      await tester.pumpAndSettle();

      expect(probe.image, isNull);
    });

    testWidgets('un resultado tardío de un álbum anterior se ignora',
        (tester) async {
      repository.gates[7] = Completer<void>();
      await pumpIndividual(tester, const _Params(albumId: 7));
      expect(probe.image, isNull);

      await update(tester, params.value.copyWith(albumId: 8));
      expect(_firstByte(probe.image), 8);

      repository.gates[7]!.complete();
      await tester.pumpAndSettle();

      expect(_firstByte(probe.image), 8);
    });

    testWidgets('cambio de size: pide de nuevo al tamaño nuevo',
        (tester) async {
      await pumpIndividual(tester, const _Params(albumId: 7));

      await update(tester, params.value.copyWith(size: 64));

      expect(repository.sizes, [96, 128]);
      expect(_firstByte(probe.image), 7);
    });

    testWidgets('cambio de dpr: pide de nuevo al tamaño nuevo',
        (tester) async {
      await pumpIndividual(tester, const _Params(albumId: 7));

      await update(tester, params.value.copyWith(dpr: 3));

      expect(repository.sizes, [96, 144]);
    });

    testWidgets('tamaño físico = (size × dpr).round(), sin fijar 48',
        (tester) async {
      await pumpIndividual(
        tester,
        const _Params(albumId: 7, size: 56, dpr: 2.625),
      );
      expect(repository.sizes, [(56 * 2.625).round()]); // 147

      await update(tester, params.value.copyWith(size: 128.4, dpr: 3));
      expect(repository.sizes.last, (128.4 * 3).round()); // 385
    });
  });

  // Decodificación real (PNG reales): lo que Flutter decodifica de verdad.
  group('decodificación acotada (Fase 1.8L)', () {
    // size 256 × dpr 2 = 512 px físicos.
    const individual = _Params(albumId: 7, size: 256);

    Future<Size> decode(
      WidgetTester tester,
      int width,
      int height,
    ) async {
      final bytes = await tester.runAsync(
        () => _png(width, height, const Color(0xFF336699)),
      );
      repository.artwork[7] = bytes!;
      await pumpIndividual(tester, individual);
      expect(repository.sizes, [512]);
      final size = await tester.runAsync(() => _decodedSize(probe.image!));
      return size!;
    }

    setUp(() => PaintingBinding.instance.imageCache.clear());
    tearDown(() => PaintingBinding.instance.imageCache.clear());

    testWidgets('fuente mayor que el target (1000×1000 → 512)',
        (tester) async {
      expect(await decode(tester, 1000, 1000), const Size(512, 512));
    });

    testWidgets('fuente igual al target (512×512 → 512)', (tester) async {
      expect(await decode(tester, 512, 512), const Size(512, 512));
    });

    testWidgets('fuente menor que el target: NO se amplía (300×300 → 300)',
        (tester) async {
      expect(await decode(tester, 300, 300), const Size(300, 300));
    });

    testWidgets('fuente mucho menor: NO se amplía (64×64 → 64)',
        (tester) async {
      expect(await decode(tester, 64, 64), const Size(64, 64));
    });

    testWidgets('rectangular 1000×600 → 512: conserva la relación de aspecto',
        (tester) async {
      final size = await decode(tester, 1000, 600);

      expect(size.width, 512);
      expect(size.height, 307); // 600 × 512 / 1000 = 307,2, sin deformar
      expect(size.width / size.height, closeTo(1000 / 600, 0.01));
    });

    testWidgets('rectangular menor que el target: sin ampliar ni deformar',
        (tester) async {
      expect(await decode(tester, 400, 240), const Size(400, 240));
    });

    testWidgets('mosaico: cada tesela se decodifica a su ancho físico',
        (tester) async {
      final bytes = await tester.runAsync(
        () => _png(1000, 1000, const Color(0xFF993366)),
      );
      repository.artwork[10] = bytes!;
      // 57 lp → tesela floor(57/2) = 28 lp × 2 = 56 px.
      await pumpMosaic(tester, const _Params(albumIds: [10], size: 57));

      expect(repository.sizes, [56]);
      expect(probe.images.single.asResize.width, 56);
      final size =
          await tester.runAsync(() => _decodedSize(probe.images.single!));
      expect(size, const Size(56, 56));
    });

    // ImageCache de Flutter: su clave es la del ImageProvider. La del
    // MemoryImage es la identidad de los bytes y la del ResizeImage añade el
    // ancho, así que unos bytes nuevos (p. ej. tras ArtworkCache.clear()) no
    // pueden recibir la imagen decodificada de los viejos.
    testWidgets('clear() de ArtworkCache y bytes nuevos: no se reutiliza la '
        'imagen decodificada anterior', (tester) async {
      final a = await tester.runAsync(
        () => _png(1000, 1000, const Color(0xFFAA0000)),
      );
      final b = await tester.runAsync(
        () => _png(800, 800, const Color(0xFF00AA00)),
      );
      repository.artwork[7] = a!;
      await pumpIndividual(tester, individual);
      final first = probe.image!;
      expect(
        await tester.runAsync(() => _decodedSize(first)),
        const Size(512, 512),
      );
      final firstKey = await first.obtainKey(ImageConfiguration.empty);

      // Otro artwork para el mismo álbum y tamaño tras limpiar la caché.
      cache.clear();
      repository.artwork[7] = b!;
      await tester.pumpWidget(const SizedBox());
      await pumpIndividual(tester, individual);
      final second = probe.image!;

      expect(identical(memoryImageOf(second).bytes, a), isFalse);
      expect(identical(memoryImageOf(second).bytes, b), isTrue);
      expect(await second.obtainKey(ImageConfiguration.empty), isNot(firstKey));
      // La ImageCache de Flutter sigue conteniendo la imagen vieja, pero la
      // nueva no la recibe: decodifica sus propios bytes (800 → 512).
      expect(
        PaintingBinding.instance.imageCache.containsKey(firstKey),
        isTrue,
      );
      expect(
        await tester.runAsync(() => _decodedSize(second)),
        const Size(512, 512),
      );
      expect(
        PaintingBinding.instance.imageCache.containsKey(
          await second.obtainKey(ImageConfiguration.empty),
        ),
        isTrue,
      );
    });

    testWidgets('mismos bytes y mismo ancho: misma clave (se reutiliza la '
        'decodificación)', (tester) async {
      await pumpIndividual(tester, individual);
      final first = probe.image!;
      await update(tester, individual.copyWith(tick: 1));

      expect(
        await probe.image!.obtainKey(ImageConfiguration.empty),
        await first.obtainKey(ImageConfiguration.empty),
      );
    });

    testWidgets('mismos bytes con otro ancho: otra clave', (tester) async {
      await pumpIndividual(tester, individual);
      final at512 = await probe.image!.obtainKey(ImageConfiguration.empty);
      await cache.load((reference: const LocalArtworkReference(7), size: 768));
      await update(tester, individual.copyWith(size: 384));

      // Los bytes son otros (otra entrada de la caché) y el ancho también.
      expect(
        await probe.image!.obtainKey(ImageConfiguration.empty),
        isNot(at512),
      );
      expect(probe.image.asResize.width, 768);
    });
  });

  group('AlbumArtworkMosaicBuilder', () {
    for (final count in [1, 2, 3, 4]) {
      testWidgets('$count álbum(es): una imagen por álbum, en orden',
          (tester) async {
        final ids = [for (var i = 0; i < count; i++) 10 + i];
        await pumpMosaic(tester, _Params(albumIds: ids));

        expect(probe.images, hasLength(count));
        expect(_firstBytes(probe.images), ids);
        expect(repository.requests, hasLength(count));
      });
    }

    testWidgets('el orden recibido se conserva (sin reordenar)',
        (tester) async {
      await pumpMosaic(tester, const _Params(albumIds: [30, 10, 20, 40]));

      expect(_firstBytes(probe.images), [30, 10, 20, 40]);
    });

    testWidgets('albumId null: null en su posición y sin petición',
        (tester) async {
      await pumpMosaic(tester, const _Params(albumIds: [10, null, 20]));

      expect(_firstBytes(probe.images), [10, null, 20]);
      expect(repository.albumIds, [10, 20]);
    });

    testWidgets('artwork ausente y bytes vacíos: null en su posición',
        (tester) async {
      repository
        ..missing.add(20)
        ..empty.add(30);
      await pumpMosaic(tester, const _Params(albumIds: [10, 20, 30, 40]));

      expect(_firstBytes(probe.images), [10, null, null, 40]);
      expect(tester.takeException(), isNull);
    });

    testWidgets('lectura fallida: null en su posición, sin excepción',
        (tester) async {
      repository.failing.add(20);
      await pumpMosaic(tester, const _Params(albumIds: [10, 20]));

      expect(_firstBytes(probe.images), [10, null]);
      expect(tester.takeException(), isNull);
    });

    testWidgets('lista vacía: entrega una lista vacía', (tester) async {
      await pumpMosaic(tester, const _Params());

      expect(probe.images, isEmpty);
      expect(repository.requests, isEmpty);
    });

    testWidgets('un álbum repetido: una sola lectura, dos imágenes',
        (tester) async {
      await pumpMosaic(tester, const _Params(albumIds: [10, 10, 20]));

      expect(_firstBytes(probe.images), [10, 10, 20]);
      expect(repository.requests, hasLength(2));
    });

    testWidgets('cada tesela se pide a floor(size / 2) × dpr', (tester) async {
      await pumpMosaic(tester, const _Params(albumIds: [10, 20], size: 57));

      // floor(57 / 2) = 28 → 28 × 2 = 56 px, no 57 × 2 ni 28.5 × 2.
      expect(repository.sizes, [56, 56]);
    });

    testWidgets('tamaño de tesela con dpr fraccionario', (tester) async {
      await pumpMosaic(
        tester,
        const _Params(albumIds: [10], size: 56, dpr: 2.625),
      );

      expect(repository.sizes, [(28 * 2.625).round()]); // 74
    });

    testWidgets('cambio de size: pide de nuevo las teselas', (tester) async {
      await pumpMosaic(tester, const _Params(albumIds: [10, 20], size: 56));

      await update(tester, params.value.copyWith(size: 128));

      expect(repository.sizes, [56, 56, 128, 128]);
      expect(_firstBytes(probe.images), [10, 20]);
    });

    testWidgets('cambio de dpr: pide de nuevo las teselas', (tester) async {
      await pumpMosaic(tester, const _Params(albumIds: [10, 20], size: 56));

      await update(tester, params.value.copyWith(dpr: 3));

      expect(repository.sizes, [56, 56, 84, 84]);
    });

    testWidgets('cambio de lista: pide solo lo nuevo y descarta lo quitado',
        (tester) async {
      await pumpMosaic(tester, const _Params(albumIds: [10, 20]));

      await update(tester, params.value.copyWith(albumIds: [20, 30, 40]));

      expect(_firstBytes(probe.images), [20, 30, 40]);
      // 20 ya estaba en la caché al mismo tamaño: no se vuelve a pedir.
      expect(repository.albumIds, [10, 20, 30, 40]);
    });

    testWidgets('misma lista en otra instancia: no repite peticiones',
        (tester) async {
      await pumpMosaic(tester, const _Params(albumIds: [10, 20]));

      await update(
        tester,
        params.value.copyWith(albumIds: [10, 20], tick: 1),
      );
      await update(tester, params.value.copyWith(tick: 2));

      expect(repository.requests, hasLength(2));
      expect(_firstBytes(probe.images), [10, 20]);
    });

    testWidgets('cache hit: la primera construcción ya trae las imágenes',
        (tester) async {
      await cache.load((reference: const LocalArtworkReference(10), size: 56));
      await cache.load((reference: const LocalArtworkReference(20), size: 56));
      repository.requests.clear();

      await pumpMosaic(tester, const _Params(albumIds: [10, 20], size: 56));

      expect(_firstBytes(probe.imagesHistory.first), [10, 20]);
      expect(repository.requests, isEmpty);
    });
  });

  group('AlbumArtworkBuilder.reference', () {
    Future<void> pumpReference(
      WidgetTester tester,
      ArtworkReference reference,
      ArtworkCache cache,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [artworkCacheProvider.overrideWithValue(cache)],
          child: MediaQuery(
            data: const MediaQueryData(devicePixelRatio: 2),
            child: AlbumArtworkBuilder.reference(
              reference: reference,
              size: 48,
              builder: (context, image) {
                probe.image = image;
                return const SizedBox();
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('local: igual que por albumId', (tester) async {
      await pumpReference(tester, const LocalArtworkReference(7), cache);

      expect(_firstByte(probe.image), 7);
      expect(repository.albumIds, [7]);
    });

    testWidgets('remota con cargador (falso, sin red): entrega la imagen',
        (tester) async {
      final loader = _FakeRemoteLoader(Uint8List.fromList([42]));
      final remoteCache = ArtworkCache(repository, remoteLoader: loader);

      await pumpReference(
        tester,
        RemoteArtworkReference('https://x/a.jpg'),
        remoteCache,
      );

      expect(_firstByte(probe.image), 42);
      expect(loader.sizes, [96]);
      expect(repository.requests, isEmpty);
    });

    testWidgets('remota sin cargador: null, sin tocar el repositorio local',
        (tester) async {
      await pumpReference(tester, RemoteArtworkReference('7'), cache);

      expect(probe.image, isNull);
      expect(repository.requests, isEmpty);
    });

    testWidgets('no disponible: null sin pedir nada', (tester) async {
      await pumpReference(tester, const UnavailableArtworkReference(), cache);

      expect(probe.image, isNull);
      expect(repository.requests, isEmpty);
    });
  });
}

class _FakeRemoteLoader implements RemoteArtworkLoader {
  _FakeRemoteLoader(this.bytes);

  final Uint8List bytes;
  final sizes = <int>[];

  @override
  Future<Uint8List?> load(
    RemoteArtworkReference reference, {
    required int size,
  }) async {
    sizes.add(size);
    return bytes;
  }
}
