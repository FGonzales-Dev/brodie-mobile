import 'package:brodie/features/map/domain/map_models.dart';
import 'package:brodie/features/map/domain/route_geometry.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/geo.dart';

void main() {
  const start = GeoPoint(latitude: 14.1, longitude: 120.9);

  test('distanceBetween matches known distances', () {
    expect(distanceBetween(start, north(start, 1000)), closeTo(1000, 0.5));
    expect(distanceBetween(start, east(start, 1000)), closeTo(1000, 0.5));
  });

  test('projects a point beside a straight route', () {
    final route = RouteGeometry([start, north(start, 2000)]);
    final projection = route.project(east(north(start, 1000), 200));

    expect(route.lengthMeters, closeTo(2000, 1));
    expect(projection.distanceFromRoute, closeTo(200, 1));
    expect(projection.alongRoute, closeTo(1000, 1));
  });

  test('measures progress along a route with a turn', () {
    final corner = north(start, 1000);
    final route = RouteGeometry([start, corner, east(corner, 1000)]);
    final projection = route.project(east(corner, 500));

    expect(projection.distanceFromRoute, closeTo(0, 1));
    expect(projection.alongRoute, closeTo(1500, 1));
  });

  test('clamps points before the start to the first vertex', () {
    final route = RouteGeometry([start, north(start, 1000)]);
    final projection = route.project(north(start, -300));

    expect(projection.alongRoute, 0);
    expect(projection.distanceFromRoute, closeTo(300, 1));
  });
}
