import 'package:flutter/material.dart';

abstract final class VirilTheme {
  static const background = Color(0xFF0B0D15);
  static const panel = Color(0xFF171B2A);
  static const blue = Color(0xFF8BDcff);
  static const violet = Color(0xFFB5A0FF);
  static const green = Color(0xFF8BE8BD);

  static ThemeData get dark {
    final scheme = ColorScheme.fromSeed(
      seedColor: blue,
      brightness: Brightness.dark,
      surface: panel,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      colorScheme: scheme,
      fontFamily: 'Roboto',
      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: panel.withValues(alpha: .88),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(color: Colors.white.withValues(alpha: .08)),
        ),
      ),
    );
  }
}
