import 'package:freezed_annotation/freezed_annotation.dart';

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

@freezed
abstract class GroupTrip with _$GroupTrip {
  const factory GroupTrip({
    required String id,
    String? groupId,
    String? name,
    required TripStatus status,
    required DateTime createdAt,
    DateTime? startedAt,
    DateTime? endedAt,
  }) = _GroupTrip;
}
