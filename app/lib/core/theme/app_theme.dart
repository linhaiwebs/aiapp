import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Obsidian Amber Design System — 端云智采
/// Project: "端云智采数据采集APP" (projects/12594566715822483611)
/// Style: Neomorph Dark Mode — Warm Amber Primary, Tactile Depth
///
/// Depth through neomorph shadows (outer + inner) and glass-morphism.
/// 4px baseline grid. Inter + PingFang SC.

class AppColors {
  AppColors._();

  // ── Brand Actions ──
  /// Warm Amber — Primary Action (#ffb59a)
  static const primary = Color(0xFFFFB59A);
  /// Electronic Green — Success / Quality (#78dc77)
  static const secondary = Color(0xFF78DC77);
  /// Warning Orange — Alert / Rejection (#F59E0B)
  static const orange = Color(0xFFF59E0B);

  // ── Background (Level 0) ──
  static const background = Color(0xFF131313);
  static const surface = Color(0xFF131313);
  static const surfaceDim = Color(0xFF131313);
  static const surfaceBright = Color(0xFF393939);

  // ── Surface Tiers ──
  /// Level 1: Cards/Containers — #20201f with #58423a border
  static const cardFill = Color(0xFF20201F);
  /// Darkest surface
  static const surfaceContainerLowest = Color(0xFF0E0E0E);
  static const surfaceContainerLow = Color(0xFF1C1B1B);
  static const surfaceContainer = Color(0xFF20201F);
  static const surfaceContainerHigh = Color(0xFF2A2A2A);
  static const surfaceContainerHighest = Color(0xFF353535);
  static const surfaceVariant = Color(0xFF353535);

  // ── On-Surface Text ──
  /// Warm white
  static const onSurface = Color(0xFFE5E2E1);
  /// Warm beige
  static const onSurfaceVariant = Color(0xFFDFC0B5);
  static const onBackground = Color(0xFFE5E2E1);
  static const inverseSurface = Color(0xFFE5E2E1);
  static const inverseOnSurface = Color(0xFF313030);

  // ── Outline / Border ──
  /// Warm brown
  static const outline = Color(0xFFA78B81);
  /// Dark warm brown — card border
  static const outlineVariant = Color(0xFF58423A);
  static const separator = Color(0xFF58423A);
  static const surfaceTint = Color(0xFFFFB59A);

  // ── Error ──
  static const error = Color(0xFFFFB4AB);
  static const errorContainer = Color(0xFF93000A);
  static const onError = Color(0xFF690005);
  static const onErrorContainer = Color(0xFFFFDAD6);

  // ── M3 primary tokens (namedColors) — used by ColorScheme ──
  static const primaryM3 = Color(0xFFFFB59A);
  static const primaryContainer = Color(0xFFFF7A45);
  static const primaryFixed = Color(0xFFFFDBCF);
  static const primaryFixedDim = Color(0xFFFFB59A);
  static const onPrimary = Color(0xFF5B1B00);
  static const onPrimaryContainer = Color(0xFF672000);
  static const onPrimaryFixed = Color(0xFF380D00);
  static const onPrimaryFixedVariant = Color(0xFF802900);
  static const inversePrimary = Color(0xFFA73A05);

  // ── M3 secondary tokens (namedColors) — used by ColorScheme ──
  static const secondaryM3 = Color(0xFF78DC77);
  static const secondaryContainer = Color(0xFF00761F);
  static const onSecondary = Color(0xFF00390A);
  static const onSecondaryContainer = Color(0xFF95FB92);
  static const secondaryFixed = Color(0xFF94F990);
  static const secondaryFixedDim = Color(0xFF78DC77);
  static const onSecondaryFixed = Color(0xFF002204);
  static const onSecondaryFixedVariant = Color(0xFF005313);

  // ── M3 tertiary tokens (namedColors) — used by ColorScheme ──
  static const tertiary = Color(0xFFC8C6C6);
  static const tertiaryContainer = Color(0xFFA2A1A1);
  static const onTertiary = Color(0xFF303030);
  static const onTertiaryContainer = Color(0xFF383838);
  static const tertiaryFixed = Color(0xFFE4E2E1);
  static const tertiaryFixedDim = Color(0xFFC8C6C6);
  static const onTertiaryFixed = Color(0xFF1B1C1C);
  static const onTertiaryFixedVariant = Color(0xFF474747);

