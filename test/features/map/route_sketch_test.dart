import 'package:brodie/core/design_system/design_system.dart';
import 'package:brodie/features/map/domain/map_models.dart';
import 'package:brodie/features/map/presentation/widgets/route_overview_map.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/geo.dart';

const _start = GeoPoint(latitude: 14.1, longitude: 120.9);

void main() {
  test('a route is scaled to fit, keeping its shape', () {
    // 2 km north, then 1 km east: an L twice as tall as it is wide.
    final path = [_start, north(_start, 2000), east(north(_start, 2000), 1000)];
    final points = RouteSketchPainter.fit(path, const Size(400, 400));

    final xs = points.map((p) => p.dx);
    final ys = points.map((p) => p.dy);
    final width = xs.reduce((a, b) => a > b ? a : b) - xs.reduce((a, b) => a < b ? a : b);
    final height = ys.reduce((a, b) => a > b ? a : b) - ys.reduce((a, b) => a < b ? a : b);
    expect(height, closeTo(400 - 64, 1), reason: 'the long side fills the space, less padding');
    expect(width / height, closeTo(.5, .01));
    expect(points.first.dy, greaterThan(points[1].dy), reason: 'north is up');
    expect(points.last.dx, greaterThan(points[1].dx), reason: 'east is right');
  });

  test('nothing to draw for less than two points', () {
    expect(RouteSketchPainter.fit(const [_start], const Size(100, 100)), isEmpty);
  });

  testWidgets('shows the outline, and loads the map only on request', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: SizedBox(height: 220, child: RouteOverviewMap(path: [_start, north(_start, 1000)])),
        ),
      ),
    );
    expect(find.byType(CustomPaint), findsWidgets);
    expect(find.text('SHOW ON MAP'), findsOneWidget);
  });
}
