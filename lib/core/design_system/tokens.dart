import 'package:flutter/material.dart';

/// Color tokens for the "Throttle" direction (design/ui-options.html, option C):
/// amber on black, hard edges, high contrast for sunlight and gloves.
///
/// [primaryAction] is the main interactive color per mode: amber on dark,
/// black (with amber text) on light, where amber alone lacks contrast.
@immutable
class BrodieColors extends ThemeExtension<BrodieColors> {
  const BrodieColors({
    required this.background,
    required this.surface,
    required this.surfaceRaised,
    required this.border,
    required this.divider,
    required this.textPrimary,
    required this.textSecondary,
    required this.accent,
    required this.onAccent,
    required this.primaryAction,
    required this.onPrimaryAction,
    required this.warning,
    required this.success,
    required this.danger,
  });

  static const dark = BrodieColors(
    background: Color(0xFF000000),
    surface: Color(0xFF101010),
    surfaceRaised: Color(0xFF1C1C1C),
    border: Color(0xFF2A2A2A),
    divider: Color(0xFF2A2A2A),
    textPrimary: Color(0xFFFFFFFF),
    textSecondary: Color(0xFF9A9A9A),
    accent: Color(0xFFFFC400),
    onAccent: Color(0xFF000000),
    primaryAction: Color(0xFFFFC400),
    onPrimaryAction: Color(0xFF000000),
    warning: Color(0xFFFF5A1F),
    success: Color(0xFF00E676),
    danger: Color(0xFFFF3B30),
  );

  static const light = BrodieColors(
    background: Color(0xFFF2F0EA),
    surface: Color(0xFFFFFFFF),
    surfaceRaised: Color(0xFFE9E6DD),
    border: Color(0xFF111111),
    divider: Color(0xFFD3CEC3),
    textPrimary: Color(0xFF0A0A0A),
    textSecondary: Color(0xFF5A5A5A),
    accent: Color(0xFFFFC400),
    onAccent: Color(0xFF000000),
    primaryAction: Color(0xFF0A0A0A),
    onPrimaryAction: Color(0xFFFFC400),
    warning: Color(0xFFE04E12),
    success: Color(0xFF0A8F45),
    danger: Color(0xFFD50000),
  );

  /// The rider's own position on maps, the conventional location blue.
  static const myPosition = Color(0xFF3B82F6);

  /// Backgrounds for initial-letter avatars, picked by a stable hash of the name.
  static const avatarPalette = [Color(0xFF3B82F6), Color(0xFF10B981), Color(0xFFA855F7), Color(0xFFF97316)];

  final Color background;
  final Color surface;
  final Color surfaceRaised;
  final Color border;
  final Color divider;
  final Color textPrimary;
  final Color textSecondary;
  final Color accent;
  final Color onAccent;
  final Color primaryAction;
  final Color onPrimaryAction;
  final Color warning;
  final Color success;
  final Color danger;

  @override
  BrodieColors copyWith({
    Color? background,
    Color? surface,
    Color? surfaceRaised,
    Color? border,
    Color? divider,
    Color? textPrimary,
    Color? textSecondary,
    Color? accent,
    Color? onAccent,
    Color? primaryAction,
    Color? onPrimaryAction,
    Color? warning,
    Color? success,
    Color? danger,
  }) {
    return BrodieColors(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceRaised: surfaceRaised ?? this.surfaceRaised,
      border: border ?? this.border,
      divider: divider ?? this.divider,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      accent: accent ?? this.accent,
      onAccent: onAccent ?? this.onAccent,
      primaryAction: primaryAction ?? this.primaryAction,
      onPrimaryAction: onPrimaryAction ?? this.onPrimaryAction,
      warning: warning ?? this.warning,
      success: success ?? this.success,
      danger: danger ?? this.danger,
    );
  }

  @override
  BrodieColors lerp(ThemeExtension<BrodieColors>? other, double t) {
    if (other is! BrodieColors) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;
    return BrodieColors(
      background: mix(background, other.background),
      surface: mix(surface, other.surface),
      surfaceRaised: mix(surfaceRaised, other.surfaceRaised),
      border: mix(border, other.border),
      divider: mix(divider, other.divider),
      textPrimary: mix(textPrimary, other.textPrimary),
      textSecondary: mix(textSecondary, other.textSecondary),
      accent: mix(accent, other.accent),
      onAccent: mix(onAccent, other.onAccent),
      primaryAction: mix(primaryAction, other.primaryAction),
      onPrimaryAction: mix(onPrimaryAction, other.onPrimaryAction),
      warning: mix(warning, other.warning),
      success: mix(success, other.success),
      danger: mix(danger, other.danger),
    );
  }
}

abstract final class BrodieSpace {
  static const xxs = 4.0;
  static const xs = 8.0;
  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
}

abstract final class BrodieSize {
  static const radius = 4.0;
  static const border = 2.0;
  static const control = 60.0;
  static const controlCompact = 44.0;
  static const iconTile = 36.0;
  static const navBar = 72.0;
  static const borderRadius = BorderRadius.all(Radius.circular(radius));
}

abstract final class BrodieFonts {
  static const body = 'Inter';
  static const display = 'BarlowCondensed';
}

/// Type scale. Display styles are meant for uppercase strings; components
/// that use them uppercase their text (user-entered names excepted).
abstract final class BrodieType {
  static const screenTitle =
      TextStyle(fontFamily: BrodieFonts.display, fontWeight: FontWeight.w800, fontSize: 40, height: 1, letterSpacing: .8);
  static const headline =
      TextStyle(fontFamily: BrodieFonts.display, fontWeight: FontWeight.w800, fontSize: 30, height: 1, letterSpacing: .6);
  static const title =
      TextStyle(fontFamily: BrodieFonts.display, fontWeight: FontWeight.w800, fontSize: 22, height: 1.1, letterSpacing: .4);
  static const stat = TextStyle(fontFamily: BrodieFonts.display, fontWeight: FontWeight.w800, fontSize: 32, height: 1);
  static const button =
      TextStyle(fontFamily: BrodieFonts.display, fontWeight: FontWeight.w800, fontSize: 20, letterSpacing: 1.2);
  static const label =
      TextStyle(fontFamily: BrodieFonts.display, fontWeight: FontWeight.w700, fontSize: 14, letterSpacing: 1.7);
  static const navLabel =
      TextStyle(fontFamily: BrodieFonts.display, fontWeight: FontWeight.w700, fontSize: 13, letterSpacing: 1);
  static const body = TextStyle(fontFamily: BrodieFonts.body, fontWeight: FontWeight.w400, fontSize: 14, height: 1.35);
  static const bodyStrong =
      TextStyle(fontFamily: BrodieFonts.body, fontWeight: FontWeight.w600, fontSize: 14, height: 1.35);
  static const caption = TextStyle(fontFamily: BrodieFonts.body, fontWeight: FontWeight.w400, fontSize: 12, height: 1.3);
  static const overline =
      TextStyle(fontFamily: BrodieFonts.body, fontWeight: FontWeight.w700, fontSize: 10, letterSpacing: .8);
}
