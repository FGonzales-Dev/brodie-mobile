import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design_system/design_system.dart';
import '../../../core/presentation/feedback.dart';
import '../../vehicles/domain/vehicle.dart';
import '../../vehicles/presentation/vehicles_screen.dart';
import '../application/ride_providers.dart';
import '../domain/ride.dart';
import 'ride_widgets.dart';

/// One ride: the route ridden, its stats and vehicle. Also the summary shown
/// straight after a ride ends ([justFinished]), with a Done button back to
/// the map.
class RideDetailScreen extends ConsumerWidget {
  const RideDetailScreen({super.key, required this.rideId, this.justFinished = false});

  final String rideId;
  final bool justFinished;

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showBrodieConfirmDialog(
      context,
      title: 'Delete ride?',
      message: 'Remove this ride from your history. This cannot be undone.',
      confirmLabel: 'Delete',
    );
    if (!confirmed || !context.mounted) return;
    final deleted = await context.runWithFeedback(
      () => ref.read(rideSyncProvider.notifier).delete(rideId),
      successMessage: 'Ride deleted',
    );
    if (deleted && context.mounted) context.pop();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ride = ref.watch(rideDetailProvider(rideId));
    return Scaffold(
      appBar: BrodieAppBar(
        title: justFinished ? 'Ride summary' : 'Ride',
        actions: [
          if (ride.hasValue)
            IconButton(
              tooltip: 'Delete ride',
              icon: Icon(Icons.delete_outline, color: context.colors.danger),
              onPressed: () => _delete(context, ref),
            ),
        ],
      ),
      body: AsyncValueView(
        value: ride,
        onRetry: () => ref.invalidate(rideDetailProvider(rideId)),
        data: (ride) => ListView(
          children: [
            if (ride.path.length >= 2) SizedBox(height: 260, child: RideRouteMap(path: ride.path)),
            Padding(
              padding: const EdgeInsets.all(BrodieSpace.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    rideTitle(ride).toUpperCase(),
                    style: BrodieType.headline.copyWith(color: context.colors.textPrimary),
                  ),
                  const SizedBox(height: BrodieSpace.xxs),
                  Text(
                    '${rideStartLabel(context, ride)} · ${ride.arrived ? 'Arrived' : 'Ended early'}',
                    style: BrodieType.body.copyWith(color: context.colors.textSecondary),
                  ),
                  _UploadStatus(rideId: ride.id, justFinished: justFinished),
                  const SizedBox(height: BrodieSpace.md),
                  RideStats(ride: ride),
                  const SectionLabel('Vehicle'),
                  _VehicleRow(ride: ride),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: justFinished
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(BrodieSpace.md),
                child: BrodieButton(label: 'Done', icon: Icons.check, onPressed: () => context.pop()),
              ),
            )
          : null,
    );
  }
}

/// Whether the ride has reached the server yet, with a manual retry.
class _UploadStatus extends ConsumerWidget {
  const _UploadStatus({required this.rideId, required this.justFinished});

  final String rideId;
  final bool justFinished;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final waiting = ref.watch(rideSyncProvider.select((rides) => rides.any((ride) => ride.id == rideId)));
    // Saved rides opened from history need no status.
    if (!waiting && !justFinished) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: BrodieSpace.sm),
      child: Row(
        children: [
          Icon(waiting ? Icons.cloud_off : Icons.cloud_done, size: 20, color: waiting ? colors.warning : colors.success),
          const SizedBox(width: BrodieSpace.xs),
          Expanded(
            child: Text(
              waiting ? "Saved on this phone. It uploads when you're back online." : 'Saved to your history',
              style: BrodieType.body.copyWith(color: colors.textPrimary),
            ),
          ),
          if (waiting)
            TextButton(
              onPressed: () => ref.read(rideSyncProvider.notifier).uploadPending(),
              child: const Text('Retry'),
            ),
        ],
      ),
    );
  }
}

class _VehicleRow extends ConsumerWidget {
  const _VehicleRow({required this.ride});

  final Ride ride;

  Future<void> _choose(BuildContext context, WidgetRef ref, List<Vehicle> vehicles) async {
    final choice = await showBrodieSheet<({String? vehicleId})>(
      context,
      builder: (_) => _VehiclePicker(vehicles: vehicles, selectedId: ride.vehicleId),
    );
    if (choice == null || choice.vehicleId == ride.vehicleId || !context.mounted) return;
    await context.runWithFeedback(() => ref.read(rideSyncProvider.notifier).setVehicle(ride.id, choice.vehicleId));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vehicles = ref.watch(vehiclesControllerProvider).value;
    final vehicle = vehicles?.where((vehicle) => vehicle.id == ride.vehicleId).firstOrNull;
    final (title, subtitle) = switch ((ride.vehicleId, vehicle)) {
      (_, Vehicle(:final name, :final type)) => (name, type.label),
      (null, _) => ('No vehicle', 'Tap to choose what you rode'),
      // Its vehicle was deleted, or the garage hasn't loaded yet.
      _ => ('Vehicle', null),
    };

    return BrodieListGroup(
      children: [
        BrodieListTile(
          leading: IconTile(icon: vehicle == null ? Icons.two_wheeler : vehicleIcon(vehicle.type)),
          title: title,
          subtitle: subtitle,
          onTap: vehicles == null ? null : () => _choose(context, ref, vehicles),
        ),
      ],
    );
  }
}

/// Pops `(vehicleId: ...)`, where a null id means no vehicle; dismissing
/// pops nothing.
class _VehiclePicker extends StatelessWidget {
  const _VehiclePicker({required this.vehicles, required this.selectedId});

  final List<Vehicle> vehicles;
  final String? selectedId;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    Widget? check(String? id) => id == selectedId ? Icon(Icons.check, color: colors.accent) : const SizedBox.shrink();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(BrodieSpace.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('WHAT DID YOU RIDE?', style: BrodieType.title.copyWith(color: colors.textPrimary)),
            const SizedBox(height: BrodieSpace.md),
            BrodieListGroup(
              children: [
                for (final vehicle in vehicles)
                  BrodieListTile(
                    leading: IconTile(icon: vehicleIcon(vehicle.type)),
                    title: vehicle.name,
                    subtitle: vehicle.type.label,
                    trailing: check(vehicle.id),
                    onTap: () => Navigator.of(context).pop((vehicleId: vehicle.id)),
                  ),
                BrodieListTile(
                  leading: const IconTile(icon: Icons.block),
                  title: 'No vehicle',
                  trailing: check(null),
                  onTap: () => Navigator.of(context).pop((vehicleId: null)),
                ),
              ],
            ),
            if (vehicles.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: BrodieSpace.sm),
                child: Text(
                  'Add your bike under Profile → Vehicles to pick it here.',
                  style: BrodieType.body.copyWith(color: colors.textSecondary),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
