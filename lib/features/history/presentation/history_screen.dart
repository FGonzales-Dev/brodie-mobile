import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../../../core/design_system/design_system.dart';
import '../../../core/presentation/feedback.dart';
import '../../../core/presentation/time_labels.dart';
import '../../../core/utils/units.dart';
import '../../settings/application/settings_controller.dart';
import '../../vehicles/application/vehicle_providers.dart';
import '../../vehicles/domain/vehicle.dart';
import '../../vehicles/presentation/widgets/vehicle_icon.dart';
import '../application/ride_providers.dart';
import '../domain/ride.dart';
import '../domain/ride_filter.dart';
import 'ride_widgets.dart';
import 'widgets/history_filters.dart';

/// Past rides, filtered by kind, period and vehicle and sorted as the rider
/// chooses (newest first by default), with totals for what matches. Rides
/// still waiting to upload are listed first, so a ride finished out of
/// signal shows up straight away.
class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    unawaited(ref.read(rideSyncProvider.notifier).uploadPending());
    try {
      ref
        ..invalidate(rideHistoryControllerProvider)
        ..invalidate(rideHistoryTotalsProvider);
      await ref.read(rideHistoryControllerProvider.future);
    } catch (_) {
      // Shown by the list.
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(rideFilterControllerProvider);
    final now = DateTime.now();
    final allPending = ref.watch(rideSyncProvider);
    final pending = allPending.where((ride) => filter.matches(ride, now)).toList()..sort(filter.compare);
    final history = ref.watch(rideHistoryControllerProvider);
    final vehicleList = ref.watch(vehiclesControllerProvider).value ?? <Vehicle>[];
    final vehicles = {for (final vehicle in vehicleList) vehicle.id: vehicle};

    final pendingIds = {for (final ride in allPending) ride.id};
    final saved = [...?history.value?.rides.where((ride) => !pendingIds.contains(ride.id))];
    final loadFailed = history.hasError && !history.hasValue;
    final filtered = filter.activeCount > 0;

    final Widget body;
    if (pending.isEmpty && loadFailed) {
      body = ErrorState(error: history.error!, onRetry: () => ref.invalidate(rideHistoryControllerProvider));
    } else if (pending.isEmpty && !history.hasValue) {
      body = const LoadingState();
    } else if (pending.isEmpty && saved.isEmpty) {
      body = filtered
          ? EmptyState(
              icon: Icons.filter_alt_off_outlined,
              title: 'No rides match',
              message: 'Try another period, kind or vehicle.',
              action: BrodieButton.secondary(
                label: 'Clear filters',
                onPressed: ref.read(rideFilterControllerProvider.notifier).clear,
              ),
            )
          : const EmptyState(
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
            ScreenHeader(
              title: 'History',
              trailing: BrodieIconButton(
                icon: Icons.tune,
                tooltip: 'Filter and sort',
                badgeCount: filter.activeCount - (filter.kind == RideKind.all ? 0 : 1) + (filter.sort == RideSort.newest ? 0 : 1),
                onPressed: () => _showFilters(context, vehicleList),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(BrodieSpace.md, 0, BrodieSpace.md, BrodieSpace.xs),
              child: BrodieSegmentedControl<RideKind>(
                options: [for (final kind in RideKind.values) (kind, kind.label)],
                selected: filter.kind,
                onChanged: (kind) => ref.read(rideFilterControllerProvider.notifier).update((f) => f.copyWith(kind: kind)),
              ),
            ),
            const HistoryTotalsLine(),
            Expanded(child: body),
          ],
        ),
      ),
    );
  }

  void _showFilters(BuildContext context, List<Vehicle> vehicles) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => HistoryFilterSheet(vehicles: vehicles),
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
      dateTimeLabel(context, ride.startedAt),
      distance.text,
      moving.text,
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
