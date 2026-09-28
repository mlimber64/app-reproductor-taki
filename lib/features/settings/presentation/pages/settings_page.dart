import 'package:flutter/material.dart';

import '../../../../core/widgets/placeholder_page.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  static const String title = 'Ajustes';

  @override
  Widget build(BuildContext context) {
    return const PlaceholderPage(
      title: title,
      icon: Icons.settings_outlined,
    );
  }
}
