import 'package:flutter/material.dart';

import '../../../../core/widgets/placeholder_page.dart';

class LibraryPage extends StatelessWidget {
  const LibraryPage({super.key});

  static const String title = 'Biblioteca';

  @override
  Widget build(BuildContext context) {
    return const PlaceholderPage(
      title: title,
      icon: Icons.library_music_outlined,
    );
  }
}
