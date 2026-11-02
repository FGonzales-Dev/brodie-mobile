import 'package:flutter/material.dart';

import '../../../../core/design_system/design_system.dart';

/// Tap target that opens destination search, floating over the map.
class MapSearchBar extends StatelessWidget {
  const MapSearchBar({super.key, required this.onTap, required this.avatarName});

  final VoidCallback onTap;
  final String avatarName;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Material(
      color: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BrodieSize.borderRadius,
        side: BorderSide(color: colors.border, width: BrodieSize.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 56,
          child: Row(
            children: [
              const SizedBox(width: BrodieSpace.md),
              Icon(Icons.search, color: colors.textSecondary),
              const SizedBox(width: BrodieSpace.sm),
              Expanded(
                child: Text('Where to?', style: BrodieType.body.copyWith(fontSize: 16, color: colors.textSecondary)),
              ),
              BrodieAvatar(name: avatarName, size: 36, highlighted: true),
              const SizedBox(width: 10),
            ],
          ),
        ),
      ),
    );
  }
}
