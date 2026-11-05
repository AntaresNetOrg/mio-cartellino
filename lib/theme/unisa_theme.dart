import 'package:flutter/material.dart';

/// Colors read from the computed styles of www.unisa.it (2026-11-05).
abstract final class UnisaColors {
  /// Navbar, bottom menu, btn-primary, badges.
  static const primary = Color(0xFF2F577F);

  /// Mobile drawer.
  static const primaryLight = Color(0xFF325D88);

  /// Main link color.
  static const primaryDark = Color(0xFF244363);

  /// Secondary links.
  static const link = Color(0xFF377193);

  /// Highlighted column blocks. ~4.6:1 with white text: buttons/icons only,
  /// not small text.
  static const accent = Color(0xFF0D7FA4);

  static const text = Color(0xFF212121);
  static const surfaceAlt = Color(0xFFF7F7F7);
  static const footer = Color(0xFF333333);

  // Balance colors (green/red/blue as in the desktop dashboard; not from unisa.it).
  static const positive = Color(0xFF2E7D32);
  static const negative = Color(0xFFC62828);
  static const neutral = primary;

  static const warning = Color(0xFFB26A00);
}

ThemeData buildUnisaTheme(Brightness brightness) {
  final seeded = ColorScheme.fromSeed(
    seedColor: UnisaColors.primary,
    brightness: brightness,
  );
  final scheme = brightness == Brightness.light
      ? seeded.copyWith(
          primary: UnisaColors.primary,
          secondary: UnisaColors.accent,
          tertiary: UnisaColors.primaryDark,
        )
      : seeded;
  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    // TODO: bundle Titillium Web (OFL, Google Fonts) under assets/fonts and
    // set fontFamily here — it is the font used by unisa.it.
    appBarTheme: const AppBarTheme(
      backgroundColor: UnisaColors.primary,
      foregroundColor: Colors.white,
    ),
  );
}
