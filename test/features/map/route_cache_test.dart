import 'package:brodie/features/map/application/route_cache.dart';
import 'package:brodie/features/map/domain/map_models.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/geo.dart';

const _home = GeoPoint(latitude: 14.5, longitude: 121.0);
final _summit = north(_home, 20000);
const _route = RouteResult(path: [], distanceMeters: 20000, duration: Duration(minutes: 30), encodedPolyline: '');

void main() {
  late DateTime now;
  late RouteCache cache;

  setUp(() {
    now = DateTime(2026, 11, 27, 8);
    cache = RouteCache(() => now)..store(from: _home, to: _summit, route: _route);
  });

  test('the same trip again reuses the route', () {
    expect(cache.lookup(from: _home, to: _summit), same(_route));
  });

  test('small shifts still count as the same trip', () {
    expect(cache.lookup(from: east(_home, 100), to: east(_summit, 20)), same(_route));
  });

  test('a rider who moved away needs a route from where they are', () {
    expect(cache.lookup(from: east(_home, 300), to: _summit), isNull);
  });

  test('another destination needs its own route', () {
    expect(cache.lookup(from: _home, to: east(_summit, 100)), isNull);
  });

  test('routes expire after half an hour', () {
    now = now.add(const Duration(minutes: 29));
    expect(cache.lookup(from: _home, to: _summit), isNotNull);
    now = now.add(const Duration(minutes: 2));
    expect(cache.lookup(from: _home, to: _summit), isNull);
  });

  test('only the newest few routes are kept', () {
    for (var i = 1; i <= RouteCache.capacity; i++) {
      cache.store(from: _home, to: north(_summit, i * 1000.0), route: _route);
    }
    expect(
      cache.lookup(from: _home, to: _summit),
      isNull,
      reason: 'the oldest was dropped',
    );
    expect(cache.lookup(from: _home, to: north(_summit, 5000)), isNotNull);
  });
}
