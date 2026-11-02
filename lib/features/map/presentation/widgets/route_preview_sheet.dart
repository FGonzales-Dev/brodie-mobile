import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/routes.dart';
import '../../../../core/design_system/design_system.dart';
import '../../../../core/errors/app_failure.dart';
import '../../../../core/utils/units.dart';
import '../../../settings/application/settings_controller.dart';
import '../../domain/map_models.dart';
import '../ride_planning_controller.dart';

/// Bottom panel for the selected destination: loading, route stats with ride
/// actions, or an error with retry.
class RoutePreviewSheet extends ConsumerWidget {
  const RoutePreviewSheet({super.key, required this.state});

  final RidePlanState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final controller = ref.read(ridePlanningControllerProvider.notifier);

    final (destination, body) = switch (state) {
      RidePlanIdle() => (null, const SizedBox.shrink()),
      RidePlanLoading(:final destination) => (destination, const _Loading()),
      RidePlanPreview(:final destination, :final route) => (destination, _RouteStats(route: route)),
      RidePlanError(:final destination, :final error) => (
          destination,
          _RouteError(error: error, onRetry: controller.retry, onDismiss: controller.clear),
        ),
    };
    if (destination == null) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.accent, width: 3)),
      ),
      padding: const EdgeInsets.fromLTRB(BrodieSpace.md, BrodieSpace.md, BrodieSpace.md, BrodieSpace.md),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(destination.name.toUpperCase(), style: BrodieType.headline.copyWith(color: colors.textPrimary)),
                    if (destination.address != null)
                      Text(destination.address!, style: BrodieType.caption.copyWith(color: colors.textSecondary)),
                  ],
                ),
              ),
              IconButton(tooltip: 'Clear destination', icon: const Icon(Icons.close), onPressed: controller.clear),
            ],
          ),
          const SizedBox(height: BrodieSpace.sm),
          body,
        ],
      ),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: BrodieSpace.md),
      child: Row(
        children: [
          const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2.5)),
          const SizedBox(width: BrodieSpace.sm),
          Text('Finding the best route…', style: BrodieType.body.copyWith(color: context.colors.textSecondary)),
        ],
      ),
    );
  }
}

class _RouteStats extends ConsumerWidget {
  const _RouteStats({required this.route});

  final RouteResult route;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final units = ref.watch(settingsControllerProvider.select((settings) => settings.units));
    final distance = formatDistance(route.distanceMeters, units);
    final duration = formatDuration(route.duration);
    final arrival = MaterialLocalizations.of(context)
        .formatTimeOfDay(TimeOfDay.fromDateTime(DateTime.now().add(route.duration)));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: StatTile(value: distance.value, unit: distance.unit)),
            const SizedBox(width: BrodieSpace.xs),
            Expanded(child: StatTile(value: duration.value, unit: duration.unit)),
            const SizedBox(width: BrodieSpace.xs),
            Expanded(child: StatTile(value: arrival, unit: 'arrive')),
          ],
        ),
        const SizedBox(height: BrodieSpace.sm),
        Row(
          children: [
            Expanded(
              child: BrodieButton.secondary(
                label: 'Group',
                icon: Icons.groups_outlined,
                onPressed: () => context.push(Routes.createGroup),
              ),
            ),
            const SizedBox(width: BrodieSpace.sm),
            Expanded(
              child: BrodieButton(
                label: 'Ride solo',
                icon: Icons.navigation_outlined,
                onPressed: () => context.push(Routes.soloRide),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _RouteError extends StatelessWidget {
  const _RouteError({required this.error, required this.onRetry, required this.onDismiss});

  final Object error;
  final VoidCallback onRetry;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(AppFailure.messageFor(error), style: BrodieType.body.copyWith(color: context.colors.danger)),
        const SizedBox(height: BrodieSpace.sm),
        Row(
          children: [
            Expanded(child: BrodieButton.secondary(label: 'Dismiss', onPressed: onDismiss)),
            const SizedBox(width: BrodieSpace.sm),
            Expanded(child: BrodieButton(label: 'Try again', onPressed: onRetry)),
          ],
        ),
      ],
    );
  }
}
