import 'package:brodie/features/map/domain/off_route_detector.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final t0 = DateTime(2026, 10, 29, 8);
  DateTime at(int seconds) => t0.add(Duration(seconds: seconds));

  late OffRouteDetector detector;
  setUp(() => detector = OffRouteDetector());

  /// Feeds fixes 5 s apart and returns the indexes that triggered a re-route.
  List<int> feed(List<double> distances, {double accuracy = 10, int startSecond = 0}) => [
        for (final (i, distance) in distances.indexed)
          if (detector.onFix(distanceFromRoute: distance, accuracyMeters: accuracy, at: at(startSecond + i * 5))) i,
      ];

  test('ignores GPS jitter around the threshold', () {
    expect(feed([120, 80, 130, 90, 125, 70, 140, 60]), isEmpty);
  });

  test('fires once a deviation lasts 3 fixes and 15 s', () {
    // Fix 2 is the third fix but only 10 s in; fix 3 meets both rules.
    expect(feed([120, 130, 140, 150, 160]), [3]);
  });

  test('ignores inaccurate fixes', () {
    expect(feed([300, 300, 300, 300, 300], accuracy: 45), isEmpty);
  });

  test('does not re-route a rider who is heading back to the route', () {
    expect(feed([300, 280, 260, 240, 220]), isEmpty);
  });

  test('fires once per request, then cools down for 2 minutes', () {
    expect(feed([150, 160, 170, 180, 190, 200]), [3], reason: 'no repeat while the request is pending');

    detector.rerouteFinished(at(30), succeeded: true);
    // Still off the new route for the whole cooldown (35 s … 145 s).
    expect(feed([for (var i = 0; i < 23; i++) 150.0 + i], startSecond: 35), isEmpty);
    // The deviation never ended, so it re-routes as soon as the cooldown does.
    expect(feed([175], startSecond: 150), [0]);
    expect(detector.reroutesUsed, 1);
  });

  test('getting back on route during the cooldown restarts the count', () {
    feed([150, 160, 170, 180]);
    detector.rerouteFinished(at(20), succeeded: true);
    feed([150, 160, 40, 30], startSecond: 25);

    // Off route again after the cooldown: needs 3 fixes and 15 s once more.
    expect(feed([150, 160, 170, 180], startSecond: 150), [3]);
  });

  test('stops after the per-trip re-route limit', () {
    final limited = OffRouteDetector(maxReroutes: 1, cooldown: Duration.zero);
    bool onFix(int second) => limited.onFix(distanceFromRoute: 200, accuracyMeters: 10, at: at(second));

    expect([for (var s = 0; s <= 15; s += 5) onFix(s)], [false, false, false, true]);
    limited.rerouteFinished(at(16), succeeded: true);
    expect([for (var s = 20; s <= 120; s += 5) onFix(s)], everyElement(isFalse));
  });
}
