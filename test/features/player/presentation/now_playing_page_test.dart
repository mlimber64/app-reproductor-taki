import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:taki/core/theme/app_colors.dart';
import 'package:taki/app/theme/app_theme.dart';
import 'package:taki/core/theme/taki_colors.dart';
import 'package:taki/core/theme/taki_icon_size.dart';
import 'package:taki/core/theme/taki_typography.dart';
import 'package:taki/core/widgets/taki_artwork.dart';
import 'package:taki/features/library/presentation/providers/favorites_providers.dart';
import 'package:taki/core/artwork/artwork_providers.dart';
import 'package:taki/features/player/domain/entities/playback_state.dart';
import 'package:taki/features/player/presentation/pages/now_playing_page.dart';
import 'package:taki/features/player/presentation/providers/player_providers.dart';

import '../../../helpers/favorites_fakes.dart';
import '../../../helpers/library_fakes.dart';
import '../../../helpers/player_fakes.dart';

void main() {
  late FakeAudioPlayerPort player;
  late FakeFavoritesRepository favorites;
  late MockSeek seek;
  late int queueOpened;

  final song = buildSong(
    title: 'Un título bastante largo para comprobar el recorte',
    artist: 'Artista de prueba',
    durationMs: 200000,
  );

  setUpAll(() {
    registerFallbackValue(Duration.zero);
  });

  setUp(() {
    player = FakeAudioPlayerPort();
    favorites = FakeFavoritesRepository();
    seek = MockSeek();
    queueOpened = 0;
    when(() => seek(any())).thenAnswer((_) async {});
  });

  /// Publica la canción actual y abre Reproduciendo sobre una página base.
  Future<void> openNowPlaying(
    WidgetTester tester, {
    Size size = const Size(400, 800),
    PlaybackState? state,
    List<Override> overrides = const [],
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          audioPlayerPortProvider.overrideWithValue(player),
          artworkRepositoryProvider.overrideWithValue(NoArtworkRepository()),
          seekProvider.overrideWithValue(seek),
          favoritesRepositoryProvider.overrideWithValue(favorites),
          ...overrides,
        ],
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => NowPlayingPage(
                      onOpenQueue: () => queueOpened++,
                    ),
                  ),
                ),
                child: const Text('Base'),
              ),
            ),
          ),
        ),
      ),
    );

    player.emitState(state ?? PlaybackState(queue: [song], currentIndex: 0));
    await tester.tap(find.text('Base'));
    await tester.pumpAndSettle();
  }

  Color? iconColor(WidgetTester tester, IconData icon) =>
      tester.widget<Icon>(find.byIcon(icon)).color;

  Color accentOf(WidgetTester tester) =>
      Theme.of(tester.element(find.byType(NowPlayingPage)))
          .colorScheme
          .primary;

  testWidgets('muestra título, artista y origen', (tester) async {
    await openNowPlaying(tester);

    expect(find.text(song.title), findsOneWidget);
    expect(find.text('Artista de prueba'), findsOneWidget);
    expect(find.text('REPRODUCIENDO DESDE'), findsOneWidget);
    expect(find.text('Biblioteca'), findsOneWidget);
    expect(find.text('3:20'), findsOneWidget);
  });

  group('corazón de favoritos', () {
    testWidgets('marca y desmarca la canción', (tester) async {
      await openNowPlaying(tester);
      expect(find.byTooltip('Añadir a favoritos'), findsOneWidget);
      expect(find.byIcon(Icons.favorite_border_rounded), findsOneWidget);

      await tester.tap(find.byTooltip('Añadir a favoritos'));
      await tester.pumpAndSettle();

      expect(favorites.entries.keys, [song.id]);
      expect(find.byTooltip('Quitar de favoritos'), findsOneWidget);
      expect(
        tester.widget<Icon>(find.byIcon(Icons.favorite_rounded)).color,
        accentOf(tester),
      );

      await tester.tap(find.byTooltip('Quitar de favoritos'));
      await tester.pumpAndSettle();
      expect(favorites.entries, isEmpty);
      expect(
        tester.widget<Icon>(find.byIcon(Icons.favorite_border_rounded)).color,
        AppColors.textSecondary,
      );
    });

    testWidgets('llama a ToggleFavorite con la canción actual',
        (tester) async {
      final toggle = MockToggleFavorite();
      when(() => toggle(song)).thenAnswer((_) async => true);
      await openNowPlaying(
        tester,
        overrides: [toggleFavoriteProvider.overrideWithValue(toggle)],
      );

      await tester.tap(find.byTooltip('Añadir a favoritos'));
      await tester.pumpAndSettle();

      verify(() => toggle(song)).called(1);
    });

    testWidgets('se sincroniza si se marca desde otro lugar o cambia la canción',
        (tester) async {
      final other = buildSong(id: 99, title: 'Otra');
      await openNowPlaying(
        tester,
        state: PlaybackState(queue: [song, other], currentIndex: 0),
      );

      await favorites.add(song);
      await tester.pumpAndSettle();
      expect(find.byTooltip('Quitar de favoritos'), findsOneWidget);

      player.emitState(PlaybackState(queue: [song, other], currentIndex: 1));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Añadir a favoritos'), findsOneWidget);
    });

    testWidgets('con la base no disponible avisa sin romperse',
        (tester) async {
      favorites.failing = true;
      await openNowPlaying(tester);

      await tester.tap(find.byTooltip('Añadir a favoritos'));
      await tester.pumpAndSettle();

      expect(find.text('Los favoritos no están disponibles'), findsOneWidget);
    });
  });

  testWidgets('el botón Cola abre la cola', (tester) async {
    await openNowPlaying(tester);

    await tester.tap(find.text('Cola'));
    await tester.pump();

    expect(queueOpened, 1);
    expect(
      tester.getSize(find.byTooltip('Abrir la cola')).height,
      greaterThanOrEqualTo(44),
    );
  });

  testWidgets('todos los controles tienen tooltip en español', (tester) async {
    await openNowPlaying(tester);

    for (final label in [
      'Aleatorio',
      'Anterior',
      'Reproducir',
      'Siguiente',
      'Repetir',
      'Cerrar',
    ]) {
      expect(find.byTooltip(label), findsOneWidget, reason: label);
    }
  });

  testWidgets('aleatorio activo: color **e** icono _on (§6.2)',
      (tester) async {
    await openNowPlaying(tester);
    final accent = accentOf(tester);

    expect(iconColor(tester, Icons.shuffle_rounded), AppColors.textSecondary);

    await tester.tap(find.byTooltip('Aleatorio'));
    await tester.pumpAndSettle();

    expect(player.calls, contains('setShuffle(true)'));
    expect(find.byIcon(Icons.shuffle_rounded), findsNothing);
    expect(iconColor(tester, Icons.shuffle_on_rounded), accent);
  });

  testWidgets('repetir recorre off → all → one → off con su ícono',
      (tester) async {
    await openNowPlaying(tester);
    final accent = accentOf(tester);

    expect(iconColor(tester, Icons.repeat_rounded), AppColors.textSecondary);

    await tester.tap(find.byTooltip('Repetir'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.repeat_rounded), findsNothing);
    expect(iconColor(tester, Icons.repeat_on_rounded), accent);

    await tester.tap(find.byTooltip('Repetir'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.repeat_on_rounded), findsNothing);
    expect(iconColor(tester, Icons.repeat_one_on_rounded), accent);

    await tester.tap(find.byTooltip('Repetir'));
    await tester.pumpAndSettle();
    expect(iconColor(tester, Icons.repeat_rounded), AppColors.textSecondary);
  });

  testWidgets('muestra un indicador de carga si está en buffering',
      (tester) async {
    await openNowPlaying(tester);

    // El spinner es infinito: pump en vez de pumpAndSettle.
    player.emitState(
      PlaybackState(queue: [song], currentIndex: 0, isBuffering: true),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('arrastrar la barra no hace seek hasta soltar', (tester) async {
    await openNowPlaying(tester);

    final slider = find.byType(Slider);
    final rect = tester.getRect(slider);
    // El pulgar está en 0: el track empieza tras 8 px de padding.
    final gesture =
        await tester.startGesture(Offset(rect.left + 8, rect.center.dy));
    await tester.pump();
    await gesture.moveTo(rect.center);
    await tester.pump();

    verifyNever(() => seek(any()));
    // Mientras se arrastra se ve la posición del dedo (mitad de 3:20).
    expect(find.text('1:40'), findsOneWidget);

    await gesture.up();
    await tester.pumpAndSettle();

    final target =
        verify(() => seek(captureAny())).captured.single as Duration;
    expect(target.inMilliseconds, closeTo(100000, 1000));
  });

  testWidgets('la barra muestra la posición actual', (tester) async {
    await openNowPlaying(tester);

    player.emitPosition(const Duration(minutes: 1, seconds: 5));
    await tester.pump();
    await tester.pump();

    expect(find.text('1:05'), findsOneWidget);
  });

  group('cerrar', () {
    testWidgets('con la flecha', (tester) async {
      await openNowPlaying(tester);
      await tester.tap(find.byTooltip('Cerrar'));
      await tester.pumpAndSettle();
      expect(find.byType(NowPlayingPage), findsNothing);
    });

    testWidgets('deslizando hacia abajo', (tester) async {
      await openNowPlaying(tester);
      await tester.fling(find.text('REPRODUCIENDO DESDE'),
          const Offset(0, 300), 1500);
      await tester.pumpAndSettle();
      expect(find.byType(NowPlayingPage), findsNothing);
    });

    testWidgets('un arrastre corto no la cierra', (tester) async {
      await openNowPlaying(tester);
      await tester.drag(find.text('REPRODUCIENDO DESDE'), const Offset(0, 40));
      await tester.pumpAndSettle();
      expect(find.byType(NowPlayingPage), findsOneWidget);
    });

    testWidgets('con el botón atrás del sistema', (tester) async {
      await openNowPlaying(tester);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(NowPlayingPage), findsNothing);
    });

    testWidgets('sola, si deja de haber canción', (tester) async {
      await openNowPlaying(tester);

      player.emitState(PlaybackState.empty);
      await tester.pumpAndSettle();

      expect(find.byType(NowPlayingPage), findsNothing);
      expect(find.text('Base'), findsOneWidget);
    });
  });

  group('Design System (Fase 1.6A)', () {
    testWidgets('sonando: pausa; en pausa: reproducir (forma, no solo color)',
        (tester) async {
      await openNowPlaying(
        tester,
        state: PlaybackState(queue: [song], currentIndex: 0, isPlaying: true),
      );
      expect(find.byTooltip('Pausar'), findsOneWidget);
      expect(find.byIcon(Icons.pause_rounded), findsOneWidget);

      player.emitState(PlaybackState(queue: [song], currentIndex: 0));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Reproducir'), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
    });

    testWidgets('los controles llaman a las acciones existentes',
        (tester) async {
      final toggle = MockTogglePlayPause();
      when(() => toggle()).thenAnswer((_) async {});
      await openNowPlaying(
        tester,
        overrides: [togglePlayPauseProvider.overrideWithValue(toggle)],
      );

      await tester.tap(find.byTooltip('Reproducir'));
      await tester.tap(find.byTooltip('Anterior'));
      await tester.tap(find.byTooltip('Siguiente'));
      await tester.pumpAndSettle();

      verify(() => toggle()).called(1);
      expect(player.calls, containsAll(['skipToPrevious', 'skipToNext']));
    });

    testWidgets('play/pausa: círculo naranja de 72 con icono de 40',
        (tester) async {
      await openNowPlaying(tester);
      final button = find.ancestor(
        of: find.byIcon(Icons.play_arrow_rounded),
        matching: find.byType(IconButton),
      );

      expect(tester.getSize(button), const Size(72, 72));
      final style = tester.widget<IconButton>(button).style!;
      expect(style.backgroundColor!.resolve({}), TakiColors.primary);
      expect(
        style.backgroundColor!.resolve({WidgetState.pressed}),
        TakiColors.primaryPressed,
      );
      expect(
        tester.widget<IconButton>(button).iconSize,
        TakiIconSize.hero.value,
      );
    });

    testWidgets('el naranja solo marca acción y estado', (tester) async {
      await openNowPlaying(tester);

      expect(
        tester.widget<Scaffold>(find.byType(Scaffold).last).backgroundColor,
        TakiColors.background,
      );
      // En reposo, aleatorio, repetir y favorito van en gris secundario.
      for (final icon in [
        Icons.shuffle_rounded,
        Icons.repeat_rounded,
        Icons.favorite_border_rounded,
      ]) {
        expect(iconColor(tester, icon), TakiColors.iconSecondary);
      }
    });

    testWidgets('textos con los roles de §2.2', (tester) async {
      await openNowPlaying(tester);

      final title = tester.widget<Text>(find.text(song.title)).style!;
      expect(title.fontFamily, TakiTypography.headline.fontFamily);
      expect(title.fontSize, TakiTypography.headline.fontSize);
      expect(title.fontWeight, TakiTypography.headline.fontWeight);

      final artist = tester.widget<Text>(find.text('Artista de prueba')).style!;
      expect(artist.fontSize, TakiTypography.bodyLarge.fontSize);
      expect(artist.color, TakiColors.textSecondary);

      final eyebrow =
          tester.widget<Text>(find.text('REPRODUCIENDO DESDE')).style!;
      expect(eyebrow.letterSpacing, TakiTypography.eyebrow.letterSpacing);
      expect(eyebrow.color, TakiColors.textMuted);

      final time = tester.widget<Text>(find.text('3:20')).style!;
      expect(
        time.fontFeatures,
        contains(const FontFeature.tabularFigures()),
      );
    });

    testWidgets('carátula: TakiArtwork hero (la única sombra de la pantalla)',
        (tester) async {
      await openNowPlaying(tester);

      final artwork = tester.widget<TakiArtwork>(find.byType(TakiArtwork));
      expect(artwork.hero, isTrue);
      expect(find.byType(TakiArtwork), findsOneWidget);
    });

    testWidgets('semántica: favorito, aleatorio y repetir como interruptores',
        (tester) async {
      final handle = tester.ensureSemantics();
      await openNowPlaying(
        tester,
        state: PlaybackState(
          queue: [song],
          currentIndex: 0,
          shuffleEnabled: true,
          repeatMode: RepeatMode.one,
        ),
      );
      await favorites.add(song);
      await tester.pumpAndSettle();

      expect(
        tester.getSemantics(find.bySemanticsLabel('Quitar de favoritos')),
        isSemantics(isButton: true, hasToggledState: true, isToggled: true),
      );
      expect(
        tester.getSemantics(find.bySemanticsLabel('Aleatorio')),
        isSemantics(hasToggledState: true, isToggled: true),
      );
      expect(
        tester.getSemantics(find.bySemanticsLabel('Repetir, una')),
        isSemantics(hasToggledState: true, isToggled: true),
      );
      expect(
        tester.getSemantics(find.bySemanticsLabel('Cerrar')),
        isSemantics(isButton: true, hasTapAction: true),
      );
      handle.dispose();
    });

    testWidgets('áreas táctiles de al menos 48', (tester) async {
      await openNowPlaying(tester);
      for (final label in [
        'Aleatorio',
        'Anterior',
        'Siguiente',
        'Repetir',
        'Cerrar',
        'Más opciones',
        'Añadir a favoritos',
      ]) {
        final size = tester.getSize(find.byTooltip(label));
        expect(size.width, greaterThanOrEqualTo(48), reason: label);
        expect(size.height, greaterThanOrEqualTo(48), reason: label);
      }
    });
  });

  group('pantallas', () {
    for (final (name, size) in [
      ('móvil 360x800', const Size(360, 800)),
      ('móvil 412x915', const Size(412, 915)),
      ('pequeña 360x640', const Size(360, 640)),
      ('muy baja 360x480', const Size(360, 480)),
      ('horizontal 640x360', const Size(640, 360)),
    ]) {
      testWidgets('$name: sin desbordes y con controles alcanzables',
          (tester) async {
        await openNowPlaying(tester, size: size);

        expect(tester.takeException(), isNull);
        // En pantallas muy bajas se desplaza (último recurso).
        await tester.ensureVisible(find.byTooltip('Siguiente'));
        await tester.pumpAndSettle();
        for (final label in ['Aleatorio', 'Siguiente', 'Repetir']) {
          final center = tester.getCenter(find.byTooltip(label));
          expect(center.dx, inInclusiveRange(0, size.width), reason: label);
          expect(center.dy, inInclusiveRange(0, size.height), reason: label);
        }
      });
    }
  });
}
