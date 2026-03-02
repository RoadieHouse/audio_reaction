import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Centralized theme definition for Audio Reaction Training.
/// All widgets reference Theme.of(context) — no hardcoded colors.
abstract class AppTheme {
  // ── Design Tokens (Premium Minimalist Palette) ───────────────────────────

  // A modern, energetic "Volt" accent. Used sparingly for FABs and active states.
  static const Color brandAccent = Color.fromARGB(255, 10, 211, 187);

  static const Color bgBase = Color(0xFF0B0F14);
  static const Color bgSurface = Color(0xFF121821);
  static const Color bgSurfaceElevated = Color(0xFF18202A);

  static const Color textPrimary = Color(0xFFE6EDF3);
  static const Color textSecondary = Color(0xFF8B98A5);

  static const Color outline = Color(0xFF202938);

  static const Color error = Color(0xFFFF5D5D);

  static const Color blockWarmUp = Color(0xFF4F7CFF);
  static const Color blockLoop = Color(0xFFF59E0B);
  static const Color blockAction = brandAccent;
  static const Color blockDelay = Color(0xFF6B7280);

  // ── Theme Extension for block colors ─────────────────────────────────────

  static const _blockColorsExtension = BlockColors(
    warmUp: blockWarmUp,
    loop: blockLoop,
    action: blockAction,
    delay: blockDelay,
  );

  // ── Public Theme ─────────────────────────────────────────────────────────

