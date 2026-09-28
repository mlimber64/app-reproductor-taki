import 'package:flutter/material.dart';

import '../../../../core/widgets/placeholder_page.dart';

class PlaylistsPage extends StatelessWidget {
  const PlaylistsPage({super.key});

  static const String title = 'Playlists';

  @override
  Widget build(BuildContext context) {
    return const PlaceholderPage(
      title: title,
      icon: Icons.queue_music_outlined,
    );
  }
}
