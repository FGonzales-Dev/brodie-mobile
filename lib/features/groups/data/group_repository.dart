import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/di/core_providers.dart';
import '../../../core/errors/guard_remote.dart';
import '../domain/group_models.dart';

part 'group_repository.g.dart';

/// Group rides. Every call is a stored procedure (see brodie-supabase), which
/// handles membership checks and multi-table writes atomically.
class GroupRepository {
  GroupRepository(this._client);

  final SupabaseClient _client;

  Future<List<RideGroup>> fetchMyGroups() => _rpcList('get_my_groups', _groupFromRow);

  Future<RideGroup> createGroup(String name) async {
    final rows = await _rpcList('create_ride_group', _groupFromRow, {'group_name': name});
    return rows.first;
  }

  Future<void> inviteMember({required String groupId, required String userId}) {
    return _rpc('add_group_member', {'target_group_id': groupId, 'target_user_id': userId});
  }

  Future<List<GroupMember>> fetchActiveMembers(String groupId) {
    return _rpcList('get_active_group_members', _memberFromRow, {'target_group_id': groupId});
  }

  Future<List<GroupInvite>> fetchPendingInvites() => _rpcList('get_pending_invites', _inviteFromRow);

  Future<void> acceptInvite(String groupId) => _rpc('accept_group_invite', {'target_group_id': groupId});

  Future<void> declineInvite(String groupId) => _rpc('decline_group_invite', {'target_group_id': groupId});

  Future<GroupTrip> createTrip({
    required String groupId,
    required double destinationLatitude,
    required double destinationLongitude,
    String? name,
  }) async {
    final rows = await _rpcList('create_group_trip', _tripFromRow, {
      'target_group_id': groupId,
      'destination_lng': destinationLongitude,
      'destination_lat': destinationLatitude,
      'trip_name': name,
    });
    return rows.first;
  }

  Future<List<GroupTrip>> fetchTrips(String groupId) {
    return _rpcList('get_group_trips', _tripFromRow, {'target_group_id': groupId});
  }

  Future<void> _rpc(String function, Map<String, dynamic> params) {
    return guardRemote(() => _client.rpc(function, params: params));
  }

  Future<List<T>> _rpcList<T>(
    String function,
    T Function(Map<String, dynamic> row) fromRow, [
    Map<String, dynamic>? params,
  ]) {
    return guardRemote(() async {
      final rows = await _client.rpc(function, params: params);
      return (rows as List).cast<Map<String, dynamic>>().map(fromRow).toList();
    });
  }

  static RideGroup _groupFromRow(Map<String, dynamic> row) => RideGroup(
        id: row['id'] as String,
        name: row['name'] as String,
        inviteCode: row['invite_code'] as String,
        leaderId: row['leader_id'] as String,
        createdAt: DateTime.parse(row['created_at'] as String),
        memberCount: (row['member_count'] as num?)?.toInt() ?? 1,
      );

  static GroupMember _memberFromRow(Map<String, dynamic> row) => GroupMember(
        userId: row['user_id'] as String,
        username: row['username'] as String?,
        avatarUrl: row['avatar_url'] as String?,
        role: GroupRole.values.byName(row['role'] as String),
        status: switch (row['status'] as String) {
          'pending' => MemberStatus.pending,
          'left' => MemberStatus.left,
          'fell_behind' => MemberStatus.fellBehind,
          _ => MemberStatus.joined,
        },
        joinedAt: DateTime.parse(row['joined_at'] as String),
      );

  static GroupInvite _inviteFromRow(Map<String, dynamic> row) => GroupInvite(
        groupId: row['group_id'] as String,
        groupName: row['group_name'] as String,
        invitedBy: row['invited_by'] as String?,
        invitedAt: DateTime.parse(row['invited_at'] as String),
      );

  static GroupTrip _tripFromRow(Map<String, dynamic> row) => GroupTrip(
        id: row['id'] as String,
        groupId: row['group_id'] as String?,
        name: row['name'] as String?,
        status: TripStatus.values.byName(row['status'] as String),
        createdAt: DateTime.parse(row['created_at'] as String),
        startedAt: _parseOptionalDate(row['started_at']),
        endedAt: _parseOptionalDate(row['ended_at']),
      );

  static DateTime? _parseOptionalDate(Object? value) => value == null ? null : DateTime.parse(value as String);
}

@Riverpod(keepAlive: true)
GroupRepository groupRepository(Ref ref) => GroupRepository(ref.watch(supabaseClientProvider));
