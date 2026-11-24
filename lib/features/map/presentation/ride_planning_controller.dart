import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/directions_repository.dart';
import '../data/location_repository.dart';
import '../domain/map_models.dart';

part 'ride_planning_controller.g.dart';

sealed class RidePlanState {
  const RidePlanState();
}

class RidePlanIdle extends RidePlanState {
  const RidePlanIdle();
}

class RidePlanLoading extends RidePlanState {
  const RidePlanLoading(this.destination);
  final Place destination;
}

class RidePlanPreview extends RidePlanState {
  const RidePlanPreview(this.destination, this.route);
  final Place destination;
  final RouteResult route;
}

class RidePlanError extends RidePlanState {
  const RidePlanError(this.destination, this.error);
  final Place destination;
  final Object error;
}

/// Destination → route preview. Picking a destination fetches the route from
/// the user's current position straight away.
@riverpod
class RidePlanningController extends _$RidePlanningController {
  @override
  RidePlanState build() => const RidePlanIdle();

  Future<void> selectDestination(Place destination) async {
    state = RidePlanLoading(destination);
    try {
      final origin = await ref.read(locationRepositoryProvider).currentPosition();
      final route = await ref
          .read(directionsRepositoryProvider)
          .fetchRoute(from: origin, to: destination.location, purpose: RoutePurpose.ridePreview);
      if (ref.mounted) state = RidePlanPreview(destination, route);
    } catch (error) {
      if (ref.mounted) state = RidePlanError(destination, error);
    }
  }

  Future<void> retry() async {
    if (state case RidePlanError(:final destination)) await selectDestination(destination);
  }

  void clear() => state = const RidePlanIdle();
}
