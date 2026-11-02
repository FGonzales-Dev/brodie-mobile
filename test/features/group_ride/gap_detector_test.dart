import 'package:brodie/features/group_ride/domain/gap_detector.dart';
import 'package:brodie/features/group_ride/domain/group_ride_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final t0 = DateTime(2026, 10, 29, 8);
  DateTime at(int seconds) => t0.add(Duration(seconds: seconds));
  const cityMps = 30 / 3.6;

  late GapDetector detector;
  setUp(() => detector = GapDetector());

  RiderProgress rider(double along, {double speed = cityMps, DateTime? heard}) =>
      (alongRouteMeters: along, speedMps: speed, lastHeardAt: heard ?? t0);

  test('nobody is behind when the group is close together', () {
    expect(detector.evaluate({1: rider(5000), 2: rider(4600), 3: rider(4200)}, t0), isEmpty);
  });

  test('a big gap must last 60 s before it counts', () {
    // At 30 km/h the threshold is the 1 km minimum; seat 3 trails by 2 km.
    final riders = {1: rider(5000), 2: rider(4800), 3: rider(3000)};

    expect(detector.evaluate(riders, at(0)), isEmpty);
    expect(detector.evaluate(riders, at(59)), isEmpty);
    expect(detector.evaluate(riders, at(60)), {3});
  });

  test('catching up clears the streak', () {
    detector.evaluate({1: rider(5000), 3: rider(3000)}, at(0));
    detector.evaluate({1: rider(5000), 3: rider(4500)}, at(30));

    expect(detector.evaluate({1: rider(5000), 3: rider(3000)}, at(70)), isEmpty);
  });

  test('the threshold grows with group speed', () {
    // At 100 km/h, 90 s is 2.5 km, so a 2 km gap is normal spacing.
    const highwayMps = 100 / 3.6;
    final riders = {1: rider(9000, speed: highwayMps), 2: rider(7000, speed: highwayMps)};

    detector.evaluate(riders, at(0));
    expect(detector.evaluate(riders, at(90)), isEmpty);
  });

  test('a rider silent for 2 minutes is behind straight away', () {
    final riders = {1: rider(5000, heard: at(130)), 2: rider(4900, heard: at(0))};

    expect(detector.evaluate(riders, at(130)), {2});
  });

  test('RiderStatus goes live → stale → lost by silence', () {
    expect(RiderStatus.at(lastHeardAt: t0, now: at(39)), RiderStatus.live);
    expect(RiderStatus.at(lastHeardAt: t0, now: at(40)), RiderStatus.stale);
    expect(RiderStatus.at(lastHeardAt: t0, now: at(180)), RiderStatus.lost);
  });
}
