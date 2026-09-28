import 'package:flutter/material.dart';

import '../../../../core/widgets/placeholder_page.dart';

class FavoritesPage extends StatelessWidget {
  const FavoritesPage({super.key});

  static const String title = 'Favoritos';

  @override
  Widget build(BuildContext context) {
    return const PlaceholderPage(
      title: title,
      icon: Icons.favorite_outline,
    );
  }
}
