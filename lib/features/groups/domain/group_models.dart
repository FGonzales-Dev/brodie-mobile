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
    String? avatarUrl,
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
