import 'package:flutter/material.dart';

class JVTheme {
  const JVTheme._();

  static const Color primary = Color(0xFF4F46E5);
  static const Color success = Color(0xFF059669);
  static const Color warning = Color(0xFFD97706);
  static const Color ink = Color(0xFF111827);
  static const Color muted = Color(0xFF6B7280);
  static const Color background = Color(0xFFF6F7FB);
  static const Color surface = Colors.white;
  static const Color border = Color(0xFFE5E7EB);

  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        brightness: Brightness.light,
        primary: primary,
        secondary: success,
        tertiary: warning,
      ),
      fontFamily: 'Roboto',
      scaffoldBackgroundColor: background,
      appBarTheme: const AppBarTheme(
        backgroundColor: surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        foregroundColor: ink,
        surfaceTintColor: surface,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: surface,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: border),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: const Color(0xFFF9FAFB),
        selectedColor: const Color(0xFFEDEBFF),
        side: const BorderSide(color: border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        labelStyle: const TextStyle(color: ink, fontWeight: FontWeight.w600),
      ),
      dataTableTheme: DataTableThemeData(
        headingRowColor: MaterialStateProperty.all(const Color(0xFFF8FAFC)),
        headingTextStyle: const TextStyle(
          color: Color(0xFF1F2937),
          fontWeight: FontWeight.w800,
        ),
        dataTextStyle: const TextStyle(color: Color(0xFF374151)),
        dividerThickness: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFD8DDEA)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFD8DDEA)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primary, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: const BorderSide(color: border),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      navigationRailTheme: const NavigationRailThemeData(
        backgroundColor: surface,
        indicatorColor: Color(0xFFEDEBFF),
        selectedIconTheme: IconThemeData(color: primary),
        selectedLabelTextStyle: TextStyle(
          color: ink,
          fontWeight: FontWeight.w800,
        ),
        unselectedLabelTextStyle: TextStyle(color: muted),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}
