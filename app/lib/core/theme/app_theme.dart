import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Stitch Design System — 端云智采
/// Derived from Stitch project "端云智采数据采集APP" (12594566715822483611)
class AppColors {
  // Primary
  static const primary = Color(0xFF0058BE);
  static const primaryContainer = Color(0xFF2170E4);
  static const onPrimary = Color(0xFFFFFFFF);
  static const primaryFixed = Color(0xFFD8E2FF);
  static const primaryFixedDim = Color(0xFFADC6FF);

  // Secondary (Success/Quality)
  static const secondary = Color(0xFF10B981);
  static const secondaryContainer = Color(0xFFE0E3E5);
  static const onSecondary = Color(0xFFFFFFFF);

  // Tertiary (Warning/Alert)
  static const tertiary = Color(0xFF924700);
  static const tertiaryContainer = Color(0xFFB75B00);

  // Error
  static const error = Color(0xFFBA1A1A);
  static const errorContainer = Color(0xFFFFDAD6);

  // Surfaces
  static const background = Color(0xFFFCF9F8);
  static const onBackground = Color(0xFF1C1B1B);
  static const surface = Color(0xFFFFFFFF);
  static const onSurface = Color(0xFF1C1B1B);
  static const surfaceDim = Color(0xFFDCD9D9);
  static const surfaceBright = Color(0xFFFCF9F8);
  static const surfaceContainerLowest = Color(0xFFFFFFFF);
  static const surfaceContainerLow = Color(0xFFF6F3F2);
  static const surfaceContainer = Color(0xFFF0EDEC);
  static const surfaceContainerHigh = Color(0xFFEBE7E7);
  static const surfaceContainerHighest = Color(0xFFE5E2E1);
  static const surfaceVariant = Color(0xFFE5E2E1);
  static const onSurfaceVariant = Color(0xFF424754);
  static const inverseSurface = Color(0xFF313030);
  static const inverseOnSurface = Color(0xFFF3F0EF);
  static const inversePrimary = Color(0xFFADC6FF);

  // Outlines
  static const outline = Color(0xFF727785);
  static const outlineVariant = Color(0xFFC2C6D6);

  // Custom overrides from Stitch
  static const overridePrimary = Color(0xFF3B82F6);
  static const overrideSecondary = Color(0xFF10B981);
  static const orange = Color(0xFFF59E0B);
}

class AppSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
  static const containerPadding = 20.0;
  static const gridGutter = 16.0;
  static const stackGap = 16.0;
  static const elementGap = 8.0;
}

class AppRadius {
  static const sm = 2.0;
  static const md = 8.0;
  static const lg = 12.0;
  static const xl = 16.0;
  static const xxl = 24.0;
  static const pill = 9999.0;
}

class AppTheme {
  static final lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    primaryColor: AppColors.primary,
    scaffoldBackgroundColor: AppColors.background,
    colorScheme: const ColorScheme.light(
      primary: AppColors.primary,
      onPrimary: AppColors.onPrimary,
      primaryContainer: AppColors.primaryContainer,
      secondary: AppColors.secondary,
      onSecondary: AppColors.onSecondary,
      tertiary: AppColors.tertiary,
      error: AppColors.error,
      surface: AppColors.surface,
      onSurface: AppColors.onSurface,
      surfaceContainerHighest: AppColors.surfaceContainerHighest,
      outline: AppColors.outline,
    ),
    appBarTheme: const AppBarTheme(
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: AppColors.background,
      foregroundColor: AppColors.onSurface,
      systemOverlayStyle: SystemUiOverlayStyle.dark,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: AppColors.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      type: BottomNavigationBarType.fixed,
      selectedItemColor: AppColors.primary,
      unselectedItemColor: Color(0xFF9CA3AF),
      backgroundColor: AppColors.surface,
      elevation: 0,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.surfaceContainer,
      selectedColor: AppColors.primary.withValues(alpha: 0.1),
      labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      side: BorderSide.none,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surfaceContainerLow,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      hintStyle: const TextStyle(
        color: AppColors.outline,
        fontSize: 14,
        fontWeight: FontWeight.w400,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.outlineVariant,
      thickness: 1,
      space: 1,
    ),
    fontFamily: 'Inter',
  );

  static final darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    primaryColor: AppColors.primaryFixedDim,
    scaffoldBackgroundColor: const Color(0xFF10131A),
    colorScheme: const ColorScheme.dark(
      primary: AppColors.primaryFixedDim,
      onPrimary: Color(0xFF002E6A),
      primaryContainer: Color(0xFF4D8EFF),
      secondary: Color(0xFF4EDEA3),
      tertiary: Color(0xFFFFB786),
      error: Color(0xFFFFB4AB),
      surface: Color(0xFF10131A),
      onSurface: Color(0xFFE1E2EC),
    ),
  );
}
