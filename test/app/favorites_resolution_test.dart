import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:taki/app/app.dart';
import 'package:taki/features/library/domain/entities/favorite_entry.dart';
import 'package:taki/features/player/domain/entities/playback_state.dart';
import 'package:taki/core/domain/entities/local_music_identity.dart';

import '../helpers/favorites_fakes.dart';
import '../helpers/library_fakes.dart';
import '../helpers/player_fakes.dart';

void main() {
  testWidgets(
      'un favorito cuyo id cambió se reencuentra al cargar la biblioteca, '
      'sin abrir la pestaña Favoritos', (tester) async {
    // Tras un reescaneo la canción pasó del id 5 al 50 (misma ruta).
    final song = buildSong(id: 50, title: 'Reencontrada');
    final favorites = FakeFavoritesRepository()
      ..seed(FavoriteEntry(
        musicIdentity: localMusicIdentity(5),
        addedAt: DateTime(2026, 9, 1),
        title: 'Reencontrada',
        path: song.path,
      ));
    final player = FakeAudioPlayerPort()
      ..emitState(PlaybackState(queue: [song], currentIndex: 0));
    final permission = MockMediaPermission();
    when(permission.isGranted).thenAnswer((_) async => true);
    final library = MockSongRepository();
    when(library.getSongs).thenAnswer((_) async => [song]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: libraryOverrides(
          permission: permission,
          songs: library,
          player: player,
          favorites: favorites,
        ),
        child: const TakiApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(favorites.relinks, [(localMusicIdentity(5), localMusicIdentity(50))]);

    // Abrir Reproduciendo desde el mini player: el corazón ya está marcado.
    await tester.tap(
      find.descendant(
        of: find.byType(Material),
        matching: find.text('Reencontrada'),
      ).last,
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip('Quitar de favoritos'), findsOneWidget);
  });
}
