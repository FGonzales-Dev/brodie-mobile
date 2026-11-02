import 'package:flutter/material.dart';

import '../../../../core/design_system/design_system.dart';

/// Decorative street grid with a highlighted route, fading into the
/// background. Drawn in code so it follows the theme colors.
class RoadArt extends StatelessWidget {
  const RoadArt({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (bounds) => const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Colors.black, Colors.transparent],
        stops: [.45, 1],
      ).createShader(bounds),
      child: CustomPaint(
        size: Size.infinite,
        painter: _RoadArtPainter(road: colors.surfaceRaised, minorRoad: colors.surface, route: colors.accent),
      ),
    );
  }
}

class _RoadArtPainter extends CustomPainter {
  _RoadArtPainter({required this.road, required this.minorRoad, required this.route});

  final Color road;
  final Color minorRoad;
  final Color route;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final minor = Paint()
      ..color = minorRoad
      ..strokeWidth = 6;
    for (final x in [.15, .6, .86]) {
      canvas.drawLine(Offset(w * x, 0), Offset(w * x, h), minor);
    }
    for (final y in [.18, .55, .9]) {
      canvas.drawLine(Offset(0, h * y), Offset(w, h * y), minor);
    }

    final major = Paint()
      ..color = road
      ..strokeWidth = 12
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(w * .4, 0), Offset(w * .4, h), major);
    canvas.drawLine(Offset(0, h * .72), Offset(w, h * .72), major);
    canvas.drawPath(
      Path()
        ..moveTo(0, h * 1.05)
        ..quadraticBezierTo(w * .55, h * .62, w * 1.05, h * .1),
      major,
    );

    final routePaint = Paint()
      ..color = route
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(
      Path()
        ..moveTo(w * .4, h * 1.1)
        ..lineTo(w * .4, h * .72)
        ..lineTo(w * .6, h * .72)
        ..lineTo(w * .6, h * .2),
      routePaint,
    );
  }

  @override
  bool shouldRepaint(_RoadArtPainter old) => old.road != road || old.minorRoad != minorRoad || old.route != route;
}
