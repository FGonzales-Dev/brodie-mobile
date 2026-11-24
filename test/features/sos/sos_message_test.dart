import 'package:brodie/features/group_ride/domain/position_codec.dart';
import 'package:brodie/features/map/domain/map_models.dart';
import 'package:brodie/features/sos/domain/sos_message.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

final _fix = GeoFix(
  position: const GeoPoint(latitude: 14.1153, longitude: 120.9621),
  accuracyMeters: 8.4,
  speedMps: 0,
  headingDegrees: 0,
  timestamp: DateTime.utc(2026, 11, 25, 0, 4),
);

void main() {
  test('the text names the rider and links their location', () {
    final text = SosMessage.text(username: 'alex_rides', fix: _fix, time: '8:04 AM');
    expect(text, startsWith('SOS from @alex_rides on Brodie. I may need help.'));
    expect(text, contains('https://maps.google.com/?q=14.115300,120.962100'));
    expect(text, contains('within 8 m, at 8:04 AM'));
  });

  test('the text still goes out without a location or username', () {
    final text = SosMessage.text(username: null, fix: null, time: '');
    expect(text, contains('SOS from a Brodie rider.'));
    expect(text, contains('I could not get my location.'));
    expect(text, isNot(contains('maps.google.com')));
  });

  test('Android texts every contact, comma-separated', () {
    final uri = SosMessage.smsUri(['+63 917 123 4567', '(0918) 765-4321'], 'Help me', platform: TargetPlatform.android);
    expect(uri.toString(), 'sms:+639171234567,09187654321?body=Help%20me');
  });

  test('iOS uses its several-recipients form', () {
    final uri = SosMessage.smsUri(['+63 917 123 4567', '0918 765 4321'], 'Help me', platform: TargetPlatform.iOS);
    expect(uri.toString(), 'sms:/open?addresses=+639171234567,09187654321&body=Help%20me');
  });

  test('the body survives characters with meaning in a URL', () {
    final body = SosMessage.text(username: 'a&b', fix: _fix, time: '8:04 AM');
    final uri = SosMessage.smsUri(['123'], body, platform: TargetPlatform.android);
    expect(Uri.decodeComponent(uri.toString().split('body=').last), body);
  });

  test('numbers with nothing dialable are skipped', () {
    final uri = SosMessage.smsUri(['call me', '555 0100'], 'x', platform: TargetPlatform.android);
    expect(uri.toString(), 'sms:5550100?body=x');
  });

  test('calls dial the cleaned number', () {
    expect(SosMessage.callUri('+63 917 123-4567').toString(), 'tel:+639171234567');
  });

  group('SOS on the trip channel', () {
    final fix = PositionCodec.fromDeviceFix(_fix, seat: 2, tripStartedAt: DateTime.utc(2026, 11, 25));

    test('round-trips with a position', () {
      final decoded = PositionCodec.decodeSos(PositionCodec.encodeSos((seat: 2, active: true, fix: fix)))!;
      expect(decoded.seat, 2);
      expect(decoded.active, isTrue);
      expect(decoded.fix?.latitude, closeTo(14.1153, 1e-5));
    });

    test('round-trips without one, and when turned off', () {
      final off = PositionCodec.decodeSos(PositionCodec.encodeSos((seat: 2, active: false, fix: null)))!;
      expect(off.active, isFalse);
      expect(off.fix, isNull);
    });

    test('a broken position keeps the alert', () {
      final decoded = PositionCodec.decodeSos({'s': 1, 'on': true, 'a': ['bad']})!;
      expect(decoded.active, isTrue);
      expect(decoded.fix, isNull);
    });

    test('rejects malformed alerts', () {
      expect(PositionCodec.decodeSos({'s': -1, 'on': true}), isNull);
      expect(PositionCodec.decodeSos({'s': 1}), isNull);
      expect(PositionCodec.decodeSos({'on': true}), isNull);
    });
  });
}
