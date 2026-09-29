import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:taki/app/theme/app_theme.dart';
import 'package:taki/app/widgets/song_actions_sheet.dart';
import 'package:taki/core/domain/entities/song.dart';
import 'package:taki/features/library/presentation/pages/library_page.dart';
import 'package:taki/features/player/domain/entities/playback_state.dart';
import 'package:taki/features/player/presentation/providers/player_providers.dart';

import '../../../helpers/favorites_fakes.dart';
import '../../../helpers/library_fakes.dart';
import '../../../helpers/player_fakes.dart';
import '../../../helpers/playlists_fakes.dart';

void main() {
  late MockMediaPermission permission;
  late MockSongRepository songs;
  late FakeAudioPlayerPort player;
  late FakeNotificationPermission notifications;
  late MockPlaySongs playSongs;
  late MockPlayNext playNext;
  late MockAddToQueue addToQueue;
  late FakeFavoritesRepository favorites;
  late FakePlaylistsRepository playlists;

  setUpAll(() {
    registerFallbackValue(<Song>[]);
  });

  setUp(() {
    permission = MockMediaPermission();
    songs = MockSongRepository();
    player = FakeAudioPlayerPort();
    notifications = FakeNotificationPermission();
    playSongs = MockPlaySongs();
    when(() => playSongs(any(), any())).thenAnswer((_) async {});
    playNext = MockPlayNext();
    when(() => playNext(any())).thenAnswer((_) async {});
    favorites = FakeFavoritesRepository();
    playlists = FakePlaylistsRepository();
    addToQueue = MockAddToQueue();
    when(() => addToQueue(any())).thenAnswer((_) async {});
    when(permission.isGranted).thenAnswer((_) async => true);
    when(permission.isPermanentlyDenied).thenAnswer((_) async => false);
    when(songs.getSongs).thenAnswer((_) async => []);
  });

  Future<void> pumpPage(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...libraryOverrides(
            permission: permission,
            songs: songs,
            player: player,
            notifications: notifications,
            favorites: favorites,
            playlists: playlists,
          ),
          playSongsProvider.overrideWithValue(playSongs),
          playNextProvider.overrideWithValue(playNext),
          addToQueueProvider.overrideWithValue(addToQueue),
        ],
        child: MaterialApp(theme: AppTheme.dark(), home: const LibraryPage(onSongActions: showSongActions)),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('sin permiso', () {
    setUp(() => when(permission.isGranted).thenAnswer((_) async => false));

    testWidgets('muestra el mensaje y "Permitir acceso"', (tester) async {
      when(permission.request).thenAnswer((_) async => false);

      await pumpPage(tester);

      expect(find.text('Taki necesita acceso a tu música'), findsOneWidget);
      await tester.tap(find.text('Permitir acceso'));
      await tester.pumpAndSettle();

      verify(permission.request).called(1);
      verifyNever(songs.getSongs);
    });

    testWidgets('si se concede, carga las canciones', (tester) async {
      when(permission.request).thenAnswer((_) async {
        when(permission.isGranted).thenAnswer((_) async => true);
        return true;
      });
      when(songs.getSongs).thenAnswer((_) async => [buildSong(title: 'Hola')]);

      await pumpPage(tester);
      await tester.tap(find.text('Permitir acceso'));
      await tester.pumpAndSettle();

      expect(find.text('Hola'), findsOneWidget);
    });

    testWidgets('denegado permanentemente: el botón abre los ajustes',
        (tester) async {
      when(permission.isPermanentlyDenied).thenAnswer((_) async => true);
      when(permission.openSettings).thenAnswer((_) async => true);

      await pumpPage(tester);
      await tester.tap(find.text('Abrir ajustes'));
      await tester.pumpAndSettle();

      verify(permission.openSettings).called(1);
      verifyNever(permission.request);
    });
  });

  testWidgets('vacío: muestra el mensaje y "Reintentar"', (tester) async {
    await pumpPage(tester);

    expect(find.text('No encontramos canciones'), findsOneWidget);
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();

    verify(songs.getSongs).called(2);
  });

  testWidgets('error: muestra el mensaje y "Reintentar"', (tester) async {
    when(songs.getSongs).thenThrow(Exception('MediaStore no disponible'));

    await pumpPage(tester);

    expect(find.text('No pudimos leer tu música'), findsOneWidget);
    expect(find.text('Reintentar'), findsOneWidget);
  });

  testWidgets('con datos: encabezado, filas ordenadas y duraciones',
      (tester) async {
    when(songs.getSongs).thenAnswer(
      (_) async => [
        buildSong(id: 1, title: 'zeta', artist: null, durationMs: 125000),
        buildSong(id: 2, title: 'Alfa', durationMs: 185000),
        buildSong(id: 3, title: 'Tono', durationMs: 4000), // Se descarta.
      ],
    );

    await pumpPage(tester);

    expect(find.text('Tu música'), findsOneWidget);
    expect(find.text('2 canciones · 5 min'), findsOneWidget);
    expect(find.text('Tono'), findsNothing);
    expect(find.text('Artista desconocido'), findsOneWidget);
    expect(find.text('3:05'), findsOneWidget);
    expect(find.text('2:05'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Alfa')).dy,
      lessThan(tester.getTopLeft(find.text('zeta')).dy),
    );
    // Sin carátula se ve el ícono de nota.
    expect(find.byIcon(Icons.music_note_rounded), findsNWidgets(2));
  });

  testWidgets('pull-to-refresh vuelve a escanear', (tester) async {
    when(songs.getSongs).thenAnswer((_) async => [buildSong(title: 'Una')]);

    await pumpPage(tester);
    await tester.fling(find.text('Una'), const Offset(0, 400), 1000);
    await tester.pumpAndSettle();

    verify(songs.getSongs).called(2);
  });

  group('reproducción', () {
    final unsorted = [
      buildSong(id: 1, title: 'zeta'),
      buildSong(id: 2, title: 'Alfa'),
      buildSong(id: 3, title: 'medio'),
    ];

    testWidgets(
        'tocar una canción llama a PlaySongs con la lista visible y su índice',
        (tester) async {
      when(songs.getSongs).thenAnswer((_) async => unsorted);

      await pumpPage(tester);
      await tester.tap(find.text('medio'));
      await tester.pumpAndSettle();

      final captured =
          verify(() => playSongs(captureAny(), captureAny())).captured;
      final queue = captured[0] as List<Song>;
      expect(queue.map((s) => s.title), ['Alfa', 'medio', 'zeta']);
      expect(captured[1], 1);
      expect(notifications.requests, 1);
    });

    testWidgets('la canción actual se marca con el color de acento',
        (tester) async {
      when(songs.getSongs).thenAnswer((_) async => unsorted);

      await pumpPage(tester);
      final sorted = [unsorted[1], unsorted[2], unsorted[0]];
      player.emitState(PlaybackState(queue: sorted, currentIndex: 2));
      await tester.pumpAndSettle();

      Color? titleColor(String title) =>
          tester.widget<Text>(find.text(title)).style?.color;
      final accent = Theme.of(tester.element(find.text('zeta')))
          .colorScheme
          .primary;

      expect(titleColor('zeta'), accent);
      expect(titleColor('Alfa'), isNot(accent));
    });
  });

  group('mantener pulsada una canción', () {
    final songsList = [
      buildSong(id: 1, title: 'Alfa'),
      buildSong(id: 2, title: 'Beta'),
    ];

    Future<void> openSheetFor(WidgetTester tester, String title) async {
      when(songs.getSongs).thenAnswer((_) async => songsList);
      await pumpPage(tester);
      await tester.longPress(find.text(title));
      await tester.pumpAndSettle();
    }

    testWidgets('ofrece las dos opciones', (tester) async {
      await openSheetFor(tester, 'Beta');

      expect(find.text('Reproducir a continuación'), findsOneWidget);
      expect(find.text('Añadir a la cola'), findsOneWidget);
    });

    testWidgets('"Reproducir a continuación" llama a PlayNext con la canción',
        (tester) async {
      player.emitState(
        PlaybackState(queue: [songsList.first], currentIndex: 0),
      );
      await openSheetFor(tester, 'Beta');

      await tester.tap(find.text('Reproducir a continuación'));
      await tester.pumpAndSettle();

      verify(() => playNext([songsList[1]])).called(1);
      verifyNever(() => addToQueue(any()));
      expect(find.text('Sonará a continuación'), findsOneWidget);
    });

    testWidgets('"Añadir a la cola" llama a AddToQueue con la canción',
        (tester) async {
      player.emitState(
        PlaybackState(queue: [songsList.first], currentIndex: 0),
      );
      await openSheetFor(tester, 'Beta');

      await tester.tap(find.text('Añadir a la cola'));
      await tester.pumpAndSettle();

      verify(() => addToQueue([songsList[1]])).called(1);
      verifyNever(() => playNext(any()));
      expect(find.text('Añadida a la cola'), findsOneWidget);
    });

    testWidgets('ofrece "Añadir a favoritos" y la marca', (tester) async {
      await openSheetFor(tester, 'Beta');

      await tester.tap(find.text('Añadir a favoritos'));
      await tester.pumpAndSettle();

      expect(favorites.entries.keys, [2]);
      expect(find.text('Añadida a favoritos'), findsOneWidget);
    });

    testWidgets('si ya es favorita ofrece "Quitar de favoritos"',
        (tester) async {
      favorites.seed(favorites.entryFor(songsList[1]));
      await openSheetFor(tester, 'Beta');

      expect(find.text('Quitar de favoritos'), findsOneWidget);
      expect(find.text('Añadir a favoritos'), findsNothing);

      await tester.tap(find.text('Quitar de favoritos'));
      await tester.pumpAndSettle();

      expect(favorites.entries, isEmpty);
      expect(find.text('Quitada de favoritos'), findsOneWidget);
    });

    testWidgets('"Añadir a una playlist" añade y avisa si ya estaba',
        (tester) async {
      final mix = playlists.seed('Mix');
      await openSheetFor(tester, 'Beta');

      await tester.tap(find.text('Añadir a una playlist'));
      await tester.pumpAndSettle();
      expect(find.text('Nueva playlist'), findsOneWidget);
      await tester.tap(find.text('Mix'));
      await tester.pumpAndSettle();

      expect(playlists.entriesOf(mix).map((e) => e.songId), [2]);
      expect(find.text('Añadida a «Mix»'), findsOneWidget);

      await tester.longPress(find.text('Beta'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Añadir a una playlist'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mix'));
      await tester.pumpAndSettle();

      expect(playlists.entriesOf(mix).map((e) => e.songId), [2, 2]);
      expect(
        find.text('Ya estaba en «Mix»; se añadió otra vez'),
        findsOneWidget,
      );
    });

    testWidgets('"Nueva playlist" desde el selector la crea con la canción',
        (tester) async {
      await openSheetFor(tester, 'Alfa');

      await tester.tap(find.text('Añadir a una playlist'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Nueva playlist'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Recién hecha');
      await tester.pump();
      await tester.tap(find.text('Crear'));
      await tester.pumpAndSettle();

      expect(playlists.namesInOrder(), ['Recién hecha']);
      expect(find.text('Añadida a «Recién hecha»'), findsOneWidget);
    });

    testWidgets('sin nada sonando, avisa que empieza a reproducir',
        (tester) async {
      await openSheetFor(tester, 'Alfa');

      await tester.tap(find.text('Añadir a la cola'));
      await tester.pumpAndSettle();

      verify(() => addToQueue([songsList[0]])).called(1);
      expect(find.text('Reproduciendo «Alfa»'), findsOneWidget);
      expect(notifications.requests, 1);
    });
  });
}
