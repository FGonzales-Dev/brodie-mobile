import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design_system/design_system.dart';
import '../../../core/utils/units.dart';
import '../../settings/application/settings_controller.dart';
import '../application/group_ride_controller.dart';
import '../domain/group_ride_models.dart';
import 'rider_markers.dart';

String _clockAt(BuildContext context, DateTime time) =>
    MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(time));

/// Top of the ride screen: the ride, who's online, and anyone who fell behind.
class GroupRideBanner extends StatelessWidget {
  const GroupRideBanner({super.key, required this.ride});

  final GroupRideState ride;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final total = ride.others.length + 1;
    final online = ride.others.where((other) => other.online).length + (ride.connected ? 1 : 0);
    final subtitle = ride.connected ? '$online of $total riders online' : 'Connecting to your group…';
    final behind = ride.behind;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(BrodieSpace.md),
          decoration: BoxDecoration(color: colors.primaryAction, borderRadius: BrodieSize.borderRadius),
          child: Row(
            children: [
              Icon(Icons.groups, size: 40, color: colors.onPrimaryAction),
              const SizedBox(width: BrodieSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (ride.trip.name ?? 'Group ride').toUpperCase(),
                      style: BrodieType.headline.copyWith(color: colors.onPrimaryAction),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(subtitle, style: BrodieType.bodyStrong.copyWith(color: colors.onPrimaryAction, fontSize: 15)),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (behind.isNotEmpty) _BehindAlert(riders: behind),
      ],
    );
  }
}

class _BehindAlert extends ConsumerWidget {
  const _BehindAlert({required this.riders});

  final List<LiveRider> riders;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final units = ref.watch(settingsControllerProvider.select((settings) => settings.units));
    final lines = [
      for (final rider in riders.take(2))
        switch (rider.metersBehindMe) {
          final double gap when gap > 0 && rider.status == RiderStatus.live =>
            '@${rider.rider.username ?? 'rider'} fell behind · ${_distance(gap, units)} back',
          _ when rider.status != RiderStatus.live => "@${rider.rider.username ?? 'rider'} hasn't been heard from",
          _ => '@${rider.rider.username ?? 'rider'} fell behind',
        },
      if (riders.length > 2) 'and ${riders.length - 2} more',
    ];

    return Container(
      margin: const EdgeInsets.only(top: BrodieSpace.xs),
      padding: const EdgeInsets.all(BrodieSpace.sm),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BrodieSize.borderRadius,
        border: Border.all(color: colors.danger, width: BrodieSize.border),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: colors.danger),
          const SizedBox(width: BrodieSpace.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final line in lines) Text(line, style: BrodieType.bodyStrong.copyWith(color: colors.textPrimary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _distance(double meters, DistanceUnit units) {
  final distance = formatShortDistance(meters, units);
  return '${distance.value} ${distance.unit}';
}

/// The other riders, side by side; tapping one moves the map to them.
class RiderStrip extends ConsumerWidget {
  const RiderStrip({super.key, required this.riders, required this.onTap});

  final List<LiveRider> riders;
  final ValueChanged<LiveRider> onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final units = ref.watch(settingsControllerProvider.select((settings) => settings.units));
    if (riders.isEmpty) {
      return Text(
        'Nobody else has joined yet.',
        style: BrodieType.body.copyWith(color: context.colors.textSecondary),
      );
    }
    return SizedBox(
      height: 56,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: riders.length,
        separatorBuilder: (_, _) => const SizedBox(width: BrodieSpace.xs),
        itemBuilder: (context, index) => _RiderChip(rider: riders[index], units: units, onTap: onTap),
      ),
    );
  }
}

class _RiderChip extends StatelessWidget {
  const _RiderChip({required this.rider, required this.units, required this.onTap});

  final LiveRider rider;
  final DistanceUnit units;
  final ValueChanged<LiveRider> onTap;

