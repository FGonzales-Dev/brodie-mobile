import 'dart:math' as math;

/// What the detector needs to know about one rider.
typedef RiderProgress = ({double alongRouteMeters, double speedMps, DateTime lastHeardAt});

/// Works out who has fallen behind, on each phone, from positions it already
/// receives, so it costs no extra messages or database writes.
///
/// A rider is behind when they trail the front-most rider along the route by
/// more than max([minGapMeters], [gapTime] at the group's median speed) for
/// at least [persistFor], or when nothing has been heard from them for
/// [silentAfter].
class GapDetector {
  GapDetector({
    this.minGapMeters = 1000,
    this.gapTime = const Duration(seconds: 90),
    this.persistFor = const Duration(seconds: 60),
    this.silentAfter = const Duration(minutes: 2),
  });

  final double minGapMeters;
  final Duration gapTime;
  final Duration persistFor;
  final Duration silentAfter;

  /// When each seat first exceeded the gap threshold in the current streak.
  final _overThresholdSince = <int, DateTime>{};

  /// Seats currently behind, keyed the same as [riders].
  Set<int> evaluate(Map<int, RiderProgress> riders, DateTime now) {
    _overThresholdSince.removeWhere((seat, _) => !riders.containsKey(seat));

    final silent = {
      for (final MapEntry(key: seat, value: progress) in riders.entries)
        if (now.difference(progress.lastHeardAt) >= silentAfter) seat,
    };
    final heard = {
      for (final entry in riders.entries)
        if (!silent.contains(entry.key)) entry.key: entry.value,
    };
    if (heard.isEmpty) return silent;

    final front = heard.values.map((progress) => progress.alongRouteMeters).reduce(math.max);
    final speeds = heard.values.map((progress) => progress.speedMps).toList()..sort();
    final medianSpeed = speeds[speeds.length ~/ 2];
    final threshold = math.max(minGapMeters, medianSpeed * gapTime.inSeconds);

    final behind = {...silent};
    for (final MapEntry(key: seat, value: progress) in heard.entries) {
      if (front - progress.alongRouteMeters > threshold) {
        final since = _overThresholdSince.putIfAbsent(seat, () => now);
        if (now.difference(since) >= persistFor) behind.add(seat);
      } else {
        _overThresholdSince.remove(seat);
      }
    }
    return behind;
  }
}
