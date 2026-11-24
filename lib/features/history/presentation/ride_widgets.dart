import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design_system/design_system.dart';
import '../../../core/utils/units.dart';
import '../../settings/application/settings_controller.dart';
import '../domain/ride.dart';

String rideTitle(Ride ride) => ride.destinationName ?? 'Ride';

/// Distance and moving time, then average and top speed.
class RideStats extends ConsumerWidget {
  const RideStats({super.key, required this.ride});

  final Ride ride;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final units = ref.watch(settingsControllerProvider.select((settings) => settings.units));
    final distance = formatDistance(ride.distanceMeters, units);
    final moving = formatDuration(ride.movingTime);
    final average = formatSpeed(ride.averageSpeedMps, units);
    final top = formatSpeed(ride.maxSpeedMps, units);

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: StatTile(value: distance.value, unit: distance.unit),
            ),
            const SizedBox(width: BrodieSpace.xs),
            Expanded(
              child: StatTile(value: moving.value, unit: '${moving.unit} moving'),
            ),
          ],
        ),
        const SizedBox(height: BrodieSpace.xs),
        Row(
          children: [
            Expanded(
              child: StatTile(value: average.value, unit: 'avg ${average.unit}'),
            ),
            const SizedBox(width: BrodieSpace.xs),
            Expanded(
              child: StatTile(value: top.value, unit: 'top ${top.unit}'),
            ),
          ],
        ),
      ],
    );
  }
}
