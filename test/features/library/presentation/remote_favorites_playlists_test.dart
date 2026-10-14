import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:taki/app/theme/app_theme.dart';
import 'package:taki/app/widgets/song_actions_sheet.dart';
import 'package:taki/core/domain/entities/local_music_identity.dart';
import 'package:taki/core/domain/entities/music_identity.dart';
import 'package:taki/core/domain/entities/song.dart';
import 'package:taki/core/domain/services/source_song_lookup.dart';
import 'package:taki/core/lookup/song_lookup_providers.dart';
import 'package:taki/core/widgets/taki_error_state.dart';
import 'package:taki/features/library/domain/services/local_song_lookup.dart';
import 'package:taki/features/library/presentation/pages/favorites_page.dart';
import 'package:taki/features/library/presentation/providers/songs_notifier.dart';
import 'package:taki/features/player/presentation/providers/player_providers.dart';
import 'package:taki/features/playlists/presentation/pages/playlist_detail_page.dart';

import '../../../helpers/favorites_fakes.dart';
import '../../../helpers/library_fakes.dart';
import '../../../helpers/player_fakes.dart';
import '../../../helpers/playlists_fakes.dart';
import '../../../helpers/song_lookup_fakes.dart';
import '../../../helpers/universal_song.dart';

/// Fase 3.4: Favoritos y detalle de playlist resuelven canciones de **otras
/// fuentes** sin depender del permiso ni del estado de la biblioteca local.
/// «jamendo» es solo la etiqueta de fuente de una fuente de prueba.
void main() {
  final local = buildSong(id: 42, title: 'Local 42');
  final remote = buildUniversalSong(
    MusicIdentity('jamendo', '123'),
    title: 'Remota 123',
  );
  final remote0042 = buildUniversalSong(
    MusicIdentity('jamendo', '0042'),
    title: 'Remota 0042',
  );

  late MockMediaPermission permission;
  late MockSongRepository library;
  late FakeFavoritesRepository favorites;
  late FakePlaylistsRepository playlists;
  late FakeSourceLookup remoteLookup;
  late MockPlaySongs playSongs;

  setUpAll(() => registerFallbackValue(<Song>[]));

  setUp(() {
    permission = MockMediaPermission();
    when(permission.isGranted).thenAnswer((_) async => true);
    when(permission.isPermanentlyDenied).thenAnswer((_) async => false);
    library = MockSongRepository();
    when(library.getSongs).thenAnswer((_) async => [local]);
    favorites = FakeFavoritesRepository();
    playlists = FakePlaylistsRepository();
    remoteLookup = FakeSourceLookup([remote, remote0042]);
    playSongs = MockPlaySongs();
    when(() => playSongs(any(), any())).thenAnswer((_) async {});
  });

  Future<void> pump(WidgetTester tester, Widget page) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...libraryOverrides(
            permission: permission,
            songs: library,
            favorites: favorites,
            playlists: playlists,
          ),
          // Mismo cableado que `buildSongLookup` (local + otra fuente), con la
          // fuente remota de prueba.
          songLookupProvider.overrideWith(
            (ref) => SourceSongLookup({
              localMusicSource: LocalSongLookup(() async {
                final state = await ref.read(songsProvider.future);
                return state is LibraryLoaded ? state.songs : const [];
              }),
              'jamendo': remoteLookup,
            }),
          ),
          playSongsProvider.overrideWithValue(playSongs),
        ],
        child: MaterialApp(theme: AppTheme.dark(), home: page),
      ),
    );
    await tester.pumpAndSettle();
  }

  const favoritesPage = FavoritesPage(onSongActions: showSongActions);

  void permissionDenied() =>
      when(permission.isGranted).thenAnswer((_) async => false);

  bool showsPermission(WidgetTester tester) => tester
      .widgetList<TakiErrorState>(find.byType(TakiErrorState))
      .any((s) => s.kind == TakiErrorStateKind.permission);

  group('Favoritos', () {
    test('(sanidad) las identidades de prueba son distintas', () {
      expect(localMusicIdentity(42) == MusicIdentity('jamendo', '42'), isFalse);
      expect(
        MusicIdentity('jamendo', '42') == MusicIdentity('jamendo', '0042'),
        isFalse,
      );
    });

    testWidgets('A: jamendo:123 sin permiso de música se muestra y se '
        'reproduce', (tester) async {
      permissionDenied();
      await favorites.add(remote);
      await pump(tester, favoritesPage);

      expect(showsPermission(tester), isFalse);
      expect(find.text('Remota 123'), findsOneWidget);

      await tester.tap(find.text('Remota 123'));
      await tester.pump();
      final captured =
          verify(() => playSongs(captureAny(), captureAny())).captured;
      expect((captured[0] as List<Song>).single, remote);
      expect(captured[1], 0);
    });

    testWidgets('C: mixtos con permiso: local y remota', (tester) async {
      await favorites.add(local);
      await favorites.add(remote);
      await pump(tester, favoritesPage);

      expect(find.text('Local 42'), findsOneWidget);
      expect(find.text('Remota 123'), findsOneWidget);
      expect(showsPermission(tester), isFalse);
    });

    testWidgets('D: mixtos sin permiso: la remota se muestra y la local no '
        '(regla de la fuente local), sin borrar nada', (tester) async {
      permissionDenied();
      await favorites.add(local);
      await favorites.add(remote);
      await pump(tester, favoritesPage);

      expect(find.text('Remota 123'), findsOneWidget);
      expect(find.text('Local 42'), findsNothing);
      expect(showsPermission(tester), isFalse);
      expect(favorites.entries.keys,
          {localMusicIdentity(42), MusicIdentity('jamendo', '123')});
    });

    testWidgets('el reencuentro local sigue funcionando con la biblioteca '
        '(id viejo → misma canción, se relinka)', (tester) async {
      favorites.seed(
        favorites.entryFor(local, identity: localMusicIdentity(7)),
      );
      await pump(tester, favoritesPage);

      expect(find.text('Local 42'), findsOneWidget);
      expect(favorites.relinks, [(localMusicIdentity(7), local.musicIdentity)]);
    });

    testWidgets('sin permiso y solo favoritos locales: se pide el permiso '
        '(como antes)', (tester) async {
      permissionDenied();
      await favorites.add(local);
      await pump(tester, favoritesPage);

      expect(showsPermission(tester), isTrue);
      expect(find.text('Permitir acceso'), findsOneWidget);
    });

    testWidgets('E: la fuente remota falla: se muestra la local y no se '
        'borra la remota', (tester) async {
      remoteLookup.failure = StateError('sin red');
      await favorites.add(local);
      await favorites.add(remote);
      await pump(tester, favoritesPage);

      expect(find.text('Local 42'), findsOneWidget);
      expect(find.text('Remota 123'), findsNothing);
      expect(find.text('Favoritos no disponibles'), findsNothing);
      expect(favorites.entries, hasLength(2));
      expect(favorites.relinks, isEmpty);
    });

    testWidgets('F: la biblioteca local falla: se muestra la remota',
        (tester) async {
      when(library.getSongs).thenAnswer((_) async => throw StateError('x'));
      await favorites.add(local);
      await favorites.add(remote);
      await pump(tester, favoritesPage);

      expect(find.text('Remota 123'), findsOneWidget);
      expect(find.text('Local 42'), findsNothing);
      expect(find.text('Favoritos no disponibles'), findsNothing);
    });

    testWidgets('fallan todas las fuentes: estado de error existente',
        (tester) async {
      remoteLookup.failure = StateError('sin red');
      await favorites.add(remote);
      await pump(tester, favoritesPage);

      expect(find.text('Favoritos no disponibles'), findsOneWidget);
      expect(favorites.entries, hasLength(1));
    });

    testWidgets('H: la identidad persistida no cambia (0042 ≠ 42)',
        (tester) async {
      permissionDenied();
      await favorites.add(remote0042);
      await pump(tester, favoritesPage);

      expect(find.text('Remota 0042'), findsOneWidget);
      expect(favorites.entries.keys.single, MusicIdentity('jamendo', '0042'));
      expect(favorites.relinks, isEmpty);
      expect(
        remoteLookup.requests.single,
        {MusicIdentity('jamendo', '0042')},
      );
    });
  });

  group('Detalle de playlist', () {
    Widget detail(int id) =>
        PlaylistDetailPage(playlistId: id, onSongActions: showSongActions);

    testWidgets('B: jamendo:123 sin permiso de música se muestra y se '
        'reproduce', (tester) async {
      permissionDenied();
      final id = playlists.seed('Mix', songs: [remote]);
      await pump(tester, detail(id));

      expect(showsPermission(tester), isFalse);
      expect(find.text('Remota 123'), findsOneWidget);

      await tester.tap(find.text('Remota 123'));
      await tester.pump();
      final captured =
          verify(() => playSongs(captureAny(), captureAny())).captured;
      expect((captured[0] as List<Song>).single, remote);
    });

    testWidgets('C: mixtas con permiso, con orden y duplicados',
        (tester) async {
      final id = playlists.seed('Mix', songs: [remote, local, remote]);
      await pump(tester, detail(id));

      expect(find.text('Remota 123'), findsNWidgets(2));
      expect(find.text('Local 42'), findsOneWidget);
      final order = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data)
          .where((t) => t == 'Remota 123' || t == 'Local 42')
          .toList();
      expect(order, ['Remota 123', 'Local 42', 'Remota 123']);
      expect(playlists.entriesOf(id).map((e) => e.position), [0, 1, 2]);
    });

    testWidgets('D: mixtas sin permiso: la remota (y su duplicado) se '
        'muestran, la local no, y nada se borra', (tester) async {
      permissionDenied();
      final id = playlists.seed('Mix', songs: [remote, local, remote]);
      await pump(tester, detail(id));

      expect(showsPermission(tester), isFalse);
      expect(find.text('Remota 123'), findsNWidgets(2));
      expect(find.text('Local 42'), findsNothing);
      expect(playlists.entriesOf(id), hasLength(3));
    });

    testWidgets('sin permiso y solo locales: se pide el permiso (como antes)',
        (tester) async {
      permissionDenied();
      final id = playlists.seed('Mix', songs: [local]);
      await pump(tester, detail(id));

      expect(showsPermission(tester), isTrue);
    });

    testWidgets('E: la fuente remota falla: se muestra la local',
        (tester) async {
      remoteLookup.failure = StateError('sin red');
      final id = playlists.seed('Mix', songs: [remote, local]);
      await pump(tester, detail(id));

      expect(find.text('Local 42'), findsOneWidget);
      expect(find.text('Remota 123'), findsNothing);
      expect(find.text('Playlist no disponible'), findsNothing);
      expect(playlists.entriesOf(id), hasLength(2));
    });

    testWidgets('F: la biblioteca local falla: se muestra la remota',
        (tester) async {
      when(library.getSongs).thenAnswer((_) async => throw StateError('x'));
      final id = playlists.seed('Mix', songs: [local, remote]);
      await pump(tester, detail(id));

      expect(find.text('Remota 123'), findsOneWidget);
      expect(find.text('Playlist no disponible'), findsNothing);
    });

    testWidgets('H: la identidad de la entrada no cambia', (tester) async {
      permissionDenied();
      final id = playlists.seed('Mix', songs: [remote0042]);
      await pump(tester, detail(id));

      expect(find.text('Remota 0042'), findsOneWidget);
      expect(playlists.entriesOf(id).single.musicIdentity,
          MusicIdentity('jamendo', '0042'));
      expect(playlists.relinks, isEmpty);
    });
  });
}
