import 'package:freezed_annotation/freezed_annotation.dart';

import '../../map/domain/map_models.dart';

part 'group_ride_models.freezed.dart';

/// A rider's position as broadcast to the group. Kept small on purpose:
/// it goes to every rider every few seconds (see `PositionCodec`).
@freezed
abstract class RiderFix with _$RiderFix {
  const factory RiderFix({
    required int seat,
    required double latitude,
    required double longitude,
    required int headingDegrees,
    required int speedKmh,

    /// Seconds since the trip started; lets receivers drop out-of-order fixes.
    required int tripSeconds,
  }) = _RiderFix;
}

/// A participant in a trip. The seat is a small per-trip number used on
/// the wire instead of the user id.
@freezed
abstract class TripRider with _$TripRider {
  const factory TripRider({
    required String userId,
    String? username,
    required int seat,
    required bool isLeader,
  }) = _TripRider;
}

/// The shared route. [version] increases on every re-route so riders know
/// when to reload it.
@freezed
abstract class TripRoute with _$TripRoute {
  const factory TripRoute({
    required int version,
    required List<GeoPoint> path,
    required double distanceMeters,
    required Duration duration,
  }) = _TripRoute;
}

@freezed
abstract class TripSession with _$TripSession {
  const factory TripSession({
    required String tripId,
    required String groupId,
    required String leaderId,
    required int mySeat,
    DateTime? startedAt,
    required TripRoute route,
    required List<TripRider> roster,
  }) = _TripSession;
}

/// How recently a rider was heard from, judged by when their last message
/// arrived (not the time they claim).
enum RiderStatus {
  live,
  stale,
  lost;

  static const staleAfter = Duration(seconds: 40);
  static const lostAfter = Duration(minutes: 3);

  static RiderStatus at({required DateTime lastHeardAt, required DateTime now}) {
    final silence = now.difference(lastHeardAt);
    if (silence >= lostAfter) return lost;
    if (silence >= staleAfter) return stale;
    return live;
  }
}
