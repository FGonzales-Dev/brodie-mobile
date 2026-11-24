import 'package:brodie/features/group_ride/domain/group_ride_models.dart';
import 'package:brodie/features/group_ride/domain/position_codec.dart';
import 'package:brodie/features/map/domain/map_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const fix = RiderFix(
    seat: 3,
    latitude: 14.5995123,
    longitude: 120.9842199,
    headingDegrees: 87,
    speedKmh: 54,
    tripSeconds: 1234,
  );

  test('encodes to the compact wire format, coordinates rounded to 5 decimals', () {
    expect(PositionCodec.encode(fix), {
      's': 3,
      'a': [14.59951, 120.98422, 87, 54, 1234],
    });
  });

  test('round-trips through encode and decode', () {
    final decoded = PositionCodec.decode(PositionCodec.encode(fix));

    expect(decoded, fix.copyWith(latitude: 14.59951, longitude: 120.98422));
  });

  test('rejects malformed payloads from other devices', () {
    final invalid = <Map<String, dynamic>>[
      {},
      {'s': 3},
      {
        's': '3',
        'a': [14.5, 120.9, 0, 0, 0],
      },
      {
        's': 3,
        'a': [14.5, 120.9, 0, 0],
      },
      {
        's': 3,
        'a': [14.5, 'x', 0, 0, 0],
      },
      {
        's': 3,
        'a': [95.0, 120.9, 0, 0, 0],
      },
      {
        's': 3,
        'a': [14.5, 120.9, 0, -5, 0],
      },
      {
        's': -1,
        'a': [14.5, 120.9, 0, 0, 0],
      },
    ];

    for (final payload in invalid) {
      expect(PositionCodec.decode(payload), isNull, reason: '$payload');
    }
  });

  test('converts a device fix, tolerating unknown heading and speed', () {
    final startedAt = DateTime(2026, 10, 29, 8);
    final deviceFix = GeoFix(
      position: const GeoPoint(latitude: 14.6, longitude: 121.0),
      accuracyMeters: 5,
      speedMps: 22.2,
      headingDegrees: -1,
      timestamp: startedAt.add(const Duration(minutes: 2, seconds: 5)),
    );

    final converted = PositionCodec.fromDeviceFix(deviceFix, seat: 2, tripStartedAt: startedAt);

    expect(converted.speedKmh, 80);
    expect(converted.headingDegrees, 0);
    expect(converted.tripSeconds, 125);
  });
}