  // ── Input ──
  /// Dark fill — deeper than background for recessed effect
  static const inputFill = Color(0xFF0A0A0A);
}

class AppSpacing {
  AppSpacing._();
  /// 4px baseline grid
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
  static const layoutMargin = 24.0;
  static const dataGutter = 20.0;
  static const cardPadding = 24.0;
  static const listGap = 16.0;
}

class AppRadius {
  AppRadius._();
  /// Standard elements: buttons, inputs, checkboxes (4px)
  static const sm = 4.0;
  /// Container elements: cards (8px)
  static const md = 8.0;
  /// Rounded cards: neomorph highlights (28px — Stitch signature)
  static const card = 28.0;
  /// Indicators: status dots, pips
  static const full = 9999.0;
}

class AppShadows {
  AppShadows._();

  /// Neomorph tactile card shadow (outer)
  static const card = [
    BoxShadow(
      color: Color(0x66000000),
      blurRadius: 24,
      offset: Offset(0, 8),
    ),
  ];

  /// Recessed inner shadow mimic — dark gradient overlay
  static const innerWell = BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0x08000000), Color(0x33000000)],
    ),
  );

  /// Subtle shadow for top bar
  static const topBar = [
    BoxShadow(
      color: Color(0x20000000),
      blurRadius: 6,
      offset: Offset(0, 2),
    ),
  ];

  /// Bottom nav shadow
  static const bottomNav = [
    BoxShadow(
      color: Color(0x66000000),
      blurRadius: 24,
      offset: Offset(0, -8),
    ),
  ];
}

class AppTheme {
  AppTheme._();

  static const _fontFamily = 'Inter';

