// Draws Brodie's app icon: the brand mark (a black navigation arrow on the
// accent yellow, as in BrandMark) at launcher sizes.
//
//   dart run tool/generate_app_icon.dart
//   dart run flutter_launcher_icons
//
// Writes assets/icon/app_icon.png (full icon, for iOS and older Android)
// and assets/icon/app_icon_foreground.png (arrow only, for Android's
// adaptive icon, whose background color is set in pubspec.yaml).
import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as img;

const _size = 1024;

/// Drawn this many times larger, then scaled down, for smooth edges.
const _supersample = 4;

final _yellow = img.ColorRgba8(0xFF, 0xC4, 0x00, 0xFF);
final _black = img.ColorRgba8(0x00, 0x00, 0x00, 0xFF);
final _clear = img.ColorRgba8(0, 0, 0, 0);

/// A navigation arrow (tip, left wing, notch, right wing) in a 24×24 grid,
/// like Material's "navigation" glyph without its clipped corners.
const _arrow = [(12.0, 2.0), (4.5, 20.5), (12.0, 16.5), (19.5, 20.5)];

void main() {
  // The full icon: iOS masks the corners itself, so it's a full square.
  _write('assets/icon/app_icon.png', background: _yellow, arrowShare: .56);
  // Android's adaptive icon shows the middle 72/108 of the canvas, and
  // flutter_launcher_icons insets this layer by a further 16% a side, so the
  // arrow is drawn larger here to end up the same size as on iOS.
  _write('assets/icon/app_icon_foreground.png', background: _clear, arrowShare: .60);
}

void _write(String path, {required img.Color background, required double arrowShare}) {
  const big = _size * _supersample;
  final canvas = img.Image(width: big, height: big, numChannels: 4);
  img.fill(canvas, color: background);

  // Tilted like a heading on a map, then centered by its outline so it
  // looks balanced in the square.
  final scale = big * arrowShare / 18.5;
  const angle = 45 * math.pi / 180;
  final rotated = [
    for (final (x, y) in _arrow)
      (
        x * scale * math.cos(angle) - y * scale * math.sin(angle),
        x * scale * math.sin(angle) + y * scale * math.cos(angle),
      ),
  ];
  final xs = rotated.map((p) => p.$1);
  final ys = rotated.map((p) => p.$2);
  final shiftX = big / 2 - (xs.reduce(math.min) + xs.reduce(math.max)) / 2;
  final shiftY = big / 2 - (ys.reduce(math.min) + ys.reduce(math.max)) / 2;
  img.fillPolygon(canvas, vertices: [for (final (x, y) in rotated) img.Point(x + shiftX, y + shiftY)], color: _black);

  final icon = img.copyResize(canvas, width: _size, height: _size, interpolation: img.Interpolation.average);
  File(path)
    ..createSync(recursive: true)
    ..writeAsBytesSync(img.encodePng(icon));
  stdout.writeln('Wrote $path');
}
