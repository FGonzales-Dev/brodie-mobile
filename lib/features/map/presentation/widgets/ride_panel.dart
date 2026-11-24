import 'package:flutter/material.dart';

import '../../../../core/design_system/design_system.dart';

/// The bottom panel of the ride screens (solo and group): the stats and
/// buttons while riding, and the summary once the ride is over. [accent]
/// colors its top edge.
class RidePanel extends StatelessWidget {
  const RidePanel({super.key, required this.children, this.accent});

  final List<Widget> children;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: accent ?? colors.accent, width: 3)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(BrodieSpace.md),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
        ),
      ),
    );
  }
}
