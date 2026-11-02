import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../tokens.dart';

/// Large uppercase title for the four tab-root screens.
class ScreenHeader extends StatelessWidget {
  const ScreenHeader({super.key, required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(BrodieSpace.md, BrodieSpace.xs, BrodieSpace.md, BrodieSpace.sm),
      child: Row(
        children: [
          Expanded(
            child: Text(title.toUpperCase(), style: BrodieType.screenTitle.copyWith(color: context.colors.textPrimary)),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// App bar for pushed (non-tab) screens.
class BrodieAppBar extends StatelessWidget implements PreferredSizeWidget {
  const BrodieAppBar({super.key, required this.title, this.actions});

  final String title;
  final List<Widget>? actions;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) => AppBar(title: Text(title.toUpperCase()), actions: actions);
}

/// Uppercase label above a group of content.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: BrodieSpace.lg, bottom: BrodieSpace.xs),
      child: Text(text.toUpperCase(), style: BrodieType.label.copyWith(color: context.colors.textSecondary)),
    );
  }
}

/// Square bordered icon button with an optional count badge. While
/// [isLoading] it shows a spinner and ignores taps.
class BrodieIconButton extends StatelessWidget {
  const BrodieIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.tooltip,
    this.badgeCount = 0,
    this.isLoading = false,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final String tooltip;
  final int badgeCount;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BrodieSize.borderRadius,
          side: BorderSide(color: colors.border, width: BrodieSize.border),
        ),
        child: InkWell(
          onTap: isLoading ? null : onPressed,
          customBorder: const RoundedRectangleBorder(borderRadius: BrodieSize.borderRadius),
          child: SizedBox.square(
            dimension: 44,
            child: isLoading
                ? const Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2.5))
                : Badge(
                    isLabelVisible: badgeCount > 0,
                    label: Text('$badgeCount'),
                    backgroundColor: colors.danger,
                    child: Icon(icon, color: colors.textPrimary),
                  ),
          ),
        ),
      ),
    );
  }
}
