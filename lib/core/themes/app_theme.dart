import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const Color primary = Color(0xFFE07B39);
  static const Color secondary = Color(0xFFF5E6C8);
  static const Color background = Color(0xFF3E2723);
  static const Color surface = Color(0xFF5D4037);
  static const Color textLight = Color(0xFFF5E6C8);
  static const Color textDark = Color(0xFF3E2723);
  static const Color accent = Color(0xFFFFB74D);

  static ThemeData get theme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.dark(
        primary: primary,
        secondary: secondary,
        background: background,
        surface: surface,
      ),
      scaffoldBackgroundColor: background,
      textTheme: GoogleFonts.poppinsTextTheme().apply(
        bodyColor: textLight,
        displayColor: textLight,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: textLight,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: textLight,
        centerTitle: true,
        titleTextStyle: GoogleFonts.poppins(
          color: textLight,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}