  static ThemeData get darkTheme {
    // 1. Initialize the base text theme with the Inter font
    final baseTextTheme = GoogleFonts.interTextTheme(
      ThemeData.dark().textTheme,
    );

    // 2. Build a fully-aligned dark ColorScheme, overriding key roles
    final baseScheme = ColorScheme.fromSeed(
      seedColor: brandAccent,
      brightness: Brightness.dark,
    );

    final colorScheme = baseScheme.copyWith(
      primary: brandAccent,
      onPrimary: Colors.black,
      secondary: textSecondary,
      onSecondary: textPrimary,
      tertiary: blockWarmUp,
      onTertiary: textPrimary,
      error: error,
      onError: textPrimary,
      surface: bgSurface,
      surfaceContainerHighest: bgSurfaceElevated,
      surfaceContainerHigh: bgSurface,
      surfaceContainer: bgSurface,
      surfaceContainerLow: bgSurface,
      surfaceDim: bgBase,
      surfaceBright: bgSurface,
      onSurface: textPrimary,
      onSurfaceVariant: textSecondary,
      outline: bgSurfaceElevated,
      outlineVariant: bgSurfaceElevated,
      inverseSurface: textPrimary,
      onInverseSurface: bgBase,
      inversePrimary: brandAccent,
    );

    // 3. Refined typography: slightly lighter weights and limited negative tracking
    final textTheme = baseTextTheme.copyWith(
      displayLarge: baseTextTheme.displayLarge?.copyWith(
        fontWeight: FontWeight.w700,
        color: textPrimary,
        letterSpacing: -0.5,
      ),
      titleLarge: baseTextTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w600,
        color: textPrimary,
        letterSpacing: -0.25,
        fontSize: 22,
      ),
      titleMedium: baseTextTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w500,
        color: textPrimary,
      ),
      bodyMedium: baseTextTheme.bodyMedium?.copyWith(
        color: textPrimary,
        fontWeight: FontWeight.w400,
      ),
      bodySmall: baseTextTheme.bodySmall?.copyWith(
        color: textSecondary,
        fontWeight: FontWeight.w400,
      ),
      labelLarge: baseTextTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
      ),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: bgBase,
      textTheme: textTheme,
      extensions: const <ThemeExtension<dynamic>>[_blockColorsExtension],

      // 4. APP BAR: Seamless blend with background, aligned with textTheme
      appBarTheme: AppBarTheme(
        backgroundColor: bgBase,
        foregroundColor: textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.25,
        ),
      ),

      // 5. CARDS: Zero elevation, distinct surface color, no unwanted surface tint
      cardTheme: CardThemeData(
        color: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        margin: const EdgeInsets.symmetric(vertical: 6),
      ),

      // 6. FLOATING ACTION BUTTON: Primary pop of color, uses scheme colors
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
        shape: const StadiumBorder(),
        extendedPadding: const EdgeInsets.symmetric(
          horizontal: 24,
          vertical: 16,
        ),
        extendedTextStyle: textTheme.labelLarge?.copyWith(fontSize: 16),
      ),

      // 7. BUTTONS: Primary uses brand color; white variant remains possible ad hoc
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          elevation: 0,
          minimumSize: const Size(64, 52),
          textStyle: textTheme.labelLarge?.copyWith(fontSize: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colorScheme.onSurface,
          side: BorderSide(color: colorScheme.outline, width: 1.5),
          minimumSize: const Size(64, 52),
          textStyle: textTheme.labelLarge?.copyWith(fontSize: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),

      // 8. INPUTS: Soft, borderless forms with clear focus state
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: bgSurfaceElevated,
        labelStyle: textTheme.bodySmall,
        floatingLabelStyle: textTheme.bodySmall?.copyWith(
          color: textPrimary,
          fontWeight: FontWeight.w500,
        ),
        hintStyle: textTheme.bodySmall?.copyWith(
          color: textSecondary.withValues(alpha: 0.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.error, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.error, width: 1.5),
        ),
      ),

      // 9. CHIPS: Borderless, elevated elements aligned with surfaceVariant
      chipTheme: ChipThemeData(
        backgroundColor: colorScheme.surfaceContainerHighest,
        deleteIconColor: textSecondary,
        labelStyle: textTheme.bodySmall?.copyWith(
          color: textPrimary,
          fontWeight: FontWeight.w500,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),

      // 10. LIST TILE: Clean styling inside cards
      listTileTheme: ListTileThemeData(
        iconColor: textSecondary,
        textColor: textPrimary,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      ),

      // 11. DIVIDERS: Barely visible structural lines
      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant,
        thickness: 1,
        space: 24,
      ),

      // 12. SWITCH: Premium look, using scheme colors
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith<Color>((states) {
          if (states.contains(WidgetState.disabled)) {
            return textSecondary.withValues(alpha: 0.4);
          }
          if (states.contains(WidgetState.selected)) {
            return colorScheme.onPrimary;
          }
          return textSecondary;
        }),
        trackColor: WidgetStateProperty.resolveWith<Color>((states) {
          if (states.contains(WidgetState.disabled)) {
            return bgSurfaceElevated.withValues(alpha: 0.5);
          }
          if (states.contains(WidgetState.selected)) {
            return colorScheme.primary;
          }
          return bgSurfaceElevated;
        }),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
    );
  }
}

/// ThemeExtension for block-specific colors (warm-up, loop, etc.).
// ignore: unintended_html_in_doc_comment
/// Access via: Theme.of(context).extension<BlockColors>().
class BlockColors extends ThemeExtension<BlockColors> {
  final Color warmUp;
  final Color loop;
  final Color action;
  final Color delay;

  const BlockColors({
    required this.warmUp,
    required this.loop,
    required this.action,
    required this.delay,
  });

  @override
  BlockColors copyWith({
    Color? warmUp,
    Color? loop,
    Color? action,
    Color? delay,
  }) {
    return BlockColors(
      warmUp: warmUp ?? this.warmUp,
      loop: loop ?? this.loop,
      action: action ?? this.action,
      delay: delay ?? this.delay,
    );
  }

  @override
  BlockColors lerp(ThemeExtension<BlockColors>? other, double t) {
    if (other is! BlockColors) return this;
    return BlockColors(
      warmUp: Color.lerp(warmUp, other.warmUp, t)!,
      loop: Color.lerp(loop, other.loop, t)!,
      action: Color.lerp(action, other.action, t)!,
      delay: Color.lerp(delay, other.delay, t)!,
    );
  }
}
