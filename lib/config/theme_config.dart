import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

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

  // ── Premium "Rich & Premium" tokens ──────────────────────────────────────
  // Deep forest green primary, gold accent, warm ivory surfaces.
  static const Color premiumGreen = Color(0xFF1B4332);
  static const Color premiumGreenDeep = Color(0xFF143226);
  static const Color premiumGreenSoft = Color(0xFFE4EDE7);
  static const Color premiumGold = Color(0xFFC9A227);
  static const Color premiumGoldDeep = Color(0xFFB8860B);
  static const Color premiumGoldSoft = Color(0xFFF7EEDC);
  static const Color premiumIvory = Color(0xFFFBFAF7);
  static const Color premiumCard = Color(0xFFFFFFFF);
  static const Color premiumText = Color(0xFF1F2421);
  static const Color premiumTaupe = Color(0xFF6B6B5E);
  static const Color premiumBorder = Color(0xFFE8E6DF);

  static ThemeData buildThemeData({
    String paletteName = 'emerald',
    String fontFamily = 'Inter',
  }) {
    final colors = getPaletteColors(paletteName);
    // Deep premium color derived from the admin-selected palette (800 shade for
    // depth), with a brighter palette-derived accent instead of a fixed gold,
    // so the whole app reflects the admin's brand colour.
    final primary = colors[800]!;
    final primaryDark = colors[900]!;
    final primarySoft = colors[100]!;
    final accent = colors[600]!;
    final accentSoft = colors[50]!;

    const surface = premiumIvory;
    const surfaceCard = premiumCard;
    const textPrimary = premiumText;
    const textSecondary = premiumTaupe;
    const borderSubtle = premiumBorder;

    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.light,
      primary: primary,
      onPrimary: Colors.white,
      primaryContainer: primarySoft,
      onPrimaryContainer: primaryDark,
      secondary: accent,
      onSecondary: Colors.white,
      secondaryContainer: accentSoft,
      onSecondaryContainer: primaryDark,
      tertiary: primaryDark,
      surface: surface,
      onSurface: textPrimary,
      surfaceContainerLowest: surfaceCard,
      surfaceContainerLow: surface,
      outline: borderSubtle,
      outlineVariant: borderSubtle,
    );

    final baseText = TextStyle(fontFamily: fontFamily, color: textPrimary);

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: surface,
      fontFamily: fontFamily,
      textTheme: TextTheme(
        displaySmall: baseText.copyWith(fontSize: 34, fontWeight: FontWeight.w800, height: 1.12, letterSpacing: -0.5),
        headlineLarge: baseText.copyWith(fontSize: 28, fontWeight: FontWeight.w800, height: 1.15, letterSpacing: -0.5),
        headlineMedium: baseText.copyWith(fontSize: 22, fontWeight: FontWeight.w700, height: 1.2),
        headlineSmall: baseText.copyWith(fontSize: 20, fontWeight: FontWeight.w700),
        titleLarge: baseText.copyWith(fontSize: 18, fontWeight: FontWeight.w700),
        titleMedium: baseText.copyWith(fontSize: 16, fontWeight: FontWeight.w600),
        titleSmall: baseText.copyWith(fontSize: 14, fontWeight: FontWeight.w600),
        bodyLarge: baseText.copyWith(fontSize: 16, height: 1.45),
        bodyMedium: baseText.copyWith(fontSize: 14, height: 1.4, color: textSecondary),
        bodySmall: baseText.copyWith(fontSize: 12, color: textSecondary),
        labelLarge: baseText.copyWith(fontSize: 14, fontWeight: FontWeight.w600),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          letterSpacing: -0.2,
        ),
        iconTheme: const IconThemeData(color: Colors.white, size: 22),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surfaceCard,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shadowColor: Colors.black.withValues(alpha: 0.08),
        height: 68,
        indicatorColor: accentSoft,
        indicatorShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(fontFamily: fontFamily, fontSize: 11, fontWeight: FontWeight.w600),
        ),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          return IconThemeData(
            color: states.contains(WidgetState.selected) ? primaryDark : textSecondary,
            size: 22,
          );
        }),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: surfaceCard,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.black.withValues(alpha: 0.06),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: borderSubtle),
        ),
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.white,
          elevation: 0,
          shadowColor: Colors.transparent,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.w700, fontSize: 14, letterSpacing: 0.2),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.w700, fontSize: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: const BorderSide(color: borderSubtle, width: 1.5),
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          textStyle: TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceCard,
        hintStyle: TextStyle(color: textSecondary.withValues(alpha: 0.8), fontFamily: fontFamily),
        labelStyle: TextStyle(color: textSecondary, fontFamily: fontFamily),
        prefixIconColor: textSecondary,
        suffixIconColor: textSecondary,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: borderSubtle),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: borderSubtle),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: accent, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFEF4444)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.6),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surface,
        selectedColor: accentSoft,
        labelStyle: TextStyle(color: primaryDark, fontFamily: fontFamily, fontWeight: FontWeight.w600, fontSize: 12),
        secondaryLabelStyle: TextStyle(color: textSecondary, fontFamily: fontFamily, fontSize: 12),
        side: const BorderSide(color: borderSubtle),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),
      dividerTheme: DividerThemeData(
        color: borderSubtle,
        thickness: 1,
        space: 1,
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        iconColor: textSecondary,
        textColor: textPrimary,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surfaceCard,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        showDragHandle: true,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surfaceCard,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: textPrimary,
        contentTextStyle: TextStyle(fontFamily: fontFamily, fontSize: 14, color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: primary,
        linearTrackColor: primarySoft.withValues(alpha: 0.4),
        circularTrackColor: primarySoft.withValues(alpha: 0.4),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: primary,
        unselectedLabelColor: textSecondary,
        indicatorColor: accent,
        indicatorSize: TabBarIndicatorSize.label,
        labelStyle: TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.w700, fontSize: 14),
        unselectedLabelStyle: TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.w500, fontSize: 14),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected) ? Colors.white : textSecondary),
        trackColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected) ? primary : borderSubtle),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected) ? primary : Colors.transparent),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected) ? primary : textSecondary),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: accent,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );

    final textTheme = switch (fontFamily) {
      'Poppins' => GoogleFonts.poppinsTextTheme(base.textTheme),
      'Roboto' => GoogleFonts.robotoTextTheme(base.textTheme),
      'Playfair Display' => GoogleFonts.playfairDisplayTextTheme(base.textTheme),
      _ => GoogleFonts.interTextTheme(base.textTheme),
    };

    return base.copyWith(textTheme: textTheme);
  }

  // Convenience accessors used by screens (single source of truth).
  static Color get gold => premiumGold;
  static Color get goldDeep => premiumGoldDeep;
  static Color get goldSoft => premiumGoldSoft;
  static Color get green => premiumGreen;
  static Color get greenDeep => premiumGreenDeep;
  static Color get greenSoft => premiumGreenSoft;
  static Color get ivory => premiumIvory;
  static Color get taupe => premiumTaupe;
  static Color get border => premiumBorder;

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
