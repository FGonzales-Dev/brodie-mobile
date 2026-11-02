import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../tokens.dart';

/// Bordered surface block. [highlighted] swaps the border to the accent.
class BrodieCard extends StatelessWidget {
  const BrodieCard({super.key, required this.child, this.onTap, this.highlighted = false, this.padding});

  final Widget child;
  final VoidCallback? onTap;
  final bool highlighted;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Material(
      color: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BrodieSize.borderRadius,
        side: BorderSide(color: highlighted ? colors.accent : colors.border, width: BrodieSize.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding ?? const EdgeInsets.all(BrodieSpace.md), child: child),
      ),
    );
  }
}

/// Square initial-letter avatar; the color is stable for a given [name].
class BrodieAvatar extends StatelessWidget {
  const BrodieAvatar({super.key, required this.name, this.size = 36, this.highlighted = false});

  final String name;
  final double size;

  /// Uses the accent color, for the signed-in user.
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final trimmed = name.trim();
    final palette = BrodieColors.avatarPalette;
    final background = highlighted ? colors.accent : palette[trimmed.hashCode.abs() % palette.length];
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(3)),
      child: Text(
        trimmed.isEmpty ? '?' : trimmed.characters.first.toUpperCase(),
        style: BrodieType.bodyStrong.copyWith(
          color: highlighted ? colors.onAccent : Colors.white,
          fontSize: size * .42,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Icon on a small raised square, used as a list-row leading element.
class IconTile extends StatelessWidget {
  const IconTile({super.key, required this.icon, this.color});

  final IconData icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      width: BrodieSize.iconTile,
      height: BrodieSize.iconTile,
      decoration: BoxDecoration(color: colors.surfaceRaised, borderRadius: BorderRadius.circular(3)),
      child: Icon(icon, size: 20, color: color ?? colors.textPrimary),
    );
  }
}

/// App logo: navigation arrow on an accent square.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 52});

  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: colors.accent, borderRadius: BrodieSize.borderRadius),
      child: Icon(Icons.navigation, size: size * .5, color: colors.onAccent),
    );
  }
}

/// Big number with a small uppercase unit, e.g. "64.2 / KM".
class StatTile extends StatelessWidget {
  const StatTile({super.key, required this.value, required this.unit});

  final String value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.fromLTRB(BrodieSpace.sm, 10, BrodieSpace.sm, 10),
      decoration: BoxDecoration(color: colors.surfaceRaised, borderRadius: BrodieSize.borderRadius),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FittedBox(child: Text(value, style: BrodieType.stat.copyWith(color: colors.textPrimary))),
          const SizedBox(height: 2),
          Text(unit.toUpperCase(), style: BrodieType.overline.copyWith(color: colors.textSecondary)),
        ],
      ),
    );
  }
}
