import 'dart:convert';

import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import '../../../../core/design_system/design_system.dart';
import '../../domain/map_models.dart';
import 'route_layers.dart';

/// The ride screen's route line and destination pin, styled like
/// [RouteLayers]. The part already ridden disappears as the rider moves,
/// which needs a style line layer: annotations can't be trimmed.
class RideRouteLine {
  static const _routeSource = 'ride-route';
  static const _routeLayer = 'ride-route-line';
  static const _pinSource = 'ride-destination';
  static const _pinLayer = 'ride-destination-pin';

  MapboxMap? _map;
  List<GeoPoint> _path = const [];
  GeoPoint? _destination;
  double _ridden = 0;

  /// The latest attach; each waits for the one before, so two never add the
  /// same layers at once.
  Future<void> _attaching = Future.value();

  /// Call once the map's style has loaded, and again whenever the style
  /// reloads (e.g. a light/dark switch), which drops added layers.
  Future<void> attach(MapboxMap map, {required BrodieColors colors}) {
    return _attaching = _attaching.catchError((Object _) {}).then((_) => _attach(map, colors));
  }

  Future<void> _attach(MapboxMap map, BrodieColors colors) async {
    _map = null;
    final style = map.style;
    for (final layer in [_pinLayer, _routeLayer]) {
      if (await style.styleLayerExists(layer)) await style.removeStyleLayer(layer);
    }
    for (final source in [_pinSource, _routeSource]) {
      if (await style.styleSourceExists(source)) await style.removeStyleSource(source);
    }

    await style.addSource(GeoJsonSource(id: _routeSource, data: _routeJson(), lineMetrics: true));
    await style.addSource(GeoJsonSource(id: _pinSource, data: _pinJson()));
    await style.addLayer(
      LineLayer(
        id: _routeLayer,
        sourceId: _routeSource,
        lineColor: colors.primaryAction.toARGB32(),
        lineWidth: 8,
        lineBorderColor: colors.onPrimaryAction.toARGB32(),
        lineBorderWidth: 2,
        lineCap: LineCap.ROUND,
        lineJoin: LineJoin.ROUND,
        lineTrimOffset: [0, _ridden],
      ),
    );
    await style.addLayer(
      CircleLayer(
        id: _pinLayer,
        sourceId: _pinSource,
        circleRadius: 9,
        circleColor: colors.accent.toARGB32(),
        circleStrokeColor: colors.onAccent.toARGB32(),
        circleStrokeWidth: 3,
      ),
    );
    _map = map;
  }

  /// Replaces the route, e.g. after a reroute; none of the new one is ridden.
  Future<void> show({required List<GeoPoint> path, required GeoPoint destination}) async {
    _path = path;
    _destination = destination;
    _ridden = 0;
    final style = _map?.style;
    if (style == null) return;
    await style.setStyleSourceProperty(_routeSource, 'data', _routeJson());
    await style.setStyleSourceProperty(_pinSource, 'data', _pinJson());
    await style.setStyleLayerProperty(_routeLayer, 'line-trim-offset', [0.0, 0.0]);
  }

  /// Hides the first [fraction] (0 to 1) of the route.
  Future<void> trimTo(double fraction) async {
    final ridden = fraction.clamp(0.0, 1.0);
    // Sub-meter changes on a typical route aren't worth a redraw.
    if ((ridden - _ridden).abs() < 0.0005) return;
    _ridden = ridden;
    await _map?.style.setStyleLayerProperty(_routeLayer, 'line-trim-offset', [0.0, ridden]);
  }

  String _routeJson() => _path.length < 2 ? _empty : jsonEncode(lineOf(_path).toJson());

  String _pinJson() {
    final destination = _destination;
    return destination == null ? _empty : jsonEncode(Point(coordinates: positionOf(destination)).toJson());
  }

  static const _empty = '{"type":"FeatureCollection","features":[]}';
}
