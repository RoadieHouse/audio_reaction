import 'package:flutter/material.dart';

/// Centralized theme definition for Sprint React.
/// All widgets reference Theme.of(context) — no hardcoded colors.
abstract class AppTheme {
  // ── Design Tokens ──────────────────────────────────────────────────────────
  static const Color neonGreen = Color(0xFF39FF14);
  static const Color background = Color(0xFF0A0A0A); // near-pure black
  static const Color surface = Color(0xFF141414);    // deep charcoal
  static const Color onSurface = Color(0xFFE0E0E0);
  static const Color error = Color(0xFFFF4444);

  // Block type accent colors (used in CreateSessionScreen cards)
  static const Color blockWarmUp = Color(0xFF2979FF);   // Electric Blue
  static const Color blockLoop = Color(0xFFFFAB00);     // Amber
  static const Color blockAction = neonGreen;           // Neon Green
  static const Color blockDelay = Color(0xFF9E9E9E);    // Grey

  // ── Public Theme ───────────────────────────────────────────────────────────
  static ThemeData get darkTheme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: neonGreen,
      brightness: Brightness.dark,
    ).copyWith(
      primary: neonGreen,
      onPrimary: Colors.black,
      surface: surface,
      onSurface: onSurface,
      error: error,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: background,

      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        foregroundColor: onSurface,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: onSurface,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),

      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.symmetric(vertical: 6),
      ),

      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: neonGreen,
        foregroundColor: Colors.black,
        elevation: 0,
        extendedPadding: EdgeInsets.symmetric(horizontal: 28, vertical: 20),
      ),

      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          minimumSize: WidgetStateProperty.all(const Size(64, 64)),
          iconSize: WidgetStateProperty.all(32),
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: neonGreen,
          foregroundColor: Colors.black,
          minimumSize: const Size(64, 56),
          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: neonGreen,
          side: const BorderSide(color: neonGreen, width: 1.5),
          minimumSize: const Size(64, 56),
          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        labelStyle: const TextStyle(color: onSurface),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: neonGreen, width: 2),
        ),
      ),

      tabBarTheme: const TabBarThemeData(
        labelColor: neonGreen,
        unselectedLabelColor: onSurface,
        indicatorColor: neonGreen,
        dividerColor: Colors.transparent,
      ),

      listTileTheme: const ListTileThemeData(
        tileColor: surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      ),

      textTheme: const TextTheme(
        // Massive countdown timer — scaled by FittedBox
        displayLarge: TextStyle(
          fontWeight: FontWeight.w900,
          color: neonGreen,
          letterSpacing: -2,
        ),
        // Phase label ("Sprinting", "Rest")
        titleLarge: TextStyle(
          fontWeight: FontWeight.bold,
          color: onSurface,
          letterSpacing: 3,
          fontSize: 20,
        ),
        titleMedium: TextStyle(fontWeight: FontWeight.bold, color: onSurface),
        bodyMedium: TextStyle(color: onSurface),
        bodySmall: TextStyle(color: Color(0xFF9E9E9E)),
      ),

      dividerTheme: DividerThemeData(
        color: Colors.white.withValues(alpha: 0.08),
        thickness: 1,
      ),
    );
  }
}
