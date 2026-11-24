import 'map_models.dart';
import 'route_tracker.dart';

/// Rules for a rider who has left the route. Worked out on the phone from the
/// route it already has, so guiding them back costs no Directions request.
abstract final class RouteRejoin {
  /// Closer than this the rider counts as on the route: GPS wanders this much.
  static const offRouteMeters = 50.0;

  /// Further off than this for [rerouteAfter] and a new route is suggested.
  static const rerouteMeters = 100.0;
  static const rerouteAfter = Duration(minutes: 1);

  /// Heading is only trusted when moving faster than this (about 7 km/h).
  static const _headingSpeedMps = 2.0;

  static bool isOffRoute(RideProgress? progress) => (progress?.distanceFromRouteMeters ?? 0) > offRouteMeters;

  /// Whether to suggest a new route: well off it, for a while ([farOffSince]
  /// is when the rider last went past [rerouteMeters]).
  static bool suggestReroute({required DateTime? farOffSince, required DateTime now}) =>
      farOffSince != null && now.difference(farOffSince) >= rerouteAfter;

  /// When the rider went past [rerouteMeters], given when they did before
  /// ([since]); null once they're back within it.
  static DateTime? farOffSince(RideProgress progress, {required DateTime? since, required DateTime now}) =>
      progress.distanceFromRouteMeters > rerouteMeters ? (since ?? now) : null;
}

/// Which way the route is: relative to where the rider is going ("to your
/// right") while they move, else a compass direction ("to the north-east").
String rejoinDirection(RideProgress progress, GeoFix? fix) {
  final bearing = progress.bearingToRouteDegrees;
  final heading = fix?.headingDegrees ?? -1;
  final speed = fix?.speedMps ?? 0;
  if (heading.isFinite && heading >= 0 && speed.isFinite && speed >= RouteRejoin._headingSpeedMps) {
    final turn = ((bearing - heading) % 360 + 360) % 360;
    if (turn <= 35 || turn >= 325) return 'ahead';
    if (turn >= 145 && turn <= 215) return 'behind you';
    return turn < 180 ? 'to your right' : 'to your left';
  }
  const names = ['north', 'north-east', 'east', 'south-east', 'south', 'south-west', 'west', 'north-west'];
  return 'to the ${names[((bearing + 22.5) % 360 ~/ 45) % 8]}';
}
