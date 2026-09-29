import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taki/core/artwork/album_artwork_image.dart';
import 'package:taki/core/artwork/artwork_cache.dart';
import 'package:taki/core/domain/ports/artwork_repository.dart';
import 'package:taki/core/theme/taki_colors.dart';
import 'package:taki/core/theme/taki_elevation.dart';
import 'package:taki/core/theme/taki_radius.dart';
import 'package:taki/core/widgets/taki_artwork.dart';

/// PNG válido de 1×1.
final Uint8List _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=',
);

class _FakeArtworkRepository implements ArtworkRepository {
  _FakeArtworkRepository(this.bytes);

  final Uint8List? bytes;
  final List<({int albumId, int size})> requests = [];

  @override
  Future<Uint8List?> getAlbumArtwork(int albumId, {required int size}) async {
    requests.add((albumId: albumId, size: size));
    return bytes;
  }
}

Future<void> _pump(WidgetTester tester, Widget child) {
  return tester.pumpWidget(
    MaterialApp(home: Scaffold(body: Center(child: child))),
  );
}

/// Resuelve la carga de la imagen (decodificar necesita I/O real).
Future<void> _settleImage(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

Finder _placeholderIcon(IconData icon) => find.byIcon(icon);

bool _imageShown(WidgetTester tester) {
  final raw = find.byType(RawImage);
  return raw.evaluate().isNotEmpty && tester.widget<RawImage>(raw).image != null;
}

void main() {
  group('placeholder', () {
    testWidgets('sin imagen: fondo surface e icono del tipo al 45 %',
        (tester) async {
      await _pump(tester, const TakiArtwork(size: 100));

      final icon = tester.widget<Icon>(_placeholderIcon(Icons.music_note_rounded));
      expect(icon.size, 45);
      expect(icon.color, TakiColors.iconSecondary);
      expect(
        tester.widget<ColoredBox>(find.descendant(
          of: find.byType(TakiArtwork),
          matching: find.byType(ColoredBox),
        )).color,
        TakiColors.surface,
      );
    });

    testWidgets('el icono depende del tipo de contenido', (tester) async {
      for (final kind in TakiArtworkKind.values) {
        await _pump(tester, TakiArtwork(size: 48, kind: kind));
        expect(_placeholderIcon(kind.placeholderIcon), findsOneWidget,
            reason: kind.name);
      }
    });
  });

  group('forma', () {
    testWidgets('el radio sale del tamaño (§4)', (tester) async {
      for (final size in [48.0, 128.0, 240.0]) {
        await _pump(tester, TakiArtwork(size: size));
        final clip = tester.widget<ClipRRect>(find.byType(ClipRRect));
        expect(
          clip.borderRadius,
          BorderRadius.circular(TakiRadius.forArtwork(size)),
          reason: '$size',
        );
        expect(tester.getSize(find.byType(TakiArtwork)), Size.square(size));
      }
    });

    testWidgets('los artistas van en círculo', (tester) async {
      await _pump(
        tester,
        const TakiArtwork(size: 64, kind: TakiArtworkKind.artist),
      );
      expect(find.byType(ClipOval), findsOneWidget);
      expect(find.byType(ClipRRect), findsNothing);
    });

    testWidgets('solo el artwork hero lleva la sombra del sistema',
        (tester) async {
      await _pump(tester, const TakiArtwork(size: 240, hero: true));
      final box = tester.widget<DecoratedBox>(find.descendant(
        of: find.byType(TakiArtwork),
        matching: find.byType(DecoratedBox),
      ));
      expect((box.decoration as BoxDecoration).boxShadow,
          [TakiElevation.artworkShadow]);

      await _pump(tester, const TakiArtwork(size: 240));
      expect(
        find.descendant(
          of: find.byType(TakiArtwork),
          matching: find.byType(DecoratedBox),
        ),
        findsNothing,
      );
    });
  });

  group('con imagen', () {
    testWidgets('se muestra la carátula', (tester) async {
      await _pump(tester, TakiArtwork(size: 48, image: MemoryImage(_png)));
      await _settleImage(tester);

      expect(_imageShown(tester), isTrue);
    });

    testWidgets('si la imagen falla queda el placeholder, sin error',
        (tester) async {
      await _pump(
        tester,
        TakiArtwork(size: 48, image: MemoryImage(Uint8List.fromList([1, 2, 3]))),
      );
      await _settleImage(tester);

      expect(_imageShown(tester), isFalse);
      expect(_placeholderIcon(Icons.music_note_rounded), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('AlbumArtworkImage (caché de carátulas existente)', () {
    testWidgets('pide la carátula al tamaño en píxeles reales', (tester) async {
      final repository = _FakeArtworkRepository(_png);
      final cache = ArtworkCache(repository);

      await _pump(
        tester,
        TakiArtwork(
          size: 48,
          image: AlbumArtworkImage(7, size: 48, cache: cache),
        ),
      );
      await _settleImage(tester);

      final ratio = tester.view.devicePixelRatio;
      expect(repository.requests, [(albumId: 7, size: (48 * ratio).round())]);
      expect(_imageShown(tester), isTrue);
    });

    testWidgets('un álbum sin carátula muestra el placeholder', (tester) async {
      final cache = ArtworkCache(_FakeArtworkRepository(null));

      await _pump(
        tester,
        TakiArtwork(
          size: 48,
          kind: TakiArtworkKind.playlist,
          image: AlbumArtworkImage(8, size: 48, cache: cache),
        ),
      );
      await _settleImage(tester);

      expect(_imageShown(tester), isFalse);
      expect(_placeholderIcon(Icons.queue_music_rounded), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('semántica', () {
    testWidgets('con etiqueta se anuncia como imagen', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(
        tester,
        const TakiArtwork(size: 48, semanticLabel: 'Portada de Matador'),
      );

      expect(
        tester.getSemantics(find.bySemanticsLabel('Portada de Matador')),
        isSemantics(label: 'Portada de Matador', isImage: true),
      );
      handle.dispose();
    });

    testWidgets('sin etiqueta es decorativa', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, const TakiArtwork(size: 48));

      expect(
        find.descendant(
          of: find.byType(TakiArtwork),
          matching: find.byWidgetPredicate(
            (w) => w is Semantics && (w.properties.image ?? false),
          ),
        ),
        findsNothing,
      );
      expect(find.byType(ExcludeSemantics), findsWidgets);
      handle.dispose();
    });
  });
}
