import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/catalog/catalog_sources_providers.dart';
import '../features/library/presentation/pages/favorites_page.dart';
import '../features/library/presentation/pages/library_page.dart';
import '../features/player/presentation/pages/now_playing_page.dart';
import '../features/player/presentation/pages/queue_page.dart';
import '../features/player/presentation/widgets/mini_player.dart';
import '../features/playlists/presentation/pages/playlist_detail_page.dart';
import '../features/playlists/presentation/pages/playlists_page.dart';
import '../features/search/presentation/pages/search_page.dart';
import '../features/settings/presentation/pages/settings_page.dart';
import 'widgets/song_actions_sheet.dart';

abstract final class AppRoutes {
  static const String library = '/library';
  static const String search = '/search';
  static const String playlists = '/playlists';
  static String playlistDetail(int id) => '/playlists/$id';
  static const String favorites = '/favorites';
  static const String settings = '/settings';

  // Pantallas completas, fuera del shell (sin barra inferior).
  static const String nowPlaying = '/now-playing';
  static const String queue = '/queue';
}

final routerProvider = Provider<GoRouter>((ref) {
  // «Buscar» solo existe si hay algún catálogo; es una propiedad de la build
  // (credenciales), no cambia mientras la app corre.
  final hasSearch = ref.read(catalogSourcesProvider).isAvailable;
  final router = GoRouter(
    initialLocation: AppRoutes.library,
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell, hasSearch: hasSearch),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.library,
                builder: (context, state) =>
                    const LibraryPage(onSongActions: showSongActions),
              ),
            ],
          ),
          // Las ramas van en el mismo orden que los destinos de [AppShell].
          if (hasSearch)
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: AppRoutes.search,
                  builder: (context, state) =>
                      const SearchPage(onSongActions: showSongActions),
                ),
              ],
            ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.playlists,
                builder: (context, state) => PlaylistsPage(
                  onOpenPlaylist: (id) =>
                      context.push(AppRoutes.playlistDetail(id)),
                ),
                routes: [
                  // Dentro de la pestaña: conserva mini player y barra.
                  GoRoute(
                    path: ':id',
                    builder: (context, state) => PlaylistDetailPage(
                      playlistId:
                          int.tryParse(state.pathParameters['id'] ?? '') ?? -1,
                      onSongActions: showSongActions,
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.favorites,
                builder: (context, state) =>
                    const FavoritesPage(onSongActions: showSongActions),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.settings,
                builder: (context, state) => const SettingsPage(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.nowPlaying,
        pageBuilder: (context, state) => _slideUpPage(
          state,
          NowPlayingPage(
            onOpenQueue: () => context.push(AppRoutes.queue),
          ),
        ),
      ),
      GoRoute(
        path: AppRoutes.queue,
        pageBuilder: (context, state) =>
            _slideUpPage(state, const QueuePage()),
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});

/// Página a pantalla completa que sube desde abajo.
CustomTransitionPage<void> _slideUpPage(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 320),
    reverseTransitionDuration: const Duration(milliseconds: 260),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return SlideTransition(
        position: Tween(
          begin: const Offset(0, 1),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      );
    },
  );
}

/// Shell con barra de navegación inferior; conserva el estado de cada pestaña.
class AppShell extends StatelessWidget {
  const AppShell({
    super.key,
    required this.navigationShell,
    required this.hasSearch,
  });

  final StatefulNavigationShell navigationShell;

  /// Añade el destino «Buscar» (entre Biblioteca y Playlists). Debe coincidir
  /// con las ramas del router: el índice del destino es el de la rama.
  final bool hasSearch;

  void _onDestinationSelected(int index) {
    navigationShell.goBranch(
      index,
      // Volver a tocar la pestaña activa regresa a su ruta raíz.
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          MiniPlayer(onOpen: () => context.push(AppRoutes.nowPlaying)),
          NavigationBar(
            selectedIndex: navigationShell.currentIndex,
            onDestinationSelected: _onDestinationSelected,
            destinations: [
              const NavigationDestination(
                icon: Icon(Icons.library_music_outlined),
                selectedIcon: Icon(Icons.library_music),
                label: LibraryPage.title,
              ),
              if (hasSearch)
                const NavigationDestination(
                  icon: Icon(Icons.search_rounded),
                  label: SearchPage.title,
                ),
              const NavigationDestination(
                icon: Icon(Icons.queue_music_outlined),
                selectedIcon: Icon(Icons.queue_music),
                label: PlaylistsPage.title,
              ),
              const NavigationDestination(
                icon: Icon(Icons.favorite_outline),
                selectedIcon: Icon(Icons.favorite),
                label: FavoritesPage.title,
              ),
              const NavigationDestination(
                icon: Icon(Icons.settings_outlined),
                selectedIcon: Icon(Icons.settings),
                label: SettingsPage.title,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
