import 'dart:async';
import '../../../helpers/artwork_reference_ext.dart';
import 'dart:typed_data';

import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:taki/app/theme/app_theme.dart';
import 'package:taki/core/theme/taki_colors.dart';
import 'package:taki/core/theme/taki_icon_size.dart';
import 'package:taki/core/theme/taki_typography.dart';
import 'package:taki/core/widgets/taki_artwork.dart';
import 'package:taki/core/widgets/taki_playback_controls.dart';
import 'package:taki/core/widgets/taki_progress_bar.dart';
import 'package:taki/features/library/presentation/providers/favorites_providers.dart';
import 'package:taki/core/artwork/album_artwork_builder.dart';
import 'package:taki/core/artwork/artwork_providers.dart';
import 'package:taki/core/domain/ports/artwork_repository.dart';
import 'package:taki/features/player/domain/entities/playback_state.dart';
import 'package:taki/features/player/presentation/pages/now_playing_page.dart';
import 'package:taki/features/player/presentation/providers/player_providers.dart';

import 'package:taki/core/domain/entities/music_identity.dart';
import 'package:taki/core/links/external_link_providers.dart';
import 'package:taki/core/lookup/attribution_lookup_providers.dart';

import '../../../helpers/attribution_fakes.dart';
import '../../../helpers/universal_song.dart';
import '../../../helpers/favorites_fakes.dart';
import '../../../helpers/library_fakes.dart';
import '../../../helpers/player_fakes.dart';
import '../../../helpers/artwork_image.dart';

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

      expect(favorites.entries.keys, [song.musicIdentity]);
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
        TakiColors.textSecondary,
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

  /// Estado que reciben los controles reutilizables.
  TakiPlaybackControls controls(WidgetTester tester) =>
      tester.widget<TakiPlaybackControls>(find.byType(TakiPlaybackControls));

  /// Color del círculo detrás del icono de aleatorio o repetir (null si no hay).
  Color? toggleCircle(WidgetTester tester, String tooltip) {
    final container = tester.widget<AnimatedContainer>(find.descendant(
      of: find.byTooltip(tooltip),
      matching: find.byType(AnimatedContainer),
    ));
    final color = (container.decoration! as ShapeDecoration).color;
    return color == Colors.transparent ? null : color;
  }

  testWidgets('aleatorio: activa el del reproductor y se marca con círculo',
      (tester) async {
    await openNowPlaying(tester);
    final accent = accentOf(tester);

    expect(iconColor(tester, Icons.shuffle_rounded), TakiColors.textSecondary);
    expect(toggleCircle(tester, 'Aleatorio'), isNull);

    await tester.tap(find.byTooltip('Aleatorio'));
    await tester.pumpAndSettle();

    expect(player.calls, contains('setShuffle(true)'));
    expect(controls(tester).isShuffleEnabled, isTrue);
    expect(iconColor(tester, Icons.shuffle_rounded), accent);
    expect(toggleCircle(tester, 'Aleatorio'), TakiColors.primaryContainer);
    expect(find.byIcon(Icons.shuffle_on_rounded), findsNothing);

    await tester.tap(find.byTooltip('Aleatorio'));
    await tester.pumpAndSettle();
    expect(player.calls, contains('setShuffle(false)'));
    expect(controls(tester).isShuffleEnabled, isFalse);
    expect(toggleCircle(tester, 'Aleatorio'), isNull);
  });

  testWidgets('repetir recorre off → all → one → off con su ícono',
      (tester) async {
    await openNowPlaying(tester);
    final accent = accentOf(tester);

    expect(controls(tester).repeatMode, TakiRepeatMode.off);
    expect(iconColor(tester, Icons.repeat_rounded), TakiColors.textSecondary);
    expect(toggleCircle(tester, 'Repetir'), isNull);

    await tester.tap(find.byTooltip('Repetir'));
    await tester.pumpAndSettle();
    expect(player.calls.last, 'setRepeatMode(all)');
    expect(controls(tester).repeatMode, TakiRepeatMode.all);
    expect(iconColor(tester, Icons.repeat_rounded), accent);
    expect(toggleCircle(tester, 'Repetir'), TakiColors.primaryContainer);

    await tester.tap(find.byTooltip('Repetir'));
    await tester.pumpAndSettle();
    expect(player.calls.last, 'setRepeatMode(one)');
    expect(controls(tester).repeatMode, TakiRepeatMode.one);
    expect(find.byIcon(Icons.repeat_rounded), findsNothing);
    expect(iconColor(tester, Icons.repeat_one_rounded), accent);
    expect(toggleCircle(tester, 'Repetir'), TakiColors.primaryContainer);

    await tester.tap(find.byTooltip('Repetir'));
    await tester.pumpAndSettle();
    expect(player.calls.last, 'setRepeatMode(off)');
    expect(controls(tester).repeatMode, TakiRepeatMode.off);
    expect(iconColor(tester, Icons.repeat_rounded), TakiColors.textSecondary);
    expect(toggleCircle(tester, 'Repetir'), isNull);
  });

  testWidgets('el modo de repetición del reproductor llega a los controles',
      (tester) async {
    await openNowPlaying(tester);
    for (final (mode, expected) in [
      (RepeatMode.off, TakiRepeatMode.off),
      (RepeatMode.all, TakiRepeatMode.all),
      (RepeatMode.one, TakiRepeatMode.one),
    ]) {
      player.emitState(
        PlaybackState(queue: [song], currentIndex: 0, repeatMode: mode),
      );
      await tester.pumpAndSettle();
      expect(controls(tester).repeatMode, expected, reason: mode.name);
    }
  });

  testWidgets('en buffering: spinner, y play/pausa sigue respondiendo',
      (tester) async {
    final toggle = MockTogglePlayPause();
    when(() => toggle()).thenAnswer((_) async {});
    await openNowPlaying(
      tester,
      overrides: [togglePlayPauseProvider.overrideWithValue(toggle)],
    );

    // El spinner es infinito: pump en vez de pumpAndSettle.
    player.emitState(
      PlaybackState(
        queue: [song],
        currentIndex: 0,
        isPlaying: true,
        isBuffering: true,
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(controls(tester).isLoading, isTrue);
    expect(
      find.descendant(
        of: find.byType(TakiPlayPauseButton),
        matching: find.byType(CircularProgressIndicator),
      ),
      findsOneWidget,
    );

    // Como antes: se puede pausar sin esperar a que cargue.
    await tester.tap(find.byType(TakiPlayPauseButton));
    await tester.pump();
    verify(() => toggle()).called(1);

    player.emitState(
      PlaybackState(queue: [song], currentIndex: 0, isPlaying: true),
    );
    await tester.pumpAndSettle();
    expect(controls(tester).isLoading, isFalse);
    expect(find.byType(CircularProgressIndicator), findsNothing);
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

  testWidgets('tras soltar, la barra se queda en el destino hasta que el '
      'seek termina', (tester) async {
    final pending = Completer<void>();
    when(() => seek(any())).thenAnswer((_) => pending.future);
    await openNowPlaying(tester);

    await tester.tap(find.byType(Slider));
    await tester.pump();

    // El reproductor aún no se ha movido (posición 0), pero la barra
    // muestra el destino mientras el seek está en curso.
    verify(() => seek(any())).called(1);
    expect(find.text('1:40'), findsOneWidget);
    expect(find.text('0:00'), findsNothing);

    // Al terminar, vuelve a seguir la posición real del reproductor.
    player.emitPosition(const Duration(minutes: 1, seconds: 41));
    pending.complete();
    await tester.pumpAndSettle();
    expect(find.text('1:41'), findsOneWidget);
  });

  testWidgets('seek con TalkBack (acción aumentar) usa el mismo seek',
      (tester) async {
    final handle = tester.ensureSemantics();
    await openNowPlaying(tester);

    final node = tester.getSemantics(find.byType(Slider));
    expect(
      node,
      isSemantics(
        label: TakiProgressBar.semanticLabel,
        value: '0:00 de 3:20',
        isSlider: true,
      ),
    );
    node.owner!.performAction(node.id, SemanticsAction.increase);
    await tester.pumpAndSettle();

    final target =
        verify(() => seek(captureAny())).captured.single as Duration;
    expect(target, greaterThan(Duration.zero));
    handle.dispose();
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

    testWidgets('usa los componentes reutilizables (sin controles legacy)',
        (tester) async {
      await openNowPlaying(tester);

      expect(find.byType(TakiPlaybackControls), findsOneWidget);
      expect(find.byType(TakiProgressBar), findsOneWidget);
      expect(find.byType(Slider), findsOneWidget);
      expect(find.byType(IconButton), findsNothing);
      expect(find.byIcon(Icons.shuffle_on_rounded), findsNothing);
      expect(find.byIcon(Icons.repeat_on_rounded), findsNothing);
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
      await tester.pump();
      verify(() => toggle()).called(1);

      await tester.tap(find.byTooltip('Anterior'));
      await tester.pump();
      expect(player.calls.last, 'skipToPrevious');

      await tester.tap(find.byTooltip('Siguiente'));
      await tester.pumpAndSettle();
      expect(player.calls.last, 'skipToNext');
    });

    testWidgets('play/pausa usa TogglePlayPause real: reproduce y pausa',
        (tester) async {
      await openNowPlaying(tester);

      await tester.tap(find.byTooltip('Reproducir'));
      await tester.pumpAndSettle();
      expect(player.calls.last, 'play');
      expect(controls(tester).isPlaying, isTrue);

      await tester.tap(find.byTooltip('Pausar'));
      await tester.pumpAndSettle();
      expect(player.calls.last, 'pause');
    });

    testWidgets('play/pausa: círculo naranja de 72 con icono de 40',
        (tester) async {
      await openNowPlaying(tester);
      final button = find.byType(TakiPlayPauseButton);

      expect(tester.getSize(button), const Size(72, 72));
      final circle = tester.widget<Container>(
        find.descendant(of: button, matching: find.byType(Container)),
      );
      expect(
        (circle.decoration! as ShapeDecoration).color,
        TakiColors.primary,
      );
      final icon = tester.widget<Icon>(find.byIcon(Icons.play_arrow_rounded));
      expect(icon.size, TakiIconSize.hero.value);
      expect(icon.color, TakiColors.onPrimary);

      final gesture = await tester.startGesture(tester.getCenter(button));
      await tester.pump(const Duration(milliseconds: 100));
      final pressed = tester.widget<Container>(
        find.descendant(of: button, matching: find.byType(Container)),
      );
      expect(
        (pressed.decoration! as ShapeDecoration).color,
        TakiColors.primaryPressed,
      );
      await gesture.up();
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
        tester.getSemantics(find.bySemanticsLabel('Repetir')),
        isSemantics(hasToggledState: true, isToggled: true, value: 'una'),
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

  // Fase 3.2F: la atribución es secundaria y nunca bloquea la reproducción.
  group('Atribución (Fase 3.2F)', () {
    final idA = MusicIdentity('jamendo', 'A');
    final idB = MusicIdentity('jamendo', 'B');
    final songA = buildUniversalSong(idA, title: 'Remota A');
    final songB = buildUniversalSong(idB, title: 'Remota B');
    final pageUrl = Uri.parse('https://www.jamendo.com/track/A');
    final licenseUrl = Uri.parse('https://creativecommons.org/licenses/by/4.0/');
    late ScriptedAttributionLookup lookup;
    late FakeLinkOpener opener;

    setUp(() {
      lookup = ScriptedAttributionLookup();
      opener = FakeLinkOpener();
    });

    Future<void> open(WidgetTester tester, {Size size = const Size(400, 800)}) =>
        openNowPlaying(
          tester,
          size: size,
          state: PlaybackState(queue: [songA, songB], currentIndex: 0),
          overrides: [
            attributionLookupProvider.overrideWithValue(lookup),
            externalLinkOpenerProvider.overrideWithValue(opener),
          ],
        );

    testWidgets('muestra origen, licencia y enlaces cuando llega',
        (tester) async {
      await open(tester);
      expect(find.textContaining('Origen'), findsNothing);

      lookup.found(testAttribution(idA,
          pageUrl: pageUrl, licenseUrl: licenseUrl, licenseName: 'CC BY 4.0'));
      await tester.pumpAndSettle();

      expect(find.text('Origen · Jamendo'), findsOneWidget);
      expect(find.text('Licencia · CC BY 4.0'), findsOneWidget);
      await tester.tap(find.text('Ver canción'));
      await tester.pump();
      expect(opener.opened, [pageUrl]);
    });

    testWidgets('mientras carga, los controles y la carátula ya están',
        (tester) async {
      await open(tester);
      expect(find.byType(TakiPlaybackControls), findsOneWidget);
      expect(find.byType(AlbumArtworkBuilder), findsOneWidget);
      expect(find.text('Remota A'), findsOneWidget);
    });

    testWidgets('ausente: no aparece ninguna sección', (tester) async {
      await open(tester);
      lookup.absent(idA);
      await tester.pumpAndSettle();
      expect(find.textContaining('Origen'), findsNothing);
      expect(find.text('Ver canción'), findsNothing);
    });

    testWidgets('un fallo no muestra error ni bloquea la reproducción',
        (tester) async {
      await open(tester);
      lookup.fail(idA);
      await tester.pumpAndSettle();

      expect(find.textContaining('Origen'), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
      expect(tester.takeException(), isNull);
      // Los controles siguen funcionando.
      await tester.tap(find.byTooltip('Siguiente'));
      await tester.pump();
      expect(player.calls, contains('skipToNext'));
    });

    testWidgets('A → B: la respuesta tardía de A nunca se pinta sobre B',
        (tester) async {
      await open(tester);
      player.emitState(PlaybackState(queue: [songA, songB], currentIndex: 1));
      await tester.pumpAndSettle();
      expect(find.text('Remota B'), findsOneWidget);

      lookup.found(testAttribution(idB,
          providerName: 'Prov B', pageUrl: pageUrl, licenseName: 'Lic B'));
      await tester.pumpAndSettle();
      lookup.found(testAttribution(idA,
          providerName: 'Prov A', pageUrl: pageUrl, licenseName: 'Lic A'));
      await tester.pumpAndSettle();

      expect(find.text('Origen · Prov B'), findsOneWidget);
      expect(find.textContaining('Prov A'), findsNothing);
      expect(find.textContaining('Lic A'), findsNothing);
    });

    for (final size in [
      const Size(360, 800),
      const Size(360, 640),
      const Size(360, 480),
      const Size(640, 360),
    ]) {
      testWidgets('$size con atribución completa: sin desbordes',
          (tester) async {
        await open(tester, size: size);
        lookup.found(testAttribution(idA,
            pageUrl: pageUrl,
            licenseUrl: licenseUrl,
            licenseName: 'CC BY-NC-ND 3.0'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(find.text('Ver licencia'));
        await tester.pumpAndSettle();
        expect(find.text('Ver licencia'), findsOneWidget);
      });
    }
  });

  // La resolución de la carátula la hace AlbumArtworkBuilder (core/artwork). El
  // tamaño de Reproduciendo no es una constante: depende del layout (vertical,
  // pantalla muy baja con scroll, horizontal), así que se protege que el lado
  // pedido sea el que se dibuja.
  group('Artwork compartido (Fase 1.8D)', () {
    final other = buildSong(id: 2, title: 'Otra canción', albumId: 20);

    AlbumArtworkBuilder builderOf(WidgetTester tester) =>
        tester.widget<AlbumArtworkBuilder>(find.byType(AlbumArtworkBuilder));

    TakiArtwork artworkOf(WidgetTester tester) =>
        tester.widget<TakiArtwork>(find.byType(TakiArtwork));

    Future<_BytesArtworkRepository> open(
      WidgetTester tester, {
      void Function(_BytesArtworkRepository)? configure,
      Size size = const Size(400, 800),
      PlaybackState? state,
    }) async {
      final artwork = _BytesArtworkRepository();
      configure?.call(artwork);
      await openNowPlaying(
        tester,
        size: size,
        state: state,
        overrides: [artworkRepositoryProvider.overrideWithValue(artwork)],
      );
      return artwork;
    }

    // Lado de la carátula en cada layout, con la canción de estos tests (título
    // de dos líneas). Valores medidos con el adaptador anterior (idénticos con
    // el builder), para que un tamaño distinto falle.
    for (final size in [
      const Size(400, 800), // vertical
      const Size(360, 480), // muy baja, con scroll
      const Size(640, 360), // horizontal
    ]) {
      testWidgets('$size: usa song.artwork, no albumId', (tester) async {
        final remote = remoteArtworkSong();
        final artwork = await open(
          tester,
          size: size,
          state: PlaybackState(queue: [remote], currentIndex: 0),
        );

        expect(find.byType(AlbumArtworkBuilder), findsOneWidget);
        expect(builderOf(tester).reference, remoteTestArtwork);
        expect(builderOf(tester).albumId, isNull);
        expect(artwork.requests, isEmpty);
      });
    }

    for (final (name, size, side) in [
      ('vertical 400x800', const Size(400, 800), 342.0),
      ('vertical 360x800', const Size(360, 800), 312.0),
      ('vertical 412x915', const Size(412, 915), 364.0),
      // Ancho fraccionario: el lado se redondea hacia abajo (313.5 → 313).
      ('vertical 361.5x800', const Size(361.5, 800), 313.0),
      ('pequeña 360x640', const Size(360, 640), 182.0),
      ('muy baja 360x480 (con scroll)', const Size(360, 480), 240.0),
      ('horizontal 640x360', const Size(640, 360), 224.0),
    ]) {
      testWidgets('$name: usa AlbumArtworkBuilder con el albumId de la '
          'canción y el mismo lado que dibuja ($side)', (tester) async {
        final artwork = await open(tester, size: size);

        expect(find.byType(AlbumArtworkBuilder), findsOneWidget);
        final builder = builderOf(tester);
        expect(builder.albumId, song.albumId);
        // Lado entero, el esperado y el mismo que se dibuja.
        expect(builder.size, side);
        expect(artworkOf(tester).size, side);
        expect(tester.getSize(find.byType(TakiArtwork)).width, side);
        expect(artworkOf(tester).hero, isTrue);
        // La petición es ese lado × dpr (1 en estos tests).
        expect(artwork.requests, [(song.albumId, side.round())]);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('cambio de dpr: vuelve a pedir el mismo lado al tamaño físico '
        'nuevo', (tester) async {
      final artwork = await open(tester, size: const Size(360, 800));
      expect(artwork.requests, [(song.albumId, 312)]);

      // Misma pantalla lógica (360x800) a otra densidad.
      tester.view.physicalSize = const Size(360, 800) * 2.625;
      tester.view.devicePixelRatio = 2.625;
      await tester.pumpAndSettle();

      expect(builderOf(tester).size, 312);
      expect(artwork.requests, [
        (song.albumId, 312),
        (song.albumId, (312 * 2.625).round()), // 819
      ]);
    });

    testWidgets('artwork disponible: MemoryImage con los bytes del álbum',
        (tester) async {
      await open(tester);

      final image = memoryImageOf(artworkOf(tester).image!);
      expect(image.bytes.first, song.albumId);
    });

    testWidgets('artwork ausente: placeholder y la pantalla sigue entera',
        (tester) async {
      await open(tester, configure: (r) => r.missing.add(song.albumId!));

      expect(artworkOf(tester).image, isNull);
      expect(artworkOf(tester).hero, isTrue);
      expect(find.text(song.title), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('bytes vacíos: placeholder', (tester) async {
      await open(tester, configure: (r) => r.empty.add(song.albumId!));

      expect(artworkOf(tester).image, isNull);
    });

    testWidgets('canción sin álbum: placeholder y ninguna petición',
        (tester) async {
      final noAlbum = buildSong(title: 'Sin álbum', albumId: null);
      final artwork = await open(
        tester,
        state: PlaybackState(queue: [noAlbum], currentIndex: 0),
      );

      expect(builderOf(tester).albumId, isNull);
      expect(artworkOf(tester).image, isNull);
      expect(artwork.requests, isEmpty);
    });

    testWidgets('error de lectura: sin carátula y los controles siguen '
        'funcionando', (tester) async {
      await open(tester, configure: (r) => r.failing.add(song.albumId!));

      expect(artworkOf(tester).image, isNull);
      expect(tester.takeException(), isNull);
      for (final label in ['Aleatorio', 'Anterior', 'Reproducir', 'Siguiente']) {
        expect(find.byTooltip(label), findsOneWidget, reason: label);
      }

      player.emitState(
        PlaybackState(queue: [song], currentIndex: 0, isPlaying: true),
      );
      await tester.pumpAndSettle();
      expect(find.byTooltip('Pausar'), findsOneWidget);
    });

    testWidgets('cambio de canción: resuelve la carátula nueva y al volver '
        'no la repite', (tester) async {
      final artwork = await open(
        tester,
        state: PlaybackState(queue: [song, other], currentIndex: 0),
      );
      expect(memoryImageOf(artworkOf(tester).image!).bytes.first, 10);

      player.emitState(PlaybackState(queue: [song, other], currentIndex: 1));
      await tester.pumpAndSettle();
      expect(builderOf(tester).albumId, 20);
      expect(memoryImageOf(artworkOf(tester).image!).bytes.first, 20);

      player.emitState(PlaybackState(queue: [song, other], currentIndex: 0));
      await tester.pumpAndSettle();
      expect(memoryImageOf(artworkOf(tester).image!).bytes.first, 10);

      expect([for (final r in artwork.requests) r.$1], [10, 20]);
    });

    testWidgets('play/pausa y posición no repiten lecturas y el estado se '
        'mantiene', (tester) async {
      final artwork = await open(tester);
      final before = artwork.requests.length;
      final bytes = memoryImageOf(artworkOf(tester).image!).bytes;

      player.emitState(
        PlaybackState(queue: [song], currentIndex: 0, isPlaying: true),
      );
      await tester.pumpAndSettle();
      expect(find.byTooltip('Pausar'), findsOneWidget);
      for (var s = 1; s <= 3; s++) {
        player.emitPosition(Duration(seconds: s));
        await tester.pump();
      }

      player.emitState(PlaybackState(queue: [song], currentIndex: 0));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Reproducir'), findsOneWidget);

      expect(artwork.requests.length, before);
      expect(
        identical(memoryImageOf(artworkOf(tester).image!).bytes, bytes),
        isTrue,
      );
    });
  });
}

/// Carátulas de prueba: bytes con el álbum pedido; cuenta las peticiones. Con
/// [missing] el álbum no tiene carátula, con [empty] los bytes salen vacíos y
/// con [failing] la lectura falla.
class _BytesArtworkRepository implements ArtworkRepository {
  final requests = <(int, int)>[];
  final missing = <int>{};
  final empty = <int>{};
  final failing = <int>{};

  @override
  Future<Uint8List?> getAlbumArtwork(int albumId, {required int size}) async {
    requests.add((albumId, size));
    if (failing.contains(albumId)) throw StateError('lectura fallida');
    if (missing.contains(albumId)) return null;
    if (empty.contains(albumId)) return Uint8List(0);
    return Uint8List.fromList([albumId, size]);
  }
}
