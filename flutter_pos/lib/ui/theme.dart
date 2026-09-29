import 'package:flutter/material.dart';

class CommuneTheme {
  static const Color primary = Color(0xFF111111);
  static const Color accent = Color(0xFFD4AF37); // subtle warm gold/amber
  static const Color background = Color(0xFFF7F7F8);
  static const Color surface = Colors.white;
  static const Color border = Color(0xFFE5E5E5);
  static const Color textMain = Color(0xFF1A1A1A);
  static const Color textMuted = Color(0xFF737373);
  static const Color statusOnline = Color(0xFF16A34A);
  static const Color statusOffline = Color(0xFFD97706);
  static const Color statusSyncing = Color(0xFF2563EB);
  static const Color voidRed = Color(0xFFDC2626);

  static ThemeData get theme => ThemeData(
    useMaterial3: true,
    fontFamily: 'Inter',
    scaffoldBackgroundColor: background,
    colorScheme: const ColorScheme.light(
      primary: primary,
      secondary: accent,
      surface: surface,
      onPrimary: Colors.white,
      onSurface: textMain,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: surface,
      elevation: 0,
      scrolledUnderElevation: 0,
      iconTheme: IconThemeData(color: textMain),
      titleTextStyle: TextStyle(
        color: textMain,
        fontSize: 16,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.3,
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: border,
      thickness: 1,
      space: 1,
    ),
  );
}
