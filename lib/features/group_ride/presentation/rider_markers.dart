import 'package:flutter/painting.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import '../../../core/design_system/design_system.dart';
import '../../map/domain/map_models.dart';
import '../../map/presentation/widgets/route_layers.dart';
import '../application/group_ride_controller.dart';
import '../domain/group_ride_models.dart';

/// The other riders on the ride map: a dot per rider, colored by how recently
/// they were heard from and ringed when they've fallen behind, with their
/// username underneath. This rider is the map's own location puck.
class RiderMarkers {
  CircleAnnotationManager? _dots;
  PointAnnotationManager? _labels;

  /// Redraws are queued so only the latest riders get drawn when updates
  /// arrive faster than the map can apply them.
  List<LiveRider>? _queued;
  BrodieColors? _colors;
  var _drawing = false;

  /// Call after the route layers, so riders draw on top of the route.
  Future<void> attach(MapboxMap map) async {
    _dots = await map.annotations.createCircleAnnotationManager();
    _labels = await map.annotations.createPointAnnotationManager();
  }

  Future<void> show(List<LiveRider> riders, {required BrodieColors colors}) async {
    _queued = riders;
    _colors = colors;
    if (_drawing) return;
    _drawing = true;
    try {
      while (_queued != null) {
        final next = _queued!;
        _queued = null;
        await _draw(next, _colors!);
      }
    } finally {
      _drawing = false;
    }
  }

  Future<void> _draw(List<LiveRider> riders, BrodieColors colors) async {
    final dots = _dots;
    final labels = _labels;
    if (dots == null || labels == null) return;
    final placed = [
      for (final rider in riders)
        if (rider.fix case final fix?) (rider: rider, at: GeoPoint(latitude: fix.latitude, longitude: fix.longitude)),
    ];

    await dots.deleteAll();
    await labels.deleteAll();
    if (placed.isEmpty) return;
    await dots.createMulti([
      for (final (:rider, :at) in placed)
        CircleAnnotationOptions(
          geometry: Point(coordinates: positionOf(at)),
          circleRadius: 9,
          circleColor: colorFor(rider, colors).toARGB32(),
          circleStrokeColor: (rider.behind ? colors.danger : const Color(0xFFFFFFFF)).toARGB32(),
          circleStrokeWidth: rider.behind ? 4 : 3,
        ),
    ]);
    await labels.createMulti([
      for (final (:rider, :at) in placed)
        PointAnnotationOptions(
          geometry: Point(coordinates: positionOf(at)),
          textField: '@${rider.rider.username ?? 'rider'}',
          textSize: 12,
          textOffset: [0, 1.4],
          textAnchor: TextAnchor.TOP,
          textColor: colors.textPrimary.toARGB32(),
          textHaloColor: colors.surface.toARGB32(),
          textHaloWidth: 1.5,
        ),
    ]);
  }

  /// Also used by the rider list, so a rider looks the same in both.
  static Color colorFor(LiveRider rider, BrodieColors colors) => switch (rider.status) {
        RiderStatus.live => colors.success,
        RiderStatus.stale => colors.warning,
        RiderStatus.lost || null => colors.textSecondary,
      };
}
