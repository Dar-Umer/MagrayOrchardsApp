import 'package:flutter/material.dart';

class ThemeConfig {
  ThemeConfig._();

  static const Map<String, Map<int, String>> palettes = {
    'emerald': {
      50: '#f0fdf4', 100: '#dcfce7', 200: '#bbf7d0', 300: '#86efac',
      400: '#4ade80', 500: '#22c55e', 600: '#16a34a', 700: '#15803d',
      800: '#166534', 900: '#14532d',
    },
    'blue': {
      50: '#eff6ff', 100: '#dbeafe', 200: '#bfdbfe', 300: '#93c5fd',
      400: '#60a5fa', 500: '#3b82f6', 600: '#2563eb', 700: '#1d4ed8',
      800: '#1e40af', 900: '#1e3a8a',
    },
    'indigo': {
      50: '#eef2ff', 100: '#e0e7ff', 200: '#c7d2fe', 300: '#a5b4fc',
      400: '#818cf8', 500: '#6366f1', 600: '#4f46e5', 700: '#4338ca',
      800: '#3730a3', 900: '#312e81',
    },
    'purple': {
      50: '#faf5ff', 100: '#f3e8ff', 200: '#e9d5ff', 300: '#d8b4fe',
      400: '#c084fc', 500: '#a855f7', 600: '#9333ea', 700: '#7e22ce',
      800: '#6b21a8', 900: '#581c87',
    },
    'rose': {
      50: '#fff1f2', 100: '#ffe4e6', 200: '#fecdd3', 300: '#fda4af',
      400: '#fb7185', 500: '#f43f5e', 600: '#e11d48', 700: '#be123c',
      800: '#9f1239', 900: '#881337',
    },
    'orange': {
      50: '#fff7ed', 100: '#ffedd5', 200: '#fed7aa', 300: '#fdba74',
      400: '#fb923c', 500: '#f97316', 600: '#ea580c', 700: '#c2410c',
      800: '#9a3412', 900: '#7c2d12',
    },
    'teal': {
      50: '#f0fdfa', 100: '#ccfbf1', 200: '#99f6e4', 300: '#5eead4',
      400: '#2dd4bf', 500: '#14b8a6', 600: '#0d9488', 700: '#0f766e',
      800: '#115e59', 900: '#134e4a',
    },
    'amber': {
      50: '#fffbeb', 100: '#fef3c7', 200: '#fde68a', 300: '#fcd34d',
      400: '#fbbf24', 500: '#f59e0b', 600: '#d97706', 700: '#b45309',
      800: '#92400e', 900: '#78350f',
    },
  };

  static const Map<String, String> fonts = {
    'Inter': 'Inter',
    'Poppins': 'Poppins',
    'Roboto': 'Roboto',
    'Playfair Display': 'Playfair Display',
  };

  static Color _hexToColor(String hex) {
    hex = hex.replaceFirst('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    return Color(int.parse(hex, radix: 16));
  }

  static Map<int, Color> getPaletteColors(String paletteName) {
    final raw = palettes[paletteName] ?? palettes['emerald']!;
    return raw.map((k, v) => MapEntry(k, _hexToColor(v)));
  }

  static MaterialColor buildMaterialSwatch(String paletteName) {
    final colors = getPaletteColors(paletteName);
    return MaterialColor(
      colors[600]!.value,
      {
        50: colors[50]!,
        100: colors[100]!,
        200: colors[200]!,
        300: colors[300]!,
        400: colors[400]!,
        500: colors[500]!,
        600: colors[600]!,
        700: colors[700]!,
        800: colors[800]!,
        900: colors[900]!,
      },
    );
  }

  static ThemeData buildThemeData({
    String paletteName = 'emerald',
    String fontFamily = 'Inter',
  }) {
    final colors = getPaletteColors(paletteName);
    final primary = colors[600]!;
    final primaryDark = colors[700]!;
    final primaryLight = colors[100]!;

    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        brightness: Brightness.light,
        primary: primary,
        onPrimary: Colors.white,
        primaryContainer: primaryLight,
        onPrimaryContainer: primaryDark,
        secondary: primary,
        surface: Colors.white,
        onSurface: const Color(0xFF1a1a1a),
      ),
      scaffoldBackgroundColor: const Color(0xFFF8FAFC),
      fontFamily: fontFamily,
      appBarTheme: AppBarTheme(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: BorderSide(color: primary),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.w600),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.grey.shade100),
        ),
        color: Colors.white,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.grey.shade50,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        selectedItemColor: primary,
        unselectedItemColor: Colors.grey.shade500,
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        elevation: 8,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: primaryLight,
        labelStyle: TextStyle(color: primaryDark, fontFamily: fontFamily),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: primary),
    );
  }

  static Color color50(String paletteName) => getPaletteColors(paletteName)[50]!;
  static Color color100(String paletteName) => getPaletteColors(paletteName)[100]!;
  static Color color200(String paletteName) => getPaletteColors(paletteName)[200]!;
  static Color color300(String paletteName) => getPaletteColors(paletteName)[300]!;
  static Color color400(String paletteName) => getPaletteColors(paletteName)[400]!;
  static Color color500(String paletteName) => getPaletteColors(paletteName)[500]!;
  static Color color600(String paletteName) => getPaletteColors(paletteName)[600]!;
  static Color color700(String paletteName) => getPaletteColors(paletteName)[700]!;
  static Color color800(String paletteName) => getPaletteColors(paletteName)[800]!;
  static Color color900(String paletteName) => getPaletteColors(paletteName)[900]!;
}
