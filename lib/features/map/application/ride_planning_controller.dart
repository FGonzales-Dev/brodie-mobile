import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../data/repositories/directions_repository.dart';
import '../../../data/repositories/location_repository.dart';
import '../../../domain/models/retrieved_place.dart';
import '../../../domain/models/route_result.dart';

part 'ride_planning_controller.g.dart';

sealed class RidePlanState {
  const RidePlanState();
}

class RidePlanIdle extends RidePlanState {
  const RidePlanIdle();
}

class RidePlanPendingConfirm extends RidePlanState {
  const RidePlanPendingConfirm(this.destination);
  final RetrievedPlace destination;
}

class RidePlanFetchingRoute extends RidePlanState {
  const RidePlanFetchingRoute(this.destination);
  final RetrievedPlace destination;
}

class RidePlanRoutePreview extends RidePlanState {
  const RidePlanRoutePreview(this.destination, this.route);
  final RetrievedPlace destination;
  final RouteResult route;
}

class RidePlanError extends RidePlanState {
  const RidePlanError(this.destination, this.message);
  final RetrievedPlace destination;
  final String message;
}

@riverpod
class RidePlanningController extends _$RidePlanningController {
  @override
  RidePlanState build() => const RidePlanIdle();

  void selectDestination(RetrievedPlace place) {
    state = RidePlanPendingConfirm(place);
  }

  void cancel() {
    state = const RidePlanIdle();
  }

  Future<void> confirm() async {
    final current = state;
    if (current is! RidePlanPendingConfirm) return;
    final destination = current.destination;
    state = RidePlanFetchingRoute(destination);
    try {
      final position = await ref.read(locationRepositoryProvider).positionStream().first;
      final route = await ref.read(directionsRepositoryProvider).getRoute(
            originLongitude: position.longitude,
            originLatitude: position.latitude,
            destinationLongitude: destination.longitude,
            destinationLatitude: destination.latitude,
          );
      state = RidePlanRoutePreview(destination, route);
    } catch (e) {
      state = RidePlanError(destination, e.toString());
    }
  }
}
