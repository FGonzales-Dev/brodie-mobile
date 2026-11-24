import 'package:brodie/features/map/domain/map_models.dart';
import 'package:brodie/features/map/domain/route_geometry.dart';
import 'package:brodie/features/map/domain/route_rejoin.dart';
import 'package:brodie/features/map/domain/route_tracker.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/geo.dart';

const _start = GeoPoint(latitude: 14.1, longitude: 120.9);

/// A 2 km route due north.
final _route = RouteGeometry([_start, north(_start, 2000)]);

RideProgress _progressAt(GeoPoint point) {
  final projection = _route.project(point);
  return RideProgress(
    distanceRemainingMeters: 0,
    timeRemaining: Duration.zero,
    distanceFromRouteMeters: projection.distanceFromRoute,
    bearingToRouteDegrees: projection.bearingToRoute,
    fractionRidden: 0,
    arrived: false,
  );
}

GeoFix _moving(GeoPoint at, {required double heading}) =>
    GeoFix(position: at, accuracyMeters: 8, speedMps: 10, headingDegrees: heading, timestamp: DateTime(2026, 11, 27));

void main() {
  test('points to the nearest point of the route', () {
    expect(_route.project(east(north(_start, 1000), 200)).bearingToRoute, closeTo(270, 1), reason: 'route is west');
    expect(_route.project(east(north(_start, 1000), -200)).bearingToRoute, closeTo(90, 1), reason: 'route is east');
    expect(_route.project(north(_start, -300)).bearingToRoute, closeTo(0, 1), reason: 'route starts north');
  });

  test('only well away from the route counts as off it', () {
    expect(RouteRejoin.isOffRoute(_progressAt(east(north(_start, 500), 30))), isFalse, reason: 'GPS noise');
    expect(RouteRejoin.isOffRoute(_progressAt(east(north(_start, 500), 80))), isTrue);
    expect(RouteRejoin.isOffRoute(null), isFalse);
  });

  test('while moving, the way back is relative to where the rider is going', () {
    final eastOfRoute = east(north(_start, 1000), 200);
    final progress = _progressAt(eastOfRoute);
    expect(rejoinDirection(progress, _moving(eastOfRoute, heading: 0)), 'to your left', reason: 'riding north');
    expect(rejoinDirection(progress, _moving(eastOfRoute, heading: 180)), 'to your right', reason: 'riding south');
    expect(rejoinDirection(progress, _moving(eastOfRoute, heading: 270)), 'ahead');
    expect(rejoinDirection(progress, _moving(eastOfRoute, heading: 90)), 'behind you');
  });

  test('when stopped (no reliable heading), it gives a compass direction', () {
    final progress = _progressAt(east(north(_start, 1000), 200));
    expect(rejoinDirection(progress, null), 'to the west');
    final stopped = _moving(east(north(_start, 1000), 200), heading: 0).copyWith(speedMps: 0);
    expect(rejoinDirection(progress, stopped), 'to the west');
    expect(rejoinDirection(_progressAt(east(north(_start, -300), 300)), null), 'to the north-west');
  });

  test('a reroute is suggested only after a minute well off the route', () {
    final now = DateTime(2026, 11, 27, 8);
    final farOff = _progressAt(east(north(_start, 1000), 150));
    final near = _progressAt(east(north(_start, 1000), 60));

    final since = RouteRejoin.farOffSince(farOff, since: null, now: now);
    expect(since, now);
    expect(RouteRejoin.farOffSince(farOff, since: since, now: now.add(const Duration(seconds: 30))), now);
    expect(
      RouteRejoin.farOffSince(near, since: since, now: now),
      isNull,
      reason: 'back within 100 m',
    );

    expect(RouteRejoin.suggestReroute(farOffSince: since, now: now.add(const Duration(seconds: 59))), isFalse);
    expect(RouteRejoin.suggestReroute(farOffSince: since, now: now.add(const Duration(minutes: 1))), isTrue);
    expect(RouteRejoin.suggestReroute(farOffSince: null, now: now), isFalse);
  });
}
