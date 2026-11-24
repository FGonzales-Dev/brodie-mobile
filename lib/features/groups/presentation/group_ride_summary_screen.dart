import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design_system/design_system.dart';
import '../../../core/utils/text.dart';
import '../../../core/utils/units.dart';
import '../../auth/application/session_providers.dart';
import '../../map/presentation/widgets/route_overview_map.dart';
import '../../settings/application/settings_controller.dart';
import '../application/group_providers.dart';
import '../domain/group_models.dart';

/// Date and start time of a group ride, e.g. "Sat, Nov 2 · 8:04 AM".
String groupRideStartLabel(BuildContext context, DateTime startedAt) {
  final localizations = MaterialLocalizations.of(context);
  final time = localizations.formatTimeOfDay(TimeOfDay.fromDateTime(startedAt));
  return '${localizations.formatMediumDate(startedAt)} · $time';
}

/// A finished group ride: the route the group planned, how long it took,
/// and how far each rider went (from their own saved ride).
class GroupRideSummaryScreen extends ConsumerWidget {
  const GroupRideSummaryScreen({super.key, required this.tripId});

  final String tripId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(groupRideDetailProvider(tripId));
    return Scaffold(
      appBar: BrodieAppBar(title: detail.value?.ride.groupName ?? 'Group ride'),
      body: AsyncValueView(
        value: detail,
        onRetry: () => ref.invalidate(groupRideDetailProvider(tripId)),
        data: (detail) => RefreshIndicator(
          onRefresh: () => ref.refresh(groupRideDetailProvider(tripId).future),
          child: _Summary(detail: detail),
        ),
      ),
    );
  }
}

class _Summary extends ConsumerWidget {
  const _Summary({required this.detail});

  final GroupRideDetail detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final units = ref.watch(settingsControllerProvider.select((settings) => settings.units));
    final me = ref.watch(currentUserProvider)?.id;
    final (:ride, :riders) = detail;
    final planned = formatDistance(ride.plannedDistanceMeters, units);
    final endedAt = ride.endedAt;
    final rideTime = endedAt == null ? null : formatDuration(endedAt.difference(ride.startedAt));
    final leader = ride.leaderUsername;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        if (ride.route.length >= 2) SizedBox(height: 220, child: RouteOverviewMap(path: ride.route)),
        Padding(
          padding: const EdgeInsets.all(BrodieSpace.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                (ride.name ?? 'Group ride').toUpperCase(),
                style: BrodieType.headline.copyWith(color: colors.textPrimary),
              ),
              const SizedBox(height: BrodieSpace.xxs),
              Text(
                [groupRideStartLabel(context, ride.startedAt), if (leader != null) 'Led by @$leader'].join(' · '),
                style: BrodieType.body.copyWith(color: colors.textSecondary),
              ),
              const SizedBox(height: BrodieSpace.md),
              Row(
                children: [
                  Expanded(child: StatTile(value: planned.value, unit: '${planned.unit} route')),
                  const SizedBox(width: BrodieSpace.xs),
                  Expanded(child: StatTile(value: rideTime?.value ?? '--', unit: rideTime?.unit ?? 'ride time')),
                  const SizedBox(width: BrodieSpace.xs),
                  Expanded(child: StatTile(value: '${riders.length}', unit: riders.length == 1 ? 'rider' : 'riders')),
                ],
              ),
              SectionLabel('Riders (${riders.length})'),
              BrodieListGroup(
                children: [
                  for (final rider in riders)
                    BrodieListTile(
                      leading: BrodieAvatar(name: rider.username ?? '?', highlighted: rider.userId == me),
                      title: [
                        '@${rider.username ?? 'rider'}',
                        if (rider.isLeader) 'Leader',
                        if (rider.userId == me) 'You',
                      ].join(' · '),
                      subtitle: _riderLine(rider, units),
                    ),
                ],
              ),
              const SizedBox(height: BrodieSpace.sm),
              Text(
                "Distances come from each rider's own saved ride. Riders' routes stay private.",
                style: BrodieType.caption.copyWith(color: colors.textSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static String _riderLine(GroupRideRider rider, DistanceUnit units) {
    final distance = rider.distanceMeters;
    if (distance == null) return rider.leftEarly ? 'Left early · no ride saved' : 'No ride saved';
    final ridden = formatDistance(distance, units);
    final moving = rider.movingTime;
    final top = rider.maxSpeedMps;
    return [
      '${ridden.value} ${ridden.unit}',
      if (moving != null) '${formatDuration(moving).value} ${formatDuration(moving).unit} moving',
      if (top != null && top > 0) 'top ${formatSpeed(top, units).value} ${formatSpeed(top, units).unit}',
      if (rider.leftEarly) 'left early' else if (rider.arrived == true) 'arrived',
    ].join(' · ');
  }
}

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
                    groupRideStartLabel(context, ride.startedAt),
                    countLabel(ride.riderCount, 'rider'),
                    switch (formatDistance(ride.plannedDistanceMeters, units)) {
                      final distance => '${distance.value} ${distance.unit}',
                    },
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
