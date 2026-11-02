import 'package:brodie/features/map/domain/map_models.dart';
import 'package:brodie/features/map/domain/route_geometry.dart';
import 'package:brodie/features/map/domain/track_recorder.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/geo.dart';

void main() {
  const start = GeoPoint(latitude: 14.1, longitude: 120.9);
  final at = DateTime(2026, 11, 2, 8);

  /// Feeds a fix every second, [metersPerSecond] north of the last.
  TrackRecorder rideNorth({required int seconds, double metersPerSecond = 10}) {
    final track = TrackRecorder();
    for (var s = 0; s <= seconds; s++) {
      track.add(fixAt(north(start, s * metersPerSecond), at.add(Duration(seconds: s)), speedMps: metersPerSecond));
    }
    return track;
  }

  test('sums real movement and ignores jitter and bad fixes', () {
    final track = TrackRecorder();
    for (final (meters, accuracy) in [(0.0, 5.0), (2.0, 5.0), (10.0, 5.0), (400.0, 90.0), (20.0, 5.0)]) {
      track.add(fixAt(north(start, meters), at, accuracyMeters: accuracy));
    }

    expect(track.distanceMeters, closeTo(20, 0.5));
  });

  test('a straight ride saves as just its two ends', () {
    final track = rideNorth(seconds: 60);

    expect(track.path, hasLength(2));
    expect(distanceBetween(track.path.first, start), lessThan(0.5));
    expect(distanceBetween(track.path.last, north(start, 600)), lessThan(0.5));
  });

  test('keeps the corner of a turn', () {
    final track = TrackRecorder();
    final corner = north(start, 500);
    var t = 0;
    for (var m = 0.0; m <= 500; m += 10) {
      track.add(fixAt(north(start, m), at.add(Duration(seconds: t++)), speedMps: 10));
    }
    for (var m = 10.0; m <= 500; m += 10) {
      track.add(fixAt(east(corner, m), at.add(Duration(seconds: t++)), speedMps: 10));
    }

    expect(track.path, hasLength(3));
    expect(distanceBetween(track.path[1], corner), lessThan(1));
  });

  test('ends the path at the last accurate position, even a short step on', () {
    final track = rideNorth(seconds: 10)..add(fixAt(north(start, 104), at.add(const Duration(seconds: 11))));

    expect(distanceBetween(track.path.last, north(start, 104)), lessThan(0.5));
  });

  test('counts moving time, not stops or gaps in signal', () {
    final track = TrackRecorder();
    var position = start;
    var time = at;
    void ride(int seconds, {double speed = 10, Duration step = const Duration(seconds: 1)}) {
      for (var s = 0; s < seconds; s++) {
        time = time.add(step);
        position = north(position, speed * step.inSeconds);
        track.add(fixAt(position, time, speedMps: speed));
      }
    }

    track.add(fixAt(position, time));
    ride(60); // 1 min riding
    ride(30, speed: 0); // stopped at lights
    time = time.add(const Duration(minutes: 5)); // tunnel: no fixes
    ride(60); // 1 min riding (the first fix after the gap doesn't count)

    expect(track.movingTime, const Duration(seconds: 119));
  });

  test('tracks top speed and ignores impossible readings', () {
    final track = TrackRecorder()
      ..add(fixAt(start, at, speedMps: 20))
      ..add(fixAt(north(start, 30), at.add(const Duration(seconds: 1)), speedMps: 31))
      ..add(fixAt(north(start, 60), at.add(const Duration(seconds: 2)), speedMps: 250))
      ..add(fixAt(north(start, 90), at.add(const Duration(seconds: 3)), speedMps: 45, accuracyMeters: 80));

    expect(track.maxSpeedMps, 31);
  });

  test('records nothing from inaccurate fixes', () {
    final track = TrackRecorder()..add(fixAt(start, at, accuracyMeters: 80));

    expect(track.path, isEmpty);
    expect(track.distanceMeters, 0);
  });
}
