import 'package:brodie/features/group_ride/domain/send_policy.dart';
import 'package:brodie/features/map/domain/map_models.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/geo.dart';

typedef Leg = ({Duration duration, double speedKmh});

/// Replays a ride at one GPS fix (or stationary tick) per second and counts
/// how many positions [policy] would broadcast.
int countSends(SendPolicy policy, List<Leg> legs) {
  var position = const GeoPoint(latitude: 14.1, longitude: 120.9);
  var now = DateTime(2026, 10, 29, 8);
  var sends = 0;
  for (final leg in legs) {
    final metersPerSecond = leg.speedKmh / 3.6;
    for (var second = 0; second < leg.duration.inSeconds; second++) {
      now = now.add(const Duration(seconds: 1));
      position = north(position, metersPerSecond);
      final fix = fixAt(position, now, speedMps: metersPerSecond);
      if (policy.shouldSend(fix, now)) {
        policy.markSent(fix, now);
        sends++;
      }
    }
  }
  return sends;
}

Leg minutesAt(int minutes, double speedKmh) => (duration: Duration(minutes: minutes), speedKmh: speedKmh);

void main() {
  final foreground = SendProfile.foreground(intervalSeconds: 5);
  final t0 = DateTime(2026, 10, 29, 8);
  const here = GeoPoint(latitude: 14.1, longitude: 120.9);

  test('sends the first fix immediately', () {
    expect(SendPolicy(foreground).shouldSend(fixAt(here, t0), t0), isTrue);
  });

  test('never sends faster than the minimum interval', () {
    final policy = SendPolicy(foreground)..markSent(fixAt(here, t0), t0);
    final farAway = north(here, 500);

    expect(policy.shouldSend(fixAt(farAway, t0), t0.add(const Duration(seconds: 4))), isFalse);
    expect(policy.shouldSend(fixAt(farAway, t0), t0.add(const Duration(seconds: 5))), isTrue);
  });

  test('a stationary rider sends only the heartbeat', () {
    expect(countSends(SendPolicy(foreground), [minutesAt(10, 0)]), 10);
  });

  test('inaccurate fixes do not count as movement, but the heartbeat still goes out', () {
    final policy = SendPolicy(foreground)..markSent(fixAt(here, t0), t0);
    final jumped = fixAt(north(here, 200), t0, accuracyMeters: 120);

    expect(policy.shouldSend(jumped, t0.add(const Duration(seconds: 30))), isFalse);
    expect(policy.shouldSend(jumped, t0.add(const Duration(seconds: 60))), isTrue);
  });

  group('usage budget', () {
    // A typical 2 h ride: town, highway, a fuel stop, town, lunch.
    final mixedRide = [
      minutesAt(20, 25),
      minutesAt(60, 80),
      minutesAt(10, 0),
      minutesAt(10, 25),
      minutesAt(20, 0),
    ];
    const naiveSends = 2 * 60 * 60 ~/ 5; // fixed 5 s interval: 1440

    test('mixed 2 h ride sends at least 30% less than a fixed 5 s interval', () {
      final sends = countSends(SendPolicy(foreground), mixedRide);

      expect(sends, lessThanOrEqualTo(naiveSends * 0.7));
    });

    test('battery saver roughly halves it again', () {
      final sends = countSends(SendPolicy(SendProfile.batterySaver(intervalSeconds: 5)), mixedRide);

      expect(sends, lessThanOrEqualTo(naiveSends * 0.4));
    });

    test('a locked phone on the highway sends every 15 s at most', () {
      expect(countSends(SendPolicy(SendProfile.background), [minutesAt(60, 80)]), lessThanOrEqualTo(240));
    });
  });

  test('forRide picks background over battery saver', () {
    final profile = SendProfile.forRide(intervalSeconds: 5, batterySaver: true, inBackground: true);

    expect(profile, same(SendProfile.background));
  });
}
