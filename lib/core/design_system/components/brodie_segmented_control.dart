import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../tokens.dart';

/// Row of equal-width options; the selected one is filled. Replaces radio
/// lists for small fixed choices (theme, units, vehicle type).
class BrodieSegmentedControl<T> extends StatelessWidget {
  const BrodieSegmentedControl({super.key, required this.options, required this.selected, required this.onChanged});

  final List<(T, String)> options;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BrodieSize.borderRadius,
        border: Border.all(color: colors.border, width: BrodieSize.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          for (final (value, label) in options)
            Expanded(
              child: Semantics(
                selected: value == selected,
                button: true,
                child: Material(
                  color: value == selected ? colors.primaryAction : colors.surface,
                  child: InkWell(
                    onTap: () => onChanged(value),
                    child: SizedBox(
                      height: 48,
                      child: Center(
                        child: Text(
                          label.toUpperCase(),
                          style: BrodieType.navLabel.copyWith(
                            fontSize: 15,
                            color: value == selected ? colors.onPrimaryAction : colors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
