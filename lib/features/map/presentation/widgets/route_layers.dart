import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import '../../../../core/design_system/design_system.dart';
import '../../domain/map_models.dart';

/// The route line and destination pin drawn on a map. Shared by the planning
/// map, the ride screen and ride history so all look the same.
class RouteLayers {
  PolylineAnnotationManager? _lines;
  CircleAnnotationManager? _pins;

  /// Call from `onMapCreated`. The pin manager is created last so the pin
  /// draws on top of the line.
  Future<void> attach(MapboxMap map) async {
    _lines = await map.annotations.createPolylineAnnotationManager();
    _pins = await map.annotations.createCircleAnnotationManager();
  }

  /// Replaces whatever is drawn with a line along [path] and/or a pin at
  /// [pin].
  Future<void> show({required BrodieColors colors, List<GeoPoint>? path, GeoPoint? pin, double lineWidth = 6}) async {
    await _lines?.deleteAll();
    await _pins?.deleteAll();
    if (path != null && path.length >= 2) {
      await _lines?.create(
        PolylineAnnotationOptions(
          geometry: lineOf(path),
          lineColor: colors.primaryAction.toARGB32(),
          lineWidth: lineWidth,
          lineBorderColor: colors.onPrimaryAction.toARGB32(),
          lineBorderWidth: 2,
        ),
      );
    }
    if (pin != null) {
      await _pins?.create(
        CircleAnnotationOptions(
          geometry: Point(coordinates: positionOf(pin)),
          circleRadius: 9,
          circleColor: colors.accent.toARGB32(),
          circleStrokeColor: colors.onAccent.toARGB32(),
          circleStrokeWidth: 3,
        ),
      );
    }
  }
}

Position positionOf(GeoPoint point) => Position(point.longitude, point.latitude);

LineString lineOf(List<GeoPoint> path) => LineString(coordinates: path.map(positionOf).toList());
