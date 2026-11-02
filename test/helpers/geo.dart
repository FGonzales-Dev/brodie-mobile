import 'dart:math' as math;

import 'package:brodie/features/map/domain/map_models.dart';

const _metersPerDegreeLatitude = 111194.93;

/// [point] moved [meters] north.
GeoPoint north(GeoPoint point, double meters) =>
    GeoPoint(latitude: point.latitude + meters / _metersPerDegreeLatitude, longitude: point.longitude);

/// [point] moved [meters] east.
GeoPoint east(GeoPoint point, double meters) => GeoPoint(
      latitude: point.latitude,
      longitude: point.longitude + meters / (_metersPerDegreeLatitude * math.cos(point.latitude * math.pi / 180)),
    );

GeoFix fixAt(GeoPoint position, DateTime at, {double accuracyMeters = 8, double speedMps = 0}) => GeoFix(
      position: position,
      accuracyMeters: accuracyMeters,
      speedMps: speedMps,
      headingDegrees: 0,
      timestamp: at,
    );
