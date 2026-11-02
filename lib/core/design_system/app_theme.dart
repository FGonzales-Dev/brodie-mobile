import 'package:flutter/material.dart';

import 'tokens.dart';

/// Material [ThemeData] derived from [BrodieColors], so stock widgets
/// (switches, sliders, dialogs, snackbars, text fields) match the design
/// system without per-screen styling.
abstract final class AppTheme {
  static ThemeData get dark => _build(BrodieColors.dark, Brightness.dark);
  static ThemeData get light => _build(BrodieColors.light, Brightness.light);

  static ThemeData _build(BrodieColors c, Brightness brightness) {
    final shape = RoundedRectangleBorder(
      borderRadius: BrodieSize.borderRadius,
      side: BorderSide(color: c.border, width: BrodieSize.border),
    );
    OutlineInputBorder inputBorder(Color color) => OutlineInputBorder(
          borderRadius: BrodieSize.borderRadius,
          borderSide: BorderSide(color: color, width: BrodieSize.border),
        );
    WidgetStateProperty<Color> selected(Color on, Color off) =>
        WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.selected) ? on : off);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      fontFamily: BrodieFonts.body,
      scaffoldBackgroundColor: c.background,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: c.primaryAction,
        onPrimary: c.onPrimaryAction,
        secondary: c.accent,
        onSecondary: c.onAccent,
        error: c.danger,
        onError: Colors.white,
        surface: c.surface,
        onSurface: c.textPrimary,
        surfaceContainerHighest: c.surfaceRaised,
        outline: c.border,
        outlineVariant: c.divider,
      ),
      textTheme: TextTheme(
        displaySmall: BrodieType.screenTitle.copyWith(color: c.textPrimary),
        headlineMedium: BrodieType.headline.copyWith(color: c.textPrimary),
        titleLarge: BrodieType.title.copyWith(color: c.textPrimary),
        titleMedium: BrodieType.bodyStrong.copyWith(color: c.textPrimary, fontSize: 15),
        bodyLarge: BrodieType.body.copyWith(color: c.textPrimary, fontSize: 15),
        bodyMedium: BrodieType.body.copyWith(color: c.textPrimary),
        bodySmall: BrodieType.caption.copyWith(color: c.textSecondary),
        labelLarge: BrodieType.label.copyWith(color: c.textSecondary),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: c.background,
        foregroundColor: c.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: BrodieType.title.copyWith(color: c.textPrimary),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: BrodieSpace.md, vertical: 18),
        border: inputBorder(c.border),
        enabledBorder: inputBorder(c.border),
        focusedBorder: inputBorder(c.primaryAction),
        errorBorder: inputBorder(c.danger),
        focusedErrorBorder: inputBorder(c.danger),
        hintStyle: BrodieType.body.copyWith(color: c.textSecondary),
        labelStyle: BrodieType.body.copyWith(color: c.textSecondary),
        helperStyle: BrodieType.caption.copyWith(color: c.textSecondary),
        helperMaxLines: 2,
        errorMaxLines: 2,
        prefixIconColor: c.textSecondary,
        suffixIconColor: c.textSecondary,
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: c.textPrimary,
          textStyle: BrodieType.bodyStrong,
          shape: const RoundedRectangleBorder(borderRadius: BrodieSize.borderRadius),
        ),
      ),
      cardTheme: CardThemeData(color: c.surface, elevation: 0, margin: EdgeInsets.zero, shape: shape),
      dividerTheme: DividerThemeData(color: c.divider, thickness: 1, space: 1),
      iconTheme: IconThemeData(color: c.textPrimary),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: c.primaryAction),
      textSelectionTheme: TextSelectionThemeData(cursorColor: c.primaryAction, selectionHandleColor: c.primaryAction),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: c.textPrimary,
        contentTextStyle: BrodieType.bodyStrong.copyWith(color: c.background),
        shape: const RoundedRectangleBorder(borderRadius: BrodieSize.borderRadius),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.surface,
        shape: shape,
        titleTextStyle: BrodieType.title.copyWith(color: c.textPrimary),
        contentTextStyle: BrodieType.body.copyWith(color: c.textSecondary),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        shape: Border(top: BorderSide(color: c.accent, width: 3)),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: selected(c.onPrimaryAction, c.textSecondary),
        trackColor: selected(c.primaryAction, c.surfaceRaised),
        trackOutlineColor: selected(c.primaryAction, c.border),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: c.primaryAction,
        inactiveTrackColor: c.surfaceRaised,
        thumbColor: c.primaryAction,
        valueIndicatorColor: c.primaryAction,
        valueIndicatorTextStyle: BrodieType.bodyStrong.copyWith(color: c.onPrimaryAction),
      ),
      extensions: [c],
    );
  }
}

extension BrodieThemeContext on BuildContext {
  BrodieColors get colors => Theme.of(this).extension<BrodieColors>()!;
}
