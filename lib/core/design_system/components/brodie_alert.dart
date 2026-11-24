import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../tokens.dart';

/// A short status message: an icon in [color], an optional [title], the
/// [message], and an optional button at the end. Bordered in [color] on the
/// surface by default; [filled] paints it in [color] instead, for alerts that
/// must stand out (an SOS). Used for ride alerts, notices and confirmations.
class BrodieAlert extends StatelessWidget {
  const BrodieAlert({
    super.key,
    required this.icon,
    required this.color,
    this.title,
    required this.message,
    this.action,
    this.filled = false,
    this.margin = const EdgeInsets.only(top: BrodieSpace.xs),
  });

  final IconData icon;
  final Color color;
  final String? title;
  final String message;

  /// A button's label and what it does.
  final (String label, VoidCallback onPressed)? action;
  final bool filled;
  final EdgeInsetsGeometry margin;

  /// Text on a filled alert; the alert colors are all dark enough for white.
  static const _onFilled = Color(0xFFFFFFFF);

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final strong = filled ? _onFilled : colors.textPrimary;
    final soft = filled ? _onFilled : colors.textSecondary;
    final title = this.title;
    return Semantics(
      liveRegion: true,
      child: Container(
        margin: margin,
        padding: const EdgeInsets.all(BrodieSpace.sm),
        decoration: BoxDecoration(
          color: filled ? color : colors.surface,
          borderRadius: BrodieSize.borderRadius,
          border: filled ? null : Border.all(color: color, width: BrodieSize.border),
        ),
        child: Row(
          children: [
            Icon(icon, color: filled ? _onFilled : color, size: filled ? 32 : 24),
            const SizedBox(width: BrodieSpace.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (title != null)
                    Text(
                      filled ? title.toUpperCase() : title,
                      style: filled
                          ? BrodieType.headline.copyWith(color: strong, fontSize: 20)
                          : BrodieType.bodyStrong.copyWith(color: strong),
                    ),
                  Text(
                    message,
                    // Alone, the message is the headline; under a title it's the detail.
                    style: title == null
                        ? BrodieType.bodyStrong.copyWith(color: strong)
                        : (filled ? BrodieType.bodyStrong : BrodieType.caption).copyWith(color: soft),
                  ),
                ],
              ),
            ),
            if (action case (final label, final onPressed))
              TextButton(
                onPressed: onPressed,
                style: filled ? TextButton.styleFrom(foregroundColor: _onFilled) : null,
                child: Text(label),
              ),
          ],
        ),
      ),
    );
  }
}
