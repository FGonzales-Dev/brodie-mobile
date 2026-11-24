import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design_system/design_system.dart';
import '../../../../core/presentation/time_labels.dart';
import '../../../../core/utils/text.dart';
import '../../../../core/utils/units.dart';
import '../../../settings/application/settings_controller.dart';
import '../../application/group_providers.dart';
import '../../domain/group_models.dart';

/// The group's finished rides, newest first, on the group screen. Shows
/// nothing until the group has one.
class PastGroupRides extends ConsumerWidget {
  const PastGroupRides({super.key, required this.groupId, required this.onOpen});

  final String groupId;
  final ValueChanged<PastGroupRide> onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rides = ref.watch(groupRideHistoryProvider(groupId)).value ?? const [];
    if (rides.isEmpty) return const SizedBox.shrink();
    final units = ref.watch(settingsControllerProvider.select((settings) => settings.units));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: BrodieSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionLabel('Past rides'),
          BrodieListGroup(
            children: [
              for (final ride in rides)
                BrodieListTile(
                  leading: const IconTile(icon: Icons.sports_score),
                  title: ride.name ?? 'Group ride',
                  subtitle: [
                    dateTimeLabel(context, ride.startedAt),
                    countLabel(ride.riderCount, 'rider'),
                    formatDistance(ride.plannedDistanceMeters, units).text,
                    if (ride.myRideId == null) "you didn't ride",
                  ].join(' · '),
                  onTap: () => onOpen(ride),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
