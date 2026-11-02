import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design_system/design_system.dart';
import '../../application/location_access_controller.dart';
import '../../application/my_location_providers.dart';

/// Shown under the search bar while the first position is being fetched, and
/// when fetching fails (the fix request times out after ~15 s), with a link
/// to the location settings.
class LocationStatusChip extends ConsumerWidget {
  const LocationStatusChip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = ref.watch(myLocationControllerProvider);
    final failed = location.hasError && !location.isLoading;
    if (!failed && location.hasValue) return const SizedBox.shrink();

    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
      constraints: const BoxConstraints(minHeight: 44),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BrodieSize.borderRadius,
        border: Border.all(color: failed ? colors.warning : colors.border, width: BrodieSize.border),
      ),
      child: Row(
        children: [
          if (failed)
            Icon(Icons.location_searching, color: colors.warning)
          else
            const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2)),
          const SizedBox(width: BrodieSpace.sm),
          Expanded(
            child: Text(
              failed
                  ? "Couldn't get your location. Indoors GPS can take a while; Wi-Fi-assisted location helps."
                  : 'Finding your location…',
              style: BrodieType.body.copyWith(color: colors.textPrimary),
            ),
          ),
          if (failed)
            TextButton(
              onPressed: () => ref.read(locationAccessControllerProvider.notifier).openLocationSettings(),
              child: const Text('Settings'),
            ),
        ],
      ),
    );
  }
}
