import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import '../../../../core/design_system/design_system.dart';
import '../../domain/map_models.dart';
import 'route_layers.dart';

/// "You are here" dot on the home map, drawn from the last fetched fix. The
/// map's live location puck is off there, so the dot only moves when the
/// rider refreshes their location.
class MyPositionMarker {
  CircleAnnotationManager? _dot;

  /// Call after the other layers so the dot draws on top.
  Future<void> attach(MapboxMap map) async {
    _dot = await map.annotations.createCircleAnnotationManager();
  }

  Future<void> show(GeoPoint? position) async {
    await _dot?.deleteAll();
    if (position == null) return;
    await _dot?.create(
      CircleAnnotationOptions(
        geometry: Point(coordinates: positionOf(position)),
        circleRadius: 9,
        circleColor: BrodieColors.myPosition.toARGB32(),
        circleStrokeColor: 0xFFFFFFFF,
        circleStrokeWidth: 3,
      ),
    );
  }
}
