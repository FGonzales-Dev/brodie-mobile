/// Decides when a rider has really left the route, so a re-route (a billed
/// Directions request) happens only for a sustained deviation: not for GPS
/// jitter, a brief detour, or a rider who is already heading back.
///
/// Feed it every fix with [onFix]; when it returns true, request a new route
/// and report the result with [rerouteFinished].
class OffRouteDetector {
  OffRouteDetector({
    this.thresholdMeters = 100,
    this.minConsecutiveFixes = 3,
    this.minDuration = const Duration(seconds: 15),
    this.maxAccuracyMeters = 30,
    this.approachMarginMeters = 10,
    this.cooldown = const Duration(minutes: 2),
    this.maxReroutes = 15,
  });

  final double thresholdMeters;
  final int minConsecutiveFixes;
  final Duration minDuration;

  /// Fixes less accurate than this are ignored: too noisy to judge.
  final double maxAccuracyMeters;

  /// Getting this much closer between fixes counts as heading back.
  final double approachMarginMeters;
  final Duration cooldown;
  final int maxReroutes;

  int _streak = 0;
  DateTime? _streakStart;
  double? _lastDistance;
  DateTime? _cooldownUntil;
  bool _awaitingRoute = false;
  int _reroutes = 0;

  int get reroutesUsed => _reroutes;

  bool onFix({required double distanceFromRoute, required double accuracyMeters, required DateTime at}) {
    if (accuracyMeters > maxAccuracyMeters) return false;
    if (distanceFromRoute <= thresholdMeters) {
      _resetStreak();
      return false;
    }

    final previous = _lastDistance;
    final approaching = previous != null && distanceFromRoute < previous - approachMarginMeters;
    _streak++;
    _streakStart ??= at;
    _lastDistance = distanceFromRoute;

    final cooling = _cooldownUntil != null && at.isBefore(_cooldownUntil!);
    if (_awaitingRoute || cooling || approaching || _reroutes >= maxReroutes) return false;
    if (_streak < minConsecutiveFixes || at.difference(_streakStart!) < minDuration) return false;

    _awaitingRoute = true;
    return true;
  }

  /// The re-route requested after [onFix] returned true has finished.
  /// Failures also start the cooldown, so a failing service isn't hammered.
  void rerouteFinished(DateTime at, {required bool succeeded}) {
    _awaitingRoute = false;
    if (succeeded) _reroutes++;
    _startCooldown(at);
  }

  /// A new route arrived that this rider didn't request (e.g. the leader's).
  void routeChanged(DateTime at) => _startCooldown(at);

  void _startCooldown(DateTime at) {
    _cooldownUntil = at.add(cooldown);
    _resetStreak();
  }

  void _resetStreak() {
    _streak = 0;
    _streakStart = null;
    _lastDistance = null;
  }
}
