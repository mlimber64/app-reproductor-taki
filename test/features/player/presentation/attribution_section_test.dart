import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taki/app/theme/app_theme.dart';
import 'package:taki/core/domain/entities/attribution_lookup_result.dart';
import 'package:taki/core/domain/entities/music_identity.dart';
import 'package:taki/core/domain/entities/song.dart';
import 'package:taki/core/links/external_link_providers.dart';
import 'package:taki/core/lookup/attribution_lookup_providers.dart';
import 'package:taki/core/widgets/taki_button.dart';
import 'package:taki/features/player/presentation/widgets/attribution_section.dart';

import '../../../helpers/attribution_fakes.dart';
import '../../../helpers/universal_song.dart';

void main() {
  final idA = MusicIdentity('jamendo', 'A');
  final idB = MusicIdentity('jamendo', 'B');
  final songA = buildUniversalSong(idA, title: 'Canción A');
  final songB = buildUniversalSong(idB, title: 'Canción B');
  final page = Uri.parse('https://www.jamendo.com/track/1');
  final license = Uri.parse('https://creativecommons.org/licenses/by-nc-nd/3.0/');

  late ScriptedAttributionLookup lookup;
  late FakeLinkOpener opener;

  setUp(() {
    lookup = ScriptedAttributionLookup();
    opener = FakeLinkOpener();
  });

  Future<void> pump(WidgetTester tester, Song song) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          attributionLookupProvider.overrideWithValue(lookup),
          externalLinkOpenerProvider.overrideWithValue(opener),
        ],
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: Scaffold(body: AttributionSection(song: song)),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Deja que una respuesta del lookup llegue a la pantalla.
  Future<void> settle(WidgetTester tester) => tester.pumpAndSettle();

  Finder origin() => find.textContaining('Origen');
  Finder licenseLine() => find.textContaining('Licencia');
  Finder viewSong() => find.text(AttributionSection.viewSong);
  Finder viewLicense() => find.text(AttributionSection.viewLicense);

  group('estados de la consulta', () {
    testWidgets('cargando: no muestra nada (y no bloquea)', (tester) async {
      await pump(tester, songA);
      expect(origin(), findsNothing);
      expect(find.byType(TakiButton), findsNothing);
      expect(lookup.calls.single, {idA});
    });

    testWidgets('found: proveedor, licencia y los dos enlaces', (tester) async {
      await pump(tester, songA);
      lookup.found(testAttribution(idA,
          pageUrl: page, licenseUrl: license, licenseName: 'CC BY-NC-ND 3.0'));
      await settle(tester);

      expect(find.text('Origen · Jamendo'), findsOneWidget);
      expect(find.text('Licencia · CC BY-NC-ND 3.0'), findsOneWidget);
      expect(viewSong(), findsOneWidget);
      expect(viewLicense(), findsOneWidget);
    });

    testWidgets('absent: no hay sección (ni vacía)', (tester) async {
      await pump(tester, songA);
      lookup.absent(idA);
      await settle(tester);
      expect(origin(), findsNothing);
      expect(licenseLine(), findsNothing);
      expect(find.byType(TakiButton), findsNothing);
      expect(find.byType(Text), findsNothing);
    });

    testWidgets('fallo: no muestra nada ni error, sin excepciones',
        (tester) async {
      await pump(tester, songA);
      lookup.fail(idA);
      await settle(tester);
      expect(origin(), findsNothing);
      expect(find.byType(Text), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('contenido parcial: no se inventa nada', () {
    Future<void> show(WidgetTester tester,
        {Uri? p, Uri? l, String? name}) async {
      await pump(tester, songA);
      lookup.found(
          testAttribution(idA, pageUrl: p, licenseUrl: l, licenseName: name));
      await settle(tester);
    }

    testWidgets('sin pageUrl: no hay «Ver canción»', (tester) async {
      await show(tester, l: license, name: 'CC BY 4.0');
      expect(viewSong(), findsNothing);
      expect(viewLicense(), findsOneWidget);
    });

    testWidgets('sin licenseUrl: no hay «Ver licencia»', (tester) async {
      await show(tester, p: page, name: 'CC BY 4.0');
      expect(viewLicense(), findsNothing);
      expect(viewSong(), findsOneWidget);
    });

    testWidgets('sin licenseName: no hay etiqueta de licencia', (tester) async {
      await show(tester, p: page, l: license);
      expect(licenseLine(), findsNothing);
      expect(find.text('Origen · Jamendo'), findsOneWidget);
    });

    testWidgets('licenseName en blanco: no hay etiqueta', (tester) async {
      await show(tester, p: page, name: '   ');
      expect(licenseLine(), findsNothing);
    });

    testWidgets('solo proveedor: sin botones', (tester) async {
      await show(tester);
      expect(find.text('Origen · Jamendo'), findsOneWidget);
      expect(find.byType(TakiButton), findsNothing);
    });

    testWidgets('una URL que no es http(s) no ofrece botón', (tester) async {
      await show(tester,
          p: Uri.parse('javascript:alert(1)'), l: Uri.parse('ftp://x.org/l'));
      expect(find.byType(TakiButton), findsNothing);
    });
  });

  group('enlaces', () {
    testWidgets('«Ver canción» abre exactamente pageUrl', (tester) async {
      await pump(tester, songA);
      lookup.found(testAttribution(idA, pageUrl: page, licenseUrl: license));
      await settle(tester);
      await tester.tap(viewSong());
      await tester.pump();
      expect(opener.opened, [page]);
    });

    testWidgets('«Ver licencia» abre exactamente licenseUrl', (tester) async {
      await pump(tester, songA);
      lookup.found(testAttribution(idA, pageUrl: page, licenseUrl: license));
      await settle(tester);
      await tester.tap(viewLicense());
      await tester.pump();
      expect(opener.opened, [license]);
    });

    testWidgets('si no se puede abrir: aviso discreto, sin excepción',
        (tester) async {
      opener.result = false;
      await pump(tester, songA);
      lookup.found(testAttribution(idA, pageUrl: page));
      await settle(tester);
      await tester.tap(viewSong());
      await tester.pump();
      await tester.pump();
      expect(find.text(AttributionSection.linkFailed), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('canción nueva', () {
    testWidgets('A pide, B pide, B responde y A responde tarde → solo B',
        (tester) async {
      await pump(tester, songA);
      await pump(tester, songB);
      expect(lookup.calls, [
        {idA},
        {idB},
      ]);

      lookup.found(testAttribution(idB,
          providerName: 'Prov B', pageUrl: page, licenseName: 'Lic B'));
      await settle(tester);
      expect(find.text('Origen · Prov B'), findsOneWidget);

      lookup.found(testAttribution(idA,
          providerName: 'Prov A', pageUrl: page, licenseName: 'Lic A'));
      await settle(tester);
      expect(find.text('Origen · Prov B'), findsOneWidget);
      expect(find.textContaining('Prov A'), findsNothing);
      expect(find.textContaining('Lic A'), findsNothing);
    });

    testWidgets('al cambiar de canción no queda la atribución de la anterior',
        (tester) async {
      await pump(tester, songA);
      lookup.found(testAttribution(idA, providerName: 'Prov A', pageUrl: page));
      await settle(tester);
      expect(find.text('Origen · Prov A'), findsOneWidget);

      await pump(tester, songB);
      expect(find.textContaining('Prov A'), findsNothing);

      lookup.absent(idB);
      await settle(tester);
      expect(origin(), findsNothing);
    });

    testWidgets('una respuesta de otra identidad bajo la actual no se pinta',
        (tester) async {
      final wrong = ImmediateAttributionLookup(
        (id) => AttributionLookupResult(
          found: {id: testAttribution(idB, providerName: 'Ajena')},
        ),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [attributionLookupProvider.overrideWithValue(wrong)],
          child: MaterialApp(
            home: Scaffold(body: AttributionSection(song: songA)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Ajena'), findsNothing);
    });
  });

  group('accesibilidad', () {
    testWidgets('los botones dicen qué canción y qué enlace', (tester) async {
      final handle = tester.ensureSemantics();
      await pump(tester, songA);
      lookup.found(testAttribution(idA, pageUrl: page, licenseUrl: license));
      await settle(tester);

      expect(find.bySemanticsLabel('Ver «Canción A» en Jamendo'),
          findsOneWidget);
      expect(find.bySemanticsLabel('Ver la licencia de «Canción A»'),
          findsOneWidget);
      handle.dispose();
    });
  });
}
