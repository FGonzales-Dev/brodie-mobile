import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Light and dark [ThemeData] built from the tokens in
/// tech-spec-and-roadmap.md section 6.
class AppTheme {
  const AppTheme._();

  static ThemeData get dark => _build(
        brightness: Brightness.dark,
        background: AppColors.darkBackground,
        surface: AppColors.darkSurface,
        secondaryAccent: AppColors.secondaryAccentDark,
        success: AppColors.successDark,
        danger: AppColors.dangerDark,
        textPrimary: AppColors.textPrimaryDark,
        textSecondary: AppColors.textSecondaryDark,
      );

  static ThemeData get light => _build(
        brightness: Brightness.light,
        background: AppColors.lightBackground,
        surface: AppColors.lightSurface,
        secondaryAccent: AppColors.secondaryAccentLight,
        success: AppColors.successLight,
        danger: AppColors.dangerLight,
        textPrimary: AppColors.textPrimaryLight,
        textSecondary: AppColors.textSecondaryLight,
      );

  static ThemeData _build({
    required Brightness brightness,
    required Color background,
    required Color surface,
    required Color secondaryAccent,
    required Color success,
    required Color danger,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: AppColors.primaryAccent,
      onPrimary: Colors.white,
      secondary: secondaryAccent,
      onSecondary: brightness == Brightness.dark ? Colors.black : Colors.white,
      error: danger,
      onError: Colors.white,
      surface: surface,
      onSurface: textPrimary,
    );

    final textTheme = GoogleFonts.interTextTheme(
      brightness == Brightness.dark
          ? ThemeData(brightness: Brightness.dark).textTheme
          : ThemeData(brightness: Brightness.light).textTheme,
    ).apply(
      bodyColor: textPrimary,
      displayColor: textPrimary,
    );

    final headlineFont = GoogleFonts.rajdhani(
      fontWeight: FontWeight.bold,
      color: textPrimary,
    );

    return ThemeData(
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: background,
      textTheme: textTheme.copyWith(
        displayLarge: headlineFont.copyWith(fontSize: 57),
        displayMedium: headlineFont.copyWith(fontSize: 45),
        displaySmall: headlineFont.copyWith(fontSize: 36),
        headlineLarge: headlineFont.copyWith(fontSize: 32),
        headlineMedium: headlineFont.copyWith(fontSize: 28),
        headlineSmall: headlineFont.copyWith(fontSize: 24),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: textPrimary,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: AppColors.primaryAccent,
        unselectedItemColor: textSecondary,
        type: BottomNavigationBarType.fixed,
      ),
      extensions: [
        AppStatusColors(success: success, danger: danger),
      ],
      useMaterial3: true,
    );
  }
}

/// Status colors (online/offline, SOS) that aren't part of Material's
/// [ColorScheme] but carry specific meaning per the spec (section 6).
class AppStatusColors extends ThemeExtension<AppStatusColors> {
  const AppStatusColors({required this.success, required this.danger});

  final Color success;
  final Color danger;

  @override
  AppStatusColors copyWith({Color? success, Color? danger}) {
    return AppStatusColors(
      success: success ?? this.success,
      danger: danger ?? this.danger,
    );
  }

  @override
  AppStatusColors lerp(ThemeExtension<AppStatusColors>? other, double t) {
    if (other is! AppStatusColors) return this;
    return AppStatusColors(
      success: Color.lerp(success, other.success, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
    );
  }
}
