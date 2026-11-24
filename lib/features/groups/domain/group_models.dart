import 'package:freezed_annotation/freezed_annotation.dart';

import '../../group_ride/domain/group_ride_models.dart';
import '../../map/domain/map_models.dart';

part 'group_models.freezed.dart';

@freezed
abstract class RideGroup with _$RideGroup {
  const factory RideGroup({
    required String id,
    required String name,
    required String inviteCode,
    required String leaderId,
    required DateTime createdAt,
    @Default(1) int memberCount,

    /// The status of the group's planned or active trip; null when none.
    TripStatus? openTripStatus,
  }) = _RideGroup;
}

enum GroupRole { leader, member }

enum MemberStatus { pending, joined, left, fellBehind }

@freezed
abstract class GroupMember with _$GroupMember {
  const factory GroupMember({
    required String userId,
    String? username,
    String? avatarPath,
    required GroupRole role,
    required MemberStatus status,
    required DateTime joinedAt,
  }) = _GroupMember;
}

@freezed
abstract class GroupInvite with _$GroupInvite {
  const factory GroupInvite({
    required String groupId,
    required String groupName,
    String? invitedBy,
    required DateTime invitedAt,
  }) = _GroupInvite;
}

enum TripStatus { planned, active, completed, cancelled }

/// A ride the group goes on together: the leader plans it with a route,
/// riders join it, and the leader starts it.
@freezed
abstract class GroupTrip with _$GroupTrip {
  const factory GroupTrip({
    required String id,
    required String groupId,
    required String leaderId,

    /// The destination's name.
    String? name,
    required GeoPoint destination,
    required TripStatus status,
    required TripRoute route,
    required DateTime createdAt,
    DateTime? startedAt,
  }) = _GroupTrip;
}

/// What the join screen shows for an invite code before the rider joins.
@freezed
abstract class GroupInvitePreview with _$GroupInvitePreview {
  const factory GroupInvitePreview({
    required String groupId,
    required String name,
    String? leaderUsername,
    required int memberCount,

    /// The rider's membership in the group, if any.
    MemberStatus? myStatus,
  }) = _GroupInvitePreview;
}

/// A finished ride in a group's history.
@freezed
abstract class PastGroupRide with _$PastGroupRide {
  const factory PastGroupRide({
    required String tripId,

    /// The destination's name.
    String? name,
    required DateTime startedAt,
    DateTime? endedAt,
    required double plannedDistanceMeters,
    required int riderCount,

    /// This rider's saved ride on the trip, if they rode it.
    String? myRideId,
  }) = _PastGroupRide;
}

/// One finished group ride: the trip and its planned route.
@freezed
abstract class GroupRideSummary with _$GroupRideSummary {
  const factory GroupRideSummary({
    required String tripId,
    required String groupId,
    required String groupName,
    String? name,
    String? leaderUsername,
    required DateTime startedAt,
    DateTime? endedAt,
    required double plannedDistanceMeters,
    @Default(<GeoPoint>[]) List<GeoPoint> route,
  }) = _GroupRideSummary;
}

/// Someone who rode a group ride, with the totals from their saved ride.
/// The stats are null when their ride wasn't saved.
@freezed
abstract class GroupRideRider with _$GroupRideRider {
  const factory GroupRideRider({
    required String userId,
    String? username,
    required bool isLeader,
    required bool leftEarly,
    double? distanceMeters,
    Duration? movingTime,
    double? maxSpeedMps,
    bool? arrived,
  }) = _GroupRideRider;

  const GroupRideRider._();

  bool get hasStats => distanceMeters != null;
}