  static final darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    fontFamily: _fontFamily,
    primaryColor: AppColors.primary,
    scaffoldBackgroundColor: AppColors.background,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.primaryM3,
      onPrimary: AppColors.onPrimary,
      primaryContainer: AppColors.primaryContainer,
      onPrimaryContainer: AppColors.onPrimaryContainer,
      primaryFixed: AppColors.primaryFixed,
      primaryFixedDim: AppColors.primaryFixedDim,
      secondary: AppColors.secondaryM3,
      onSecondary: AppColors.onSecondary,
      secondaryContainer: AppColors.secondaryContainer,
      onSecondaryContainer: AppColors.onSecondaryContainer,
      secondaryFixed: AppColors.secondaryFixed,
      secondaryFixedDim: AppColors.secondaryFixedDim,
      tertiary: AppColors.tertiary,
      onTertiary: AppColors.onTertiary,
      tertiaryContainer: AppColors.tertiaryContainer,
      onTertiaryContainer: AppColors.onTertiaryContainer,
      tertiaryFixed: AppColors.tertiaryFixed,
      tertiaryFixedDim: AppColors.tertiaryFixedDim,
      error: AppColors.error,
      onError: AppColors.onError,
      errorContainer: AppColors.errorContainer,
      onErrorContainer: AppColors.onErrorContainer,
      surface: AppColors.surface,
      onSurface: AppColors.onSurface,
      surfaceContainerHighest: AppColors.surfaceContainerHighest,
      surfaceContainerHigh: AppColors.surfaceContainerHigh,
      surfaceContainer: AppColors.surfaceContainer,
      surfaceContainerLow: AppColors.surfaceContainerLow,
      surfaceContainerLowest: AppColors.surfaceContainerLowest,
      surfaceDim: AppColors.surfaceDim,
      surfaceBright: AppColors.surfaceBright,
      outline: AppColors.outline,
      outlineVariant: AppColors.outlineVariant,
      inverseSurface: AppColors.inverseSurface,
      inversePrimary: AppColors.inversePrimary,
    ),

    // ── AppBar ──
    appBarTheme: const AppBarTheme(
      centerTitle: false,
      elevation: 2,
      scrolledUnderElevation: 0,
      backgroundColor: Color(0xCC131313),
      foregroundColor: AppColors.onSurface,
      shadowColor: Color(0x20000000),
      systemOverlayStyle: SystemUiOverlayStyle.light,
    ),

    // ── Cards: Level 1 (#20201f, warm border, tactile shadow) ──
    cardTheme: CardThemeData(
      elevation: 8,
      shadowColor: Colors.black,
      color: AppColors.cardFill,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: const BorderSide(color: AppColors.outlineVariant, width: 0.5),
      ),
    ),

    // ── Bottom Nav ──
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      type: BottomNavigationBarType.fixed,
      selectedItemColor: AppColors.primary,
      unselectedItemColor: AppColors.outline,
      backgroundColor: Color(0xE6131313),
      elevation: 0,
    ),

    // ── Chips: Low-Alpha bg, 1px border, matching text ──
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.surfaceContainerHigh,
      selectedColor: AppColors.primary.withValues(alpha: 0.15),
      labelStyle: const TextStyle(
        fontFamily: _fontFamily,
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
        color: AppColors.onSurface,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      side: const BorderSide(color: AppColors.outlineVariant, width: 1),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    ),

    // ── Inputs: dark-fill, 1px border, amber glow on focus ──
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.inputFill,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        borderSide: const BorderSide(color: AppColors.outlineVariant, width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        borderSide: const BorderSide(color: AppColors.outlineVariant, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      hintStyle: const TextStyle(
        fontFamily: _fontFamily,
        color: AppColors.outline,
        fontSize: 14,
        fontWeight: FontWeight.w400,
      ),
      labelStyle: const TextStyle(
        fontFamily: _fontFamily,
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.6,
        color: AppColors.onSurfaceVariant,
      ),
      floatingLabelStyle: const TextStyle(
        fontFamily: _fontFamily,
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.6,
        color: AppColors.primary,
      ),
    ),

    // ── Primary Button: Solid Amber, dark text ──
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        textStyle: const TextStyle(
          fontFamily: _fontFamily,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),

    // ── Secondary Button: Outlined, warm white text ──
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.onSurface,
        side: const BorderSide(color: AppColors.outlineVariant, width: 1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        textStyle: const TextStyle(
          fontFamily: _fontFamily,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
      ),
    ),

    // ── Separators: 1px warm brown ──
    dividerTheme: const DividerThemeData(
      color: AppColors.separator,
      thickness: 1,
      space: 1,
    ),

    tabBarTheme: const TabBarThemeData(
      labelColor: AppColors.primary,
      unselectedLabelColor: AppColors.outline,
      indicatorColor: AppColors.primary,
    ),

    // ── Level 2 Modals ──
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.cardFill,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: const BorderSide(color: AppColors.outlineVariant, width: 1),
      ),
    ),

    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.surfaceContainerHighest,
      contentTextStyle: const TextStyle(
        fontFamily: _fontFamily,
        color: AppColors.onSurface,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      behavior: SnackBarBehavior.floating,
    ),

    // ── Typography (Obsidian Amber tokens) ──
    textTheme: const TextTheme(
      // h1: 32/1.2, weight 600, -0.01em
      headlineLarge: TextStyle(
        fontFamily: _fontFamily,
        fontSize: 32,
        fontWeight: FontWeight.w600,
        height: 1.2,
        letterSpacing: -0.32,
        color: AppColors.onSurface,
      ),
      // h2: 24/1.3, weight 500, -0.01em
      headlineMedium: TextStyle(
        fontFamily: _fontFamily,
        fontSize: 24,
        fontWeight: FontWeight.w500,
        height: 1.3,
        letterSpacing: -0.24,
        color: AppColors.onSurface,
      ),
      // body-lg: 18/1.6, weight 400
      bodyLarge: TextStyle(
        fontFamily: _fontFamily,
        fontSize: 18,
        fontWeight: FontWeight.w400,
        height: 1.6,
        letterSpacing: 0.18,
        color: AppColors.onSurface,
      ),
      // body-md: 16/1.5, weight 400
      bodyMedium: TextStyle(
        fontFamily: _fontFamily,
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 1.5,
        letterSpacing: 0.16,
        color: AppColors.onSurface,
      ),
      // body-sm: 13/1.5, weight 400
      bodySmall: TextStyle(
        fontFamily: _fontFamily,
        fontSize: 13,
        fontWeight: FontWeight.w400,
        height: 1.5,
        letterSpacing: 0.13,
        color: AppColors.onSurfaceVariant,
      ),
      // label-caps: 12/1.4, weight 700, 0.1em
      labelSmall: TextStyle(
        fontFamily: _fontFamily,
        fontSize: 12,
        fontWeight: FontWeight.w700,
        height: 1.4,
        letterSpacing: 1.2,
        color: AppColors.onSurfaceVariant,
      ),
    ),
  );
}
