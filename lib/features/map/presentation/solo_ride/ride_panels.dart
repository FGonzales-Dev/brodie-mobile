import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design_system/design_system.dart';
import '../../../../core/presentation/time_labels.dart';
import '../../../../core/utils/units.dart';
import '../../../settings/application/settings_controller.dart';
import '../../domain/route_rejoin.dart';
import '../widgets/maneuver_icon.dart';
import '../widgets/ride_panel.dart';
import 'solo_ride_controller.dart';

/// Next turn at the top of the ride screen: arrow, distance and instruction.
/// Also shows rerouting, waiting for GPS, and notices such as a reached limit.
class ManeuverBanner extends ConsumerWidget {
  const ManeuverBanner({super.key, required this.ride});

  final SoloRideState ride;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final units = ref.watch(settingsControllerProvider.select((settings) => settings.units));
    final progress = ride.progress;
    final maneuver = progress?.nextManeuver;

    final (Widget leading, String title, String? detail) = switch (ride) {
      SoloRideState(rerouting: true) => (
        SizedBox.square(dimension: 36, child: CircularProgressIndicator(color: colors.onPrimaryAction)),
        'Rerouting…',
        'Finding a new route from where you are',
      ),
      _ when progress == null => (
        Icon(Icons.location_searching, size: 40, color: colors.onPrimaryAction),
        'Waiting for GPS…',
        null,
      ),
      _ when maneuver == null => (
        Icon(Icons.sports_score, size: 40, color: colors.onPrimaryAction),
        'Almost there',
        ride.destination.name,
      ),
      _ => (
        Icon(maneuverIcon(maneuver), size: 44, color: colors.onPrimaryAction),
        formatShortDistance(progress.distanceToManeuverMeters!, units).text,
        maneuver.instruction,
      ),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(BrodieSpace.md),
          decoration: BoxDecoration(color: colors.primaryAction, borderRadius: BrodieSize.borderRadius),
          child: Row(
            children: [
              leading,
              const SizedBox(width: BrodieSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title.toUpperCase(), style: BrodieType.headline.copyWith(color: colors.onPrimaryAction)),
                    if (detail != null)
                      Text(detail, style: BrodieType.bodyStrong.copyWith(color: colors.onPrimaryAction, fontSize: 15)),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (ride.notice case final notice?)
          BrodieAlert(icon: Icons.info_outline, color: colors.warning, message: notice),
      ],
    );
  }
}

/// Speed, distance left and arrival time, with the Reroute and End buttons.
class RideHud extends ConsumerWidget {
  const RideHud({super.key, required this.ride, required this.onEnd, required this.onReroute});

  final SoloRideState ride;
  final VoidCallback onEnd;
  final VoidCallback onReroute;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final units = ref.watch(settingsControllerProvider.select((settings) => settings.units));
    final progress = ride.progress;
    final speed = formatSpeed(ride.lastFix?.speedMps ?? 0, units);
    final remaining = formatDistance(progress?.distanceRemainingMeters ?? ride.route.distanceMeters, units);
    final arrival = progress == null ? '--' : clockLabel(context, DateTime.now().add(progress.timeRemaining));
    // Highlighted only once the rider has stayed well off the route, so a
    // detour or a wobbly GPS doesn't push them into a billed request.
    final suggestReroute = RouteRejoin.suggestReroute(farOffSince: ride.farOffRouteSince, now: DateTime.now());

    return RidePanel(
      children: [
        Row(
          children: [
            Expanded(
              child: StatTile(value: speed.value, unit: speed.unit),
            ),
            const SizedBox(width: BrodieSpace.xs),
            Expanded(
              child: StatTile(value: remaining.value, unit: '${remaining.unit} left'),
            ),
            const SizedBox(width: BrodieSpace.xs),
            Expanded(
              child: StatTile(value: arrival, unit: 'arrive'),
            ),
          ],
        ),
        const SizedBox(height: BrodieSpace.sm),
        Row(
          children: [
            Expanded(
              child: BrodieButton(
                label: 'Reroute',
                icon: Icons.alt_route,
                variant: suggestReroute ? BrodieButtonVariant.primary : BrodieButtonVariant.secondary,
                isLoading: ride.rerouting,
                // Needs a position to route from.
                onPressed: ride.lastFix == null ? null : onReroute,
              ),
            ),
            const SizedBox(width: BrodieSpace.sm),
            Expanded(
              child: BrodieButton.secondary(label: 'End ride', icon: Icons.stop, onPressed: onEnd),
            ),
          ],
        ),
      ],
    );
  }
}

/// Replaces the HUD once the rider reaches the destination.
class ArrivalPanel extends ConsumerWidget {
  const ArrivalPanel({super.key, required this.ride, required this.onDone});

  final SoloRideState ride;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final units = ref.watch(settingsControllerProvider.select((settings) => settings.units));
    final arrivedAt = ride.arrivedAt!;
    final ridden = formatDistance(ride.distanceRiddenMeters, units);
    final rideTime = formatDuration(arrivedAt.difference(ride.startedAt));

    return RidePanel(
      accent: colors.success,
      children: [
        Row(
          children: [
            Icon(Icons.sports_score, size: 40, color: colors.success),
            const SizedBox(width: BrodieSpace.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("YOU'VE ARRIVED", style: BrodieType.headline.copyWith(color: colors.textPrimary)),
                  Text(ride.destination.name, style: BrodieType.body.copyWith(color: colors.textSecondary)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: BrodieSpace.md),
        Row(
          children: [
            Expanded(
              child: StatTile(value: ridden.value, unit: '${ridden.unit} ridden'),
            ),
            const SizedBox(width: BrodieSpace.xs),
            Expanded(
              child: StatTile(value: rideTime.value, unit: rideTime.unit),
            ),
            const SizedBox(width: BrodieSpace.xs),
            Expanded(
              child: StatTile(value: clockLabel(context, arrivedAt), unit: 'arrived'),
            ),
          ],
        ),
        const SizedBox(height: BrodieSpace.sm),
        BrodieButton(label: 'Done', icon: Icons.check, onPressed: onDone),
      ],
    );
  }
}
