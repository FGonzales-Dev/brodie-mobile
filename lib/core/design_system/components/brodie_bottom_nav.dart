import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../tokens.dart';

class BrodieNavItem {
  const BrodieNavItem({required this.icon, required this.label});

  final IconData icon;
  final String label;
}

/// Full-width tab bar; the selected tab is a solid accent block.
class BrodieBottomNav extends StatelessWidget {
  const BrodieBottomNav({super.key, required this.items, required this.currentIndex, required this.onSelected});

  final List<BrodieNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.border, width: BrodieSize.border)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: BrodieSize.navBar,
          child: Row(
            children: [
              for (final (index, item) in items.indexed)
                Expanded(child: _NavTab(item: item, selected: index == currentIndex, onTap: () => onSelected(index))),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavTab extends StatelessWidget {
  const _NavTab({required this.item, required this.selected, required this.onTap});

  final BrodieNavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final foreground = selected ? colors.onAccent : colors.textSecondary;
    return Semantics(
      selected: selected,
      button: true,
      label: item.label,
      excludeSemantics: true,
      child: Material(
        color: selected ? colors.accent : Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(item.icon, color: foreground),
              const SizedBox(height: BrodieSpace.xxs),
              Text(item.label.toUpperCase(), style: BrodieType.navLabel.copyWith(color: foreground)),
            ],
          ),
        ),
      ),
    );
  }
}
