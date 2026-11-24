import 'package:flutter/material.dart';

import '../../../../core/design_system/design_system.dart';

/// The row above a ride screen's bottom panel: [leading] on the left (the
/// SOS button), and "Follow me" on the right once the rider has moved the
/// map away from themselves.
class RideMapButtons extends StatelessWidget {
  const RideMapButtons({super.key, this.leading, required this.following, required this.onFollow});

  final Widget? leading;
  final bool following;
  final VoidCallback onFollow;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(BrodieSpace.md),
      child: Row(
        children: [
          ?leading,
          const Spacer(),
          if (!following) BrodieIconButton(icon: Icons.navigation, tooltip: 'Follow me', onPressed: onFollow),
        ],
      ),
    );
  }
}
