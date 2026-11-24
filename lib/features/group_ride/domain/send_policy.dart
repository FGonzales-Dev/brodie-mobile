import '../../map/domain/map_models.dart';
import '../../map/domain/route_geometry.dart';

/// Limits for how often a rider's position goes out.
class SendProfile {
  const SendProfile({
    required this.minInterval,
    required this.minDistanceMeters,
    required this.heartbeat,
    this.maxAccuracyMeters = 50,
  });

  /// Never send more often than this.
  final Duration minInterval;

  /// Send once the rider has moved this far from the last sent position.
  final double minDistanceMeters;

  /// Send at least this often, even when stopped, so others know the rider
  /// is still there.
  final Duration heartbeat;

  /// Fixes less accurate than this don't count as movement.
  final double maxAccuracyMeters;

  /// Screen on, the normal case. [intervalSeconds] is the user's
  /// broadcast-interval setting (clamped to 3–30 s).
  factory SendProfile.foreground({required int intervalSeconds}) => SendProfile(
        minInterval: Duration(seconds: intervalSeconds.clamp(3, 30)),
        minDistanceMeters: 50,
        heartbeat: const Duration(seconds: 60),
      );

  factory SendProfile.batterySaver({required int intervalSeconds}) => SendProfile(
        minInterval: Duration(seconds: intervalSeconds.clamp(10, 30)),
        minDistanceMeters: 75,
        heartbeat: const Duration(seconds: 120),
      );

  /// Screen locked: sends go over REST and the rider receives nothing.
  static const background = SendProfile(
    minInterval: Duration(seconds: 15),
    minDistanceMeters: 75,
    heartbeat: Duration(seconds: 120),
  );

  /// The profile for a started ride; background wins over battery saver.
  factory SendProfile.forRide({required int intervalSeconds, required bool batterySaver, required bool inBackground}) {
    if (inBackground) return background;
    return batterySaver
        ? SendProfile.batterySaver(intervalSeconds: intervalSeconds)
        : SendProfile.foreground(intervalSeconds: intervalSeconds);
  }
}

/// Decides whether to broadcast a fix. Supabase bills every broadcast once
/// for the send plus once per receiving rider, so fewer sends is the main
/// usage lever. v1 rule: respect [SendProfile.minInterval], then send when
/// the rider has moved [SendProfile.minDistanceMeters] or the heartbeat is
/// due. A predictive (dead-reckoning) rule can replace this behind the same
/// interface if real rides show it's worth it.
class SendPolicy {
  SendPolicy(this.profile);

  /// Swapped when the app moves between foreground and background.
  SendProfile profile;

  GeoFix? _lastSent;
  DateTime? _lastSentAt;

  /// Call on every new fix and on a periodic tick, since GPS stops
  /// reporting while the rider is stationary.
  bool shouldSend(GeoFix fix, DateTime now) {
    final lastSent = _lastSent;
    final lastSentAt = _lastSentAt;
    if (lastSent == null || lastSentAt == null) return true;

    final elapsed = now.difference(lastSentAt);
    if (elapsed < profile.minInterval) return false;
    if (elapsed >= profile.heartbeat) return true;
    if (fix.accuracyMeters > profile.maxAccuracyMeters) return false;
    return distanceBetween(lastSent.position, fix.position) >= profile.minDistanceMeters;
  }

  void markSent(GeoFix fix, DateTime now) {
    _lastSent = fix;
    _lastSentAt = now;
  }
}
