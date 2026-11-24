import 'dart:math' as math;

import 'map_models.dart';

const _earthRadiusMeters = 6371008.8;

double _radians(double degrees) => degrees * math.pi / 180;

/// Great-circle distance between two points, in meters (haversine).
double distanceBetween(GeoPoint a, GeoPoint b) {
  final lat1 = _radians(a.latitude);
  final lat2 = _radians(b.latitude);
  final dLat = lat2 - lat1;
  final dLng = _radians(b.longitude - a.longitude);
  final h = math.pow(math.sin(dLat / 2), 2) + math.cos(lat1) * math.cos(lat2) * math.pow(math.sin(dLng / 2), 2);
  return 2 * _earthRadiusMeters * math.asin(math.min(1, math.sqrt(h)));
}

/// Where a point sits relative to a route.
///
/// [bearingToRoute] is the compass direction from the point to the nearest
/// point on the route, in degrees (0 = north, 90 = east).
typedef RouteProjection = ({double distanceFromRoute, double alongRoute, double bearingToRoute});

/// A route polyline with precomputed lengths, answering the two questions a
/// ride asks on every fix without any API call: how far off the route is
/// this point, and how far along it?
class RouteGeometry {
  RouteGeometry(this.path) : assert(path.length >= 2, 'A route needs at least two points') {
    var total = 0.0;
    _cumulative = [0];
    for (var i = 1; i < path.length; i++) {
      total += distanceBetween(path[i - 1], path[i]);
      _cumulative.add(total);
    }
  }

  final List<GeoPoint> path;

  /// Distance from the start to each vertex of [path].
  late final List<double> _cumulative;

  double get lengthMeters => _cumulative.last;

  RouteProjection project(GeoPoint point) {
    // Flat projection centered on [point]: error is far below GPS noise at
    // the scale of one route segment.
    final metersPerRadianLng = math.cos(_radians(point.latitude)) * _earthRadiusMeters;
    (double, double) toXY(GeoPoint p) => (
      _radians(p.longitude - point.longitude) * metersPerRadianLng,
      _radians(p.latitude - point.latitude) * _earthRadiusMeters,
    );

    var bestDistance = double.infinity;
    var bestAlong = 0.0;
    var bestBearing = 0.0;
    for (var i = 0; i < path.length - 1; i++) {
      final (ax, ay) = toXY(path[i]);
      final (bx, by) = toXY(path[i + 1]);
      final dx = bx - ax;
      final dy = by - ay;
      final lengthSquared = dx * dx + dy * dy;
      // [point] is the origin, so the vector from A to it is (-ax, -ay).
      final t = lengthSquared == 0 ? 0.0 : ((-ax * dx - ay * dy) / lengthSquared).clamp(0.0, 1.0);
      final cx = ax + t * dx;
      final cy = ay + t * dy;
      final distance = math.sqrt(cx * cx + cy * cy);
      if (distance < bestDistance) {
        bestDistance = distance;
        bestAlong = _cumulative[i] + t * (_cumulative[i + 1] - _cumulative[i]);
        // x is east and y is north, so this is a compass bearing.
        bestBearing = (math.atan2(cx, cy) * 180 / math.pi + 360) % 360;
      }
    }
    return (distanceFromRoute: bestDistance, alongRoute: bestAlong, bearingToRoute: bestBearing);
  }
}

/// [path] with every point dropped that lies within [toleranceMeters] of the
/// line between the points kept around it (Douglas–Peucker). Straight
/// stretches collapse to their ends; bends keep their shape.
List<GeoPoint> simplifyPath(List<GeoPoint> path, double toleranceMeters) {
  if (path.length <= 2) return List.of(path);

  // Flat projection centered on the first point, as in [RouteGeometry.project].
  final origin = path.first;
  final metersPerRadianLng = math.cos(_radians(origin.latitude)) * _earthRadiusMeters;
  final xy = [
    for (final p in path)
      (
        _radians(p.longitude - origin.longitude) * metersPerRadianLng,
        _radians(p.latitude - origin.latitude) * _earthRadiusMeters,
      ),
  ];

  double offset(int i, int from, int to) {
    final (px, py) = xy[i];
    final (ax, ay) = xy[from];
    final (bx, by) = xy[to];
    final dx = bx - ax;
    final dy = by - ay;
    final lengthSquared = dx * dx + dy * dy;
    final t = lengthSquared == 0 ? 0.0 : (((px - ax) * dx + (py - ay) * dy) / lengthSquared).clamp(0.0, 1.0);
    final cx = ax + t * dx - px;
    final cy = ay + t * dy - py;
    return math.sqrt(cx * cx + cy * cy);
  }

  final keep = List.filled(path.length, false)
    ..[0] = true
    ..[path.length - 1] = true;
  final spans = [(0, path.length - 1)];
  while (spans.isNotEmpty) {
    final (from, to) = spans.removeLast();
    var farthest = -1;
    var farthestOffset = toleranceMeters;
    for (var i = from + 1; i < to; i++) {
      final d = offset(i, from, to);
      if (d > farthestOffset) {
        farthest = i;
        farthestOffset = d;
      }
    }
    if (farthest != -1) {
      keep[farthest] = true;
      spans
        ..add((from, farthest))
        ..add((farthest, to));
    }
  }
  return [
    for (final (i, point) in path.indexed)
      if (keep[i]) point,
  ];
}
