import 'package:flutter/material.dart';

import '../../../../core/design_system/design_system.dart';

/// The SOS button on the ride screens: red, labelled, and big enough to hit
/// with gloves. It only opens the countdown, so a mis-tap can be cancelled.
class SosButton extends StatelessWidget {
  const SosButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      button: true,
      label: 'SOS. Opens a countdown before alerting anyone.',
      child: Material(
        color: colors.danger,
        shape: const CircleBorder(side: BorderSide(color: Color(0xFFFFFFFF), width: 3)),
        elevation: 4,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox.square(
            dimension: 64,
            child: Center(
              child: Text('SOS', style: BrodieType.stat.copyWith(color: const Color(0xFFFFFFFF), fontSize: 22)),
            ),
          ),
        ),
      ),
    );
  }
}