  String get _detail {
    if (rider.fix == null) return rider.online ? 'Online · no position yet' : 'Not connected';
    if (rider.status != RiderStatus.live) return 'Last seen a while ago';
    return switch (rider.metersBehindMe) {
      final double gap when gap.abs() < 100 => 'With you',
      final double gap when gap > 0 => '${_distance(gap, units)} behind',
      final double gap => '${_distance(-gap, units)} ahead',
      null => '${rider.fix!.speedKmh} km/h',
    };
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final name = rider.rider.username ?? 'rider';
    return Material(
      color: colors.surfaceRaised,
      shape: RoundedRectangleBorder(
        borderRadius: BrodieSize.borderRadius,
        side: BorderSide(color: rider.behind ? colors.danger : colors.border, width: BrodieSize.border),
      ),
      child: InkWell(
        onTap: rider.fix == null ? null : () => onTap(rider),
        borderRadius: BrodieSize.borderRadius,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: BrodieSpace.sm),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(color: RiderMarkers.colorFor(rider, colors), shape: BoxShape.circle),
              ),
              const SizedBox(width: BrodieSpace.xs),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    rider.rider.isLeader ? '@$name · Leader' : '@$name',
                    style: BrodieType.bodyStrong.copyWith(color: colors.textPrimary),
                  ),
                  Text(_detail, style: BrodieType.caption.copyWith(color: colors.textSecondary)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Speed, distance left and arrival, the rider strip, and End / Leave.
class GroupRideHud extends ConsumerWidget {
  const GroupRideHud({
    super.key,
    required this.ride,
    required this.busy,
    required this.onRiderTap,
    required this.onEndOrLeave,
  });

  final GroupRideState ride;
  final bool busy;
  final ValueChanged<LiveRider> onRiderTap;
  final VoidCallback onEndOrLeave;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final units = ref.watch(settingsControllerProvider.select((settings) => settings.units));
    final progress = ride.progress;
    final speed = formatSpeed(ride.lastFix?.speedMps ?? 0, units);
    final remaining = formatDistance(progress?.distanceRemainingMeters ?? ride.trip.route.distanceMeters, units);
    final arrival = progress == null ? '--' : _clockAt(context, DateTime.now().add(progress.timeRemaining));

    return RidePanel(
      children: [
        RiderStrip(riders: ride.others, onTap: onRiderTap),
        const SizedBox(height: BrodieSpace.sm),
        Row(
          children: [
            Expanded(child: StatTile(value: speed.value, unit: speed.unit)),
            const SizedBox(width: BrodieSpace.xs),
            Expanded(child: StatTile(value: remaining.value, unit: '${remaining.unit} left')),
            const SizedBox(width: BrodieSpace.xs),
            Expanded(child: StatTile(value: arrival, unit: 'arrive')),
          ],
        ),
        const SizedBox(height: BrodieSpace.sm),
        ride.isLeader
            ? BrodieButton.secondary(label: 'End ride for everyone', icon: Icons.stop, isLoading: busy, onPressed: onEndOrLeave)
            : BrodieButton.secondary(label: 'Leave ride', icon: Icons.logout, isLoading: busy, onPressed: onEndOrLeave),
      ],
    );
  }
}

/// Replaces the HUD once the ride is over on this phone.
class GroupRideEndedPanel extends ConsumerWidget {
  const GroupRideEndedPanel({super.key, required this.ride, required this.onDone});

  final GroupRideState ride;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final units = ref.watch(settingsControllerProvider.select((settings) => settings.units));
    final endedAt = ride.endedAt ?? DateTime.now();
    final ridden = formatDistance(ride.distanceRiddenMeters, units);
    final rideTime = formatDuration(endedAt.difference(ride.startedAt));
    final title = switch (ride.end) {
      GroupRideEnd.left => 'YOU LEFT THE RIDE',
      _ when ride.isLeader => 'RIDE ENDED',
      _ => 'YOUR LEADER ENDED THE RIDE',
    };

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
                  Text(title, style: BrodieType.headline.copyWith(color: colors.textPrimary)),
                  Text(ride.trip.name ?? 'Group ride', style: BrodieType.body.copyWith(color: colors.textSecondary)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: BrodieSpace.md),
        Row(
          children: [
            Expanded(child: StatTile(value: ridden.value, unit: '${ridden.unit} ridden')),
            const SizedBox(width: BrodieSpace.xs),
            Expanded(child: StatTile(value: rideTime.value, unit: rideTime.unit)),
            const SizedBox(width: BrodieSpace.xs),
            Expanded(child: StatTile(value: _clockAt(context, endedAt), unit: 'ended')),
          ],
        ),
        const SizedBox(height: BrodieSpace.sm),
        BrodieButton(label: 'Done', icon: Icons.check, onPressed: onDone),
      ],
    );
  }
}

/// The bottom panel shared by the HUD and the ended panel.
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
