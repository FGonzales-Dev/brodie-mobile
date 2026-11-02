import 'dart:math' as math;

import 'map_models.dart';
import 'route_geometry.dart';

/// The ride as actually ridden, built from GPS fixes: the path for the ride
/// summary and history, plus distance, moving time and top speed. Inaccurate
/// fixes are ignored, and standstill jitter neither adds distance nor counts
/// as moving, so a parked bike doesn't rack up meters.
class TrackRecorder {
  static const _maxAccuracyMeters = 30.0;

  /// Smaller steps are GPS jitter, not movement.
  static const _minStepMeters = 3.0;

  /// Points are recorded at least this far apart; [path] thins them further.
  static const _minSpacingMeters = 10.0;

  /// The saved path stays within this distance of the recorded one.
  static const _simplifyToleranceMeters = 5.0;

  /// From about 4 km/h up, the rider counts as moving.
  static const _movingSpeedMps = 1.0;

  /// A longer gap between fixes (lost signal, or a stop with no new fixes)
  /// doesn't count as moving time.
  static const _maxMovingGap = Duration(seconds: 30);

  /// Faster readings (about 360 km/h) are GPS glitches.
  static const _maxPlausibleSpeedMps = 100.0;

  final _points = <GeoPoint>[];
  GeoFix? _previous;
  GeoPoint? _odometerAnchor;
  double _meters = 0;
  var _moving = Duration.zero;
  double _maxSpeedMps = 0;

  double get distanceMeters => _meters;
  Duration get movingTime => _moving;
  double get maxSpeedMps => _maxSpeedMps;

  /// The route ridden, simplified for saving and ending at the last
  /// accurate position.
  List<GeoPoint> get path {
    final last = _previous?.position;
    final points = [..._points, if (last != null && last != _points.lastOrNull) last];
    return simplifyPath(points, _simplifyToleranceMeters);
  }

  void add(GeoFix fix) {
    if (fix.accuracyMeters > _maxAccuracyMeters) return;

    final previous = _previous;
    _previous = fix;
    if (previous != null && fix.speedMps >= _movingSpeedMps) {
      final gap = fix.timestamp.difference(previous.timestamp);
      if (!gap.isNegative && gap <= _maxMovingGap) _moving += gap;
    }
    if (fix.speedMps <= _maxPlausibleSpeedMps) _maxSpeedMps = math.max(_maxSpeedMps, fix.speedMps);

    final anchor = _odometerAnchor;
    if (anchor == null) {
      _odometerAnchor = fix.position;
    } else {
      final step = distanceBetween(anchor, fix.position);
      if (step >= _minStepMeters) {
        _meters += step;
        _odometerAnchor = fix.position;
      }
    }

    if (_points.isEmpty || distanceBetween(_points.last, fix.position) >= _minSpacingMeters) {
      _points.add(fix.position);
    }
  }
}
