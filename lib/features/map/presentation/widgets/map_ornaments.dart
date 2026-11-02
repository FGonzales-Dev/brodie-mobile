import 'package:flutter/widgets.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

/// Keeps Mapbox's own map overlays clear of the app's panels. The logo and
/// the ⓘ attribution button must stay visible (Mapbox's terms), so they sit
/// just above the bottom panel; the compass sits below the top panel; the
/// scale bar, which drew over the status bar and search bar, is hidden.
class MapOrnaments {
  static const _gap = 8.0;
  static const _side = 12.0;

  /// The Mapbox logo is about this wide; the ⓘ button sits to its right.
  static const _logoWidth = 88.0;

  MapboxMap? _map;
  ({double top, double bottom})? _applied;

  /// Call from `onMapCreated`.
  Future<void> attach(MapboxMap map) async {
    _map = map;
    _applied = null;
    await map.scaleBar.updateSettings(ScaleBarSettings(enabled: false));
  }

  /// [top] and [bottom] are how much of the map's top and bottom edges the
  /// app's panels cover. Cheap to call after every layout: unchanged values
  /// are skipped.
  Future<void> keepClear({required double top, required double bottom}) async {
    final map = _map;
    final insets = (top: top, bottom: bottom);
    if (map == null || insets == _applied) return;
    _applied = insets;
    await Future.wait([
      map.compass.updateSettings(
        CompassSettings(position: OrnamentPosition.TOP_RIGHT, marginTop: top + _gap, marginRight: _side),
      ),
      map.logo.updateSettings(
        LogoSettings(position: OrnamentPosition.BOTTOM_LEFT, marginBottom: bottom + _gap, marginLeft: _side),
      ),
      map.attribution.updateSettings(
        AttributionSettings(
          position: OrnamentPosition.BOTTOM_LEFT,
          marginBottom: bottom + _gap,
          marginLeft: _side + _logoWidth,
        ),
      ),
    ]);
  }
}

/// Laid-out height of the widget holding [key], or 0 before layout.
double heightOf(GlobalKey key) => (key.currentContext?.findRenderObject() as RenderBox?)?.size.height ?? 0;
