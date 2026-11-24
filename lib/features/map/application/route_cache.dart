import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/di/core_providers.dart';
import '../../auth/application/session_providers.dart';
import '../data/directions_repository.dart';
import '../domain/map_models.dart';
import '../domain/route_geometry.dart';

part 'route_cache.g.dart';

/// Routes fetched recently on this phone, so previewing the same trip again
/// (backing out and picking the same place, or a leader re-planning) doesn't
/// cost another Directions request. Short-lived and in memory only: kept
/// within what Mapbox allows for reusing results.
class RouteCache {
  RouteCache(this._now);

  static const maxAge = Duration(minutes: 30);

  /// A rider who moved further than this since needs a route from where
  /// they are now.
  static const maxStartShiftMeters = 150.0;

  /// Destinations this close count as the same (search can return the same
  /// place with slightly different coordinates).
  static const maxDestinationShiftMeters = 25.0;
  static const capacity = 5;

  final DateTime Function() _now;
  final _entries = <({GeoPoint from, GeoPoint to, RouteResult route, DateTime fetchedAt})>[];

  RouteResult? lookup({required GeoPoint from, required GeoPoint to}) {
    final now = _now();
    _entries.removeWhere((entry) => now.difference(entry.fetchedAt) > maxAge);
    for (final entry in _entries.reversed) {
      if (distanceBetween(entry.to, to) <= maxDestinationShiftMeters &&
          distanceBetween(entry.from, from) <= maxStartShiftMeters) {
        return entry.route;
      }
    }
    return null;
  }

  void store({required GeoPoint from, required GeoPoint to, required RouteResult route}) {
    _entries.add((from: from, to: to, route: route, fetchedAt: _now()));
    if (_entries.length > capacity) _entries.removeAt(0);
  }
}

@Riverpod(keepAlive: true)
RouteCache routeCache(Ref ref) {
  // Another rider signing in on this phone starts with an empty cache.
  ref.watch(currentUserProvider);
  return RouteCache(ref.watch(clockProvider));
}

/// A route from [from] to [to] for a preview or plan: a recent one from
/// [RouteCache] when there is one, else a new Directions request (which is
/// then cached). Reroutes don't use this: they always want a fresh route.
Future<RouteResult> previewRoute(
  Ref ref, {
  required GeoPoint from,
  required GeoPoint to,
  required RoutePurpose purpose,
}) async {
  final cache = ref.read(routeCacheProvider);
  if (cache.lookup(from: from, to: to) case final cached?) return cached;
  final route = await ref.read(directionsRepositoryProvider).fetchRoute(from: from, to: to, purpose: purpose);
  cache.store(from: from, to: to, route: route);
  return route;
}
