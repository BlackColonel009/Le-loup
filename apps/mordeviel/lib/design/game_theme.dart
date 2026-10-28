import 'package:flutter/material.dart';

/// Palette commune ; les ambiances de cartes restent indépendantes des règles.
abstract final class GameTheme {
  static const ink = Color(0xFF101820);
  static const panel = Color(0xFF1A2730);
  static const gold = Color(0xFFD6AE70);
  static const ivory = Color(0xFFF2E8D5);
  static const muted = Color(0xFFB5BCBA);
  static const line = Color(0xFF586052);

  static ThemeData get classic {
    final scheme = ColorScheme.fromSeed(
      seedColor: gold,
      brightness: Brightness.dark,
      primary: gold,
      onPrimary: const Color(0xFF261B0D),
      surface: panel,
      onSurface: ivory,
    );
    final base = ThemeData(
      fontFamily: 'VillageSans',
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: ink,
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
    );
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
    );
    return base.copyWith(
      textTheme: base.textTheme.copyWith(
        displayMedium: base.textTheme.displayMedium?.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: 2,
          fontFamily: 'Cormorant',
        ),
        headlineSmall: base.textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.w600,
          fontFamily: 'Cormorant',
          fontSize: 30,
        ),
        titleLarge: base.textTheme.titleLarge?.copyWith(
          fontFamily: 'Cormorant',
          fontWeight: FontWeight.w600,
          fontSize: 27,
        ),
        bodyMedium: base.textTheme.bodyMedium?.copyWith(height: 1.5),
        bodySmall: base.textTheme.bodySmall?.copyWith(
          color: muted,
          height: 1.4,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: ink,
        foregroundColor: ivory,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: panel,
        elevation: 0,
        margin: const EdgeInsets.symmetric(vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: line, width: .6),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 54),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: shape,
          elevation: 2,
          shadowColor: Colors.black38,
          textStyle: const TextStyle(
            fontFamily: 'VillageSans',
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 52),
          foregroundColor: ivory,
          side: const BorderSide(color: line),
          shape: shape,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: const TextStyle(
            fontFamily: 'VillageSans',
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          foregroundColor: gold,
          textStyle: const TextStyle(
            fontFamily: 'VillageSans',
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: panel,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: line, width: .7),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: ink.withValues(alpha: .5),
        contentPadding: const EdgeInsets.all(18),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: panel,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: line),
        ),
      ),
      dividerTheme: const DividerThemeData(color: line, thickness: .6),
    );
  }
}
