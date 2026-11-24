import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../../../core/design_system/design_system.dart';
import '../../../core/presentation/feedback.dart';
import '../../../core/utils/units.dart';
import '../../settings/application/settings_controller.dart';
import '../../vehicles/domain/vehicle.dart';
import '../../vehicles/presentation/vehicles_screen.dart';
import '../application/ride_providers.dart';
import '../domain/ride.dart';
import 'ride_widgets.dart';

/// Past rides, newest first. Rides still waiting to upload are listed too,
/// so a ride finished out of signal shows up straight away.
class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    unawaited(ref.read(rideSyncProvider.notifier).uploadPending());
    try {
      ref.invalidate(rideHistoryControllerProvider);
      await ref.read(rideHistoryControllerProvider.future);
    } catch (_) {
      // Shown by the list.
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(rideSyncProvider);
    final history = ref.watch(rideHistoryControllerProvider);
    final vehicles = {for (final vehicle in ref.watch(vehiclesControllerProvider).value ?? <Vehicle>[]) vehicle.id: vehicle};

    final pendingIds = {for (final ride in pending) ride.id};
    final saved = [...?history.value?.rides.where((ride) => !pendingIds.contains(ride.id))];
    final loadFailed = history.hasError && !history.hasValue;

    final Widget body;
    if (pending.isEmpty && loadFailed) {
      body = ErrorState(error: history.error!, onRetry: () => ref.invalidate(rideHistoryControllerProvider));
    } else if (pending.isEmpty && !history.hasValue) {
      body = const LoadingState();
    } else if (pending.isEmpty && saved.isEmpty) {
      body = const EmptyState(
        icon: Icons.route_outlined,
        title: 'No rides yet',
        message: 'Rides you finish, solo or with a group, show up here.',
      );
    } else {
      body = RefreshIndicator(
        onRefresh: () => _refresh(ref),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(BrodieSpace.md, 0, BrodieSpace.md, BrodieSpace.md),
          children: [
            if (loadFailed)
              Padding(
                padding: const EdgeInsets.only(bottom: BrodieSpace.sm),
                child: Text(
                  "Couldn't load your saved rides. Pull down to try again.",
                  style: BrodieType.body.copyWith(color: context.colors.textSecondary),
                ),
              ),
            BrodieListGroup(
              children: [
                for (final ride in pending) _RideTile(ride: ride, vehicle: vehicles[ride.vehicleId], waiting: true),
                for (final ride in saved) _RideTile(ride: ride, vehicle: vehicles[ride.vehicleId]),
              ],
            ),
            if (history.value?.hasMore ?? false)
              Padding(
                padding: const EdgeInsets.only(top: BrodieSpace.sm),
                child: BrodieButton.secondary(
                  label: 'Show more',
                  isLoading: history.isLoading,
                  onPressed: () => context.runWithFeedback(
                    () => ref.read(rideHistoryControllerProvider.notifier).loadMore(),
                  ),
                ),
              ),
          ],
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const ScreenHeader(title: 'History'),
            Expanded(child: body),
          ],
        ),
      ),
    );
  }
}

class _RideTile extends ConsumerWidget {
  const _RideTile({required this.ride, this.vehicle, this.waiting = false});

  final Ride ride;
  final Vehicle? vehicle;
  final bool waiting;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final units = ref.watch(settingsControllerProvider.select((settings) => settings.units));
    final distance = formatDistance(ride.distanceMeters, units);
    final moving = formatDuration(ride.movingTime);
    final details = [
      if (ride.groupName case final group?) 'Group · $group' else if (ride.groupTripId != null) 'Group ride',
      rideStartLabel(context, ride),
      '${distance.value} ${distance.unit}',
      '${moving.value} ${moving.unit}',
      if (waiting) 'Waiting to upload',
    ];

    return BrodieListTile(
      leading: IconTile(
        icon: waiting
            ? Icons.cloud_upload_outlined
            : vehicle != null
                ? vehicleIcon(vehicle!.type)
                : (ride.groupTripId != null ? Icons.groups : Icons.route),
      ),
      title: rideTitle(ride),
      subtitle: details.join(' · '),
      onTap: () => context.push(Routes.rideDetail(ride.id)),
    );
  }
}
