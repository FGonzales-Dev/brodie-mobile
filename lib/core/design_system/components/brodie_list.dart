import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../tokens.dart';

/// Bordered group of rows separated by dividers.
class BrodieListGroup extends StatelessWidget {
  const BrodieListGroup({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BrodieSize.borderRadius,
        border: Border.all(color: colors.border, width: BrodieSize.border),
      ),
      child: Column(
        children: [
          for (final (index, child) in children.indexed) ...[if (index > 0) const Divider(), child],
        ],
      ),
    );
  }
}

/// A row in a [BrodieListGroup]. Shows a chevron when tappable and no
/// [trailing] is given. [destructive] colors the title for sign-out/delete.
class BrodieListTile extends StatelessWidget {
  const BrodieListTile({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.destructive = false,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final trailingWidget = trailing ?? (onTap != null ? Icon(Icons.chevron_right, color: colors.textSecondary) : null);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: BrodieSpace.sm),
        child: Row(
          children: [
            if (leading != null) ...[leading!, const SizedBox(width: BrodieSpace.sm)],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: BrodieType.bodyStrong.copyWith(color: destructive ? colors.danger : colors.textPrimary),
                  ),
                  if (subtitle != null)
                    Text(subtitle!, style: BrodieType.caption.copyWith(color: colors.textSecondary)),
                ],
              ),
            ),
            ?trailingWidget,
          ],
        ),
      ),
    );
  }
}

/// Edit + delete icon pair for rows in editable lists.
class EditDeleteActions extends StatelessWidget {
  const EditDeleteActions({super.key, required this.onEdit, required this.onDelete});

  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(tooltip: 'Edit', icon: const Icon(Icons.edit_outlined), onPressed: onEdit),
        IconButton(
          tooltip: 'Delete',
          icon: Icon(Icons.delete_outline, color: context.colors.danger),
          onPressed: onDelete,
        ),
      ],
    );
  }
}
