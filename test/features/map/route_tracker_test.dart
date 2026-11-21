import 'package:brodie/features/map/domain/map_models.dart';
import 'package:brodie/features/map/domain/route_tracker.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/geo.dart';

void main() {
  // An L-shaped route: 1 km north, turn right, 1 km east. Planned at 0.1 s/m.
  const start = GeoPoint(latitude: 14.1, longitude: 120.9);
  final corner = north(start, 1000);
  final end = east(corner, 1000);
  final route = RouteResult(
    path: [start, corner, end],
    distanceMeters: 2000,
    duration: const Duration(seconds: 200),
    encodedPolyline: '',
    maneuvers: [
      const RouteManeuver(instruction: 'Head north', type: 'depart', location: start),
      RouteManeuver(instruction: 'Turn right onto Romulo Highway', type: 'turn', modifier: 'right', location: corner),
      RouteManeuver(instruction: 'You have arrived', type: 'arrive', location: end),
    ],
  );
  final tracker = RouteTracker(route, destination: end);
  final at = DateTime(2026, 10, 29, 16);

  RideProgress progressAt(GeoPoint position, {double accuracy = 8}) =>
      tracker.progressAt(fixAt(position, at, accuracyMeters: accuracy));

  test('reports distance and time left at the planned pace', () {
    final progress = progressAt(north(start, 200));

    expect(progress.distanceRemainingMeters, closeTo(1800, 2));
    expect(progress.timeRemaining.inSeconds, closeTo(180, 1));
    expect(progress.distanceFromRouteMeters, closeTo(0, 1));
    expect(progress.arrived, isFalse);
  });

  test('reports how much of the route is behind the rider', () {
    expect(progressAt(start).fractionRidden, closeTo(0, 0.001));
    expect(progressAt(east(corner, 500)).fractionRidden, closeTo(0.75, 0.001));
    expect(progressAt(end).fractionRidden, closeTo(1, 0.001));
  });

  test('shows the next turn and how far it is', () {
    final progress = progressAt(north(start, 200));

    expect(progress.nextManeuver?.instruction, 'Turn right onto Romulo Highway');
    expect(progress.distanceToManeuverMeters, closeTo(800, 2));
  });

  test('keeps a turn on screen until the rider is past it', () {
    expect(progressAt(north(start, 997)).nextManeuver?.type, 'turn', reason: '3 m before the corner');
    expect(progressAt(east(corner, 20)).nextManeuver?.type, 'arrive', reason: '20 m after the corner');
  });

  test('arrives within 40 m of the destination', () {
    expect(progressAt(east(corner, 900)).arrived, isFalse);
    expect(progressAt(east(corner, 975)).arrived, isTrue);
  });

  test('an inaccurate fix cannot declare arrival', () {
    expect(progressAt(east(corner, 990), accuracy: 80).arrived, isFalse);
  });

  test('measures how far off the route the rider is', () {
    final progress = progressAt(east(north(start, 500), -150));

    expect(progress.distanceFromRouteMeters, closeTo(150, 2));
    expect(progress.arrived, isFalse);
  });
}
