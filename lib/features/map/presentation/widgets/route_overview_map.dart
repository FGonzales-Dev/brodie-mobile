import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import '../../../../core/design_system/design_system.dart';
import '../../domain/map_models.dart';
import 'route_layers.dart';

/// A route and its end pin, framed to fit: a ride in history, a group's
/// planned trip. Not interactive, so it can sit inside a scrolling page.
class RouteOverviewMap extends StatefulWidget {
  const RouteOverviewMap({super.key, required this.path});

  final List<GeoPoint> path;

  @override
  State<RouteOverviewMap> createState() => _RouteOverviewMapState();
}

class _RouteOverviewMapState extends State<RouteOverviewMap> {
  final _layers = RouteLayers();

  Future<void> _onMapCreated(MapboxMap map) async {
    await map.location.updateSettings(LocationComponentSettings(enabled: false));
    await map.scaleBar.updateSettings(ScaleBarSettings(enabled: false));
    await _layers.attach(map);
    if (!mounted) return;
    await _layers.show(colors: context.colors, path: widget.path, pin: widget.path.last);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return IgnorePointer(
      child: MapWidget(
        styleUri: isDark ? MapboxStyles.DARK : MapboxStyles.LIGHT,
        viewport: OverviewViewportState(
          geometry: lineOf(widget.path),
          geometryPadding: const EdgeInsets.all(BrodieSpace.xl),
        ),
        onMapCreated: _onMapCreated,
      ),
    );
  }
}
