import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../tokens.dart';

enum BrodieButtonVariant { primary, secondary, danger }

/// The one button used across the app: 60px tall (glove-friendly), uppercase
/// condensed label, optional icon and loading state.
class BrodieButton extends StatelessWidget {
  const BrodieButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.variant = BrodieButtonVariant.primary,
    this.isLoading = false,
    this.compact = false,
  });

  const BrodieButton.secondary({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.compact = false,
  }) : variant = BrodieButtonVariant.secondary;

  const BrodieButton.danger({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.compact = false,
  }) : variant = BrodieButtonVariant.danger;

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final BrodieButtonVariant variant;
  final bool isLoading;

  /// Shorter height for buttons placed inside cards and list rows.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final (background, foreground, border) = switch (variant) {
      BrodieButtonVariant.primary => (colors.primaryAction, colors.onPrimaryAction, colors.primaryAction),
      BrodieButtonVariant.secondary => (Colors.transparent, colors.textPrimary, colors.border),
      BrodieButtonVariant.danger => (colors.danger, Colors.white, colors.danger),
    };
    final enabled = onPressed != null && !isLoading;

    return Opacity(
      opacity: onPressed == null ? .45 : 1,
      child: Material(
        color: background,
        shape: RoundedRectangleBorder(
          borderRadius: BrodieSize.borderRadius,
          side: BorderSide(color: border, width: BrodieSize.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enabled ? onPressed : null,
          child: SizedBox(
            height: compact ? BrodieSize.controlCompact : BrodieSize.control,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: BrodieSpace.md),
              child: Center(
                child: isLoading
                    ? SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2.5, color: foreground),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (icon != null) ...[
                            Icon(icon, size: compact ? 18 : 22, color: foreground),
                            const SizedBox(width: BrodieSpace.xs),
                          ],
                          Flexible(
                            child: Text(
                              label.toUpperCase(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: BrodieType.button.copyWith(color: foreground, fontSize: compact ? 16 : 20),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
