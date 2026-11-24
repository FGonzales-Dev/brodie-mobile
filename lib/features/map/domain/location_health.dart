import 'map_models.dart';

/// Sent down a position stream when the phone stops giving the app
/// locations: location access was revoked, or location was switched off.
class LocationAccessLost implements Exception {
  const LocationAccessLost(this.access);

  /// [LocationAccess.denied], [LocationAccess.deniedForever] or
  /// [LocationAccess.serviceDisabled].
  final LocationAccess access;

  @override
  String toString() => 'LocationAccessLost($access)';
}

/// What's wrong with the ride's location right now, worst first.
enum LocationIssue {
  /// Location is switched off for the whole phone.
  serviceDisabled,

  /// Brodie's location access was turned off.
  permissionDenied,

  /// No new position for a while although the rider was moving: tunnels,
  /// deep valleys, or GPS giving up.
  signalLost,

  /// Positions arrive but are too inaccurate to trust.
  weakSignal,
  none;

  static const weakAccuracyMeters = 50.0;
  static const lostAfter = Duration(seconds: 30);

  /// A rider faster than this (about 7 km/h) should be producing positions.
  static const movingSpeedMps = 2.0;

  /// Positions only arrive after the rider moves a few meters, so silence
  /// alone means nothing: a rider stopped at lights gets none either.
  /// Silence counts as a lost signal only if the last position was moving,
  /// or if there has never been one.
  static LocationIssue at({
    required GeoFix? lastFix,
    required LocationAccess? accessLost,
    required DateTime startedAt,
    required DateTime now,
  }) {
    switch (accessLost) {
      case LocationAccess.serviceDisabled:
        return serviceDisabled;
      case LocationAccess.denied || LocationAccess.deniedForever:
        return permissionDenied;
      case LocationAccess.always || LocationAccess.whileInUse || null:
        break;
    }
    if (lastFix == null) return now.difference(startedAt) >= lostAfter ? signalLost : none;

    final speed = lastFix.speedMps.isFinite ? lastFix.speedMps : 0;
    if (now.difference(lastFix.timestamp) >= lostAfter && speed >= movingSpeedMps) return signalLost;
    if (lastFix.accuracyMeters > weakAccuracyMeters) return weakSignal;
    return none;
  }
}
