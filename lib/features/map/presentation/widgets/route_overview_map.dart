import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' hide Size;

import '../../../../core/design_system/design_system.dart';
import '../../domain/map_models.dart';
import 'route_layers.dart';

/// A route framed to fit: a ride in history, a group's planned trip. Drawn
/// as an outline (start, line, finish) without loading a map, so these
/// screens open fast and use no map data; "Show on map" swaps in the real
/// map when the rider wants the streets. Not interactive either way, so it
/// can sit inside a scrolling page.
class RouteOverviewMap extends StatefulWidget {
  const RouteOverviewMap({super.key, required this.path});

  final List<GeoPoint> path;

  @override
  State<RouteOverviewMap> createState() => _RouteOverviewMapState();
}

class _RouteOverviewMapState extends State<RouteOverviewMap> {
  var _showMap = false;

  @override
  Widget build(BuildContext context) {
    if (_showMap) return _RouteMap(path: widget.path);
    final colors = context.colors;
    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(
          color: colors.surfaceRaised,
          child: CustomPaint(
            painter: RouteSketchPainter(
              path: widget.path,
              line: colors.primaryAction,
              lineBorder: colors.onPrimaryAction,
              start: colors.textSecondary,
              finish: colors.accent,
              finishBorder: colors.onAccent,
            ),
          ),
        ),
        Positioned(
          right: BrodieSpace.sm,
          bottom: BrodieSpace.sm,
          child: BrodieButton.secondary(
            label: 'Show on map',
            icon: Icons.map_outlined,
            compact: true,
            onPressed: () => setState(() => _showMap = true),
          ),
        ),
      ],
    );
  }
}

/// Draws a route's shape scaled to fit, keeping its true proportions.
class RouteSketchPainter extends CustomPainter {
  RouteSketchPainter({
    required this.path,
    required this.line,
    required this.lineBorder,
    required this.start,
    required this.finish,
    required this.finishBorder,
  });

  final List<GeoPoint> path;
  final Color line;
  final Color lineBorder;
  final Color start;
  final Color finish;
  final Color finishBorder;

  static const _padding = 32.0;

  /// [path] as points within [size], or empty when there's nothing to draw.
  static List<Offset> fit(List<GeoPoint> path, Size size) {
    if (path.length < 2) return const [];
    // Flat projection around the route's middle latitude: true enough for
    // the shape of a ride.
    final midLatitude = path.map((p) => p.latitude).reduce((a, b) => a + b) / path.length;
    final xScale = math.cos(midLatitude * math.pi / 180);
    final points = [for (final p in path) Offset(p.longitude * xScale, -p.latitude)];
    final left = points.map((p) => p.dx).reduce(math.min);
    final right = points.map((p) => p.dx).reduce(math.max);
    final top = points.map((p) => p.dy).reduce(math.min);
    final bottom = points.map((p) => p.dy).reduce(math.max);
    final width = math.max(right - left, 1e-9);
    final height = math.max(bottom - top, 1e-9);
    final scale = math.min((size.width - 2 * _padding) / width, (size.height - 2 * _padding) / height);
    final offset = Offset(
      (size.width - width * scale) / 2 - left * scale,
      (size.height - height * scale) / 2 - top * scale,
    );
    return [for (final p in points) p * scale + offset];
  }

  @override
  void paint(Canvas canvas, Size size) {
    final points = fit(path, size);
    if (points.isEmpty) return;
    final route = Path()..addPolygon(points, false);
    Paint stroke(Color color, double width) => Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas
      ..drawPath(route, stroke(lineBorder, 10))
      ..drawPath(route, stroke(line, 6))
      ..drawCircle(points.first, 6, Paint()..color = start)
      ..drawCircle(points.last, 11, Paint()..color = finishBorder)
      ..drawCircle(points.last, 8, Paint()..color = finish);
  }

  @override
  bool shouldRepaint(RouteSketchPainter old) =>
      old.path != path || old.line != line || old.start != start || old.finish != finish;
}

/// The real map, loaded on request.
class _RouteMap extends StatefulWidget {
  const _RouteMap({required this.path});

  final List<GeoPoint> path;

  @override
  State<_RouteMap> createState() => _RouteMapState();
}

class _RouteMapState extends State<_RouteMap> {
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
