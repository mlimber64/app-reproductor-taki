import 'package:flutter/painting.dart';

/// Paleta "Medianoche + ámbar" de Taki.
abstract final class AppColors {
  // Superficies
  static const Color background = Color(0xFF111318);
  static const Color surface = Color(0xFF1B1E26);
  static const Color surfaceElevated = Color(0xFF1F232D);
  static const Color border = Color(0xFF2A2E39);

  // Texto
  static const Color textPrimary = Color(0xFFF2F0EB);
  static const Color textSecondary = Color(0xFFA3A6B0);

  // Acento principal
  static const Color accent = Color(0xFFF5A524);

  // Acentos alternativos
  static const Color accentCoral = Color(0xFFFF7A59);
  static const Color accentBlue = Color(0xFF7C9CFF);
  static const Color accentMint = Color(0xFF3DD6B0);

  /// Color de contenido sobre el acento (ámbar claro → texto oscuro).
  static const Color onAccent = background;
}
