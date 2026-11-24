import 'dart:math' as math;

import 'package:freezed_annotation/freezed_annotation.dart';

import 'map_models.dart';
import 'route_geometry.dart';

part 'route_tracker.freezed.dart';

/// Where the rider is on their route right now.
@freezed
abstract class RideProgress with _$RideProgress {
  const factory RideProgress({
    required double distanceRemainingMeters,
    required Duration timeRemaining,
    required double distanceFromRouteMeters,

    /// How much of the route lies behind the rider, from 0 to 1.
    required double fractionRidden,

    /// The next instruction ahead, or null past the last one.
    RouteManeuver? nextManeuver,
    double? distanceToManeuverMeters,
    required bool arrived,
  }) = _RideProgress;
}

/// Recomputes [RideProgress] from each GPS fix, with no API call: distance
/// and time left along the route, the next turn, and arrival.
class RouteTracker {
  RouteTracker(this.route, {required this.destination}) : _geometry = RouteGeometry(route.path) {
    _maneuverAlong = [for (final maneuver in route.maneuvers) _geometry.project(maneuver.location).alongRoute];
  }

  /// Within this distance of the destination counts as arrived.
  static const arrivalRadiusMeters = 40.0;

  /// A fix this inaccurate can't declare arrival.
  static const _maxArrivalAccuracyMeters = 50.0;

  /// A turn counts as done once the rider is this far past it; until then it
  /// stays on screen, so GPS jitter at a corner doesn't skip it early.
  static const _passedMarginMeters = 5.0;

  final RouteResult route;
  final GeoPoint destination;
  final RouteGeometry _geometry;
  late final List<double> _maneuverAlong;

  RideProgress progressAt(GeoFix fix) {
    final projection = _geometry.project(fix.position);
    final remaining = math.max(0.0, _geometry.lengthMeters - projection.alongRoute);
    // Time left scales with distance left, at the route's planned pace.
    final secondsPerMeter = route.distanceMeters > 0 ? route.duration.inSeconds / route.distanceMeters : 0.0;
    final next = _maneuverAlong.indexWhere((along) => along > projection.alongRoute - _passedMarginMeters);

    final closeToDestination =
        distanceBetween(fix.position, destination) <= arrivalRadiusMeters ||
        (remaining <= arrivalRadiusMeters && projection.distanceFromRoute <= arrivalRadiusMeters);

    return RideProgress(
      distanceRemainingMeters: remaining,
      timeRemaining: Duration(seconds: (remaining * secondsPerMeter).round()),
      distanceFromRouteMeters: projection.distanceFromRoute,
      fractionRidden: _geometry.lengthMeters == 0 ? 0 : projection.alongRoute / _geometry.lengthMeters,
      nextManeuver: next == -1 ? null : route.maneuvers[next],
      distanceToManeuverMeters: next == -1 ? null : math.max(0.0, _maneuverAlong[next] - projection.alongRoute),
      arrived: closeToDestination && fix.accuracyMeters <= _maxArrivalAccuracyMeters,
    );
  }
}
