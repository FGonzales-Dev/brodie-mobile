import '../../map/domain/map_models.dart';
import 'group_ride_models.dart';

/// Wire format for position broadcasts: `{"s": seat, "a": [lat, lng, heading,
/// km/h, tripSeconds]}`. Short keys and one flat array keep each message
/// small, since it is sent to every rider every few seconds. Coordinates are
/// rounded to 5 decimals (about 1 m).
abstract final class PositionCodec {
  static Map<String, Object> encode(RiderFix fix) => {
        's': fix.seat,
        'a': [
          _round5(fix.latitude),
          _round5(fix.longitude),
          fix.headingDegrees,
          fix.speedKmh,
          fix.tripSeconds,
        ],
      };

  /// Returns null for anything malformed: payloads come from other devices.
  static RiderFix? decode(Map<String, dynamic> payload) {
    final seat = payload['s'];
    final values = payload['a'];
    if (seat is! int || seat < 0 || values is! List || values.length != 5) return null;
    if (values.any((value) => value is! num)) return null;

    final [lat, lng, heading, speed, seconds] = values.cast<num>();
    if (lat.abs() > 90 || lng.abs() > 180 || speed < 0 || seconds < 0) return null;
    return RiderFix(
      seat: seat,
      latitude: lat.toDouble(),
      longitude: lng.toDouble(),
      headingDegrees: heading.round() % 360,
      speedKmh: speed.round(),
      tripSeconds: seconds.round(),
    );
  }

  /// Converts a device reading into what gets broadcast.
  static RiderFix fromDeviceFix(GeoFix fix, {required int seat, required DateTime tripStartedAt}) {
    // GPS reports a negative or NaN heading/speed when it doesn't know one.
    final heading = fix.headingDegrees.isFinite && fix.headingDegrees >= 0 ? fix.headingDegrees.round() % 360 : 0;
    final speedKmh = fix.speedMps.isFinite && fix.speedMps > 0 ? (fix.speedMps * 3.6).round() : 0;
    final seconds = fix.timestamp.difference(tripStartedAt).inSeconds;
    return RiderFix(
      seat: seat,
      latitude: fix.position.latitude,
      longitude: fix.position.longitude,
      headingDegrees: heading,
      speedKmh: speedKmh,
      tripSeconds: seconds < 0 ? 0 : seconds,
    );
  }

  static double _round5(double value) => (value * 1e5).roundToDouble() / 1e5;
}
