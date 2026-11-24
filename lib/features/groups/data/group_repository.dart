import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/di/core_providers.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/errors/guard_remote.dart';
import '../../group_ride/domain/group_ride_models.dart';
import '../../map/data/maneuver_json.dart';
import '../../map/domain/map_models.dart';
import '../../map/domain/polyline_codec.dart';
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

  /// The group behind an invite code, or null when it matches none. Wrong
  /// codes count toward a daily limit on the server.
  Future<GroupInvitePreview?> fetchInvitePreview(String code) async {
    final previews = await _rpcList('get_group_invite_preview', _previewFromRow, {'invite_code': code});
    return previews.firstOrNull;
  }

  /// Joins the group behind [code] and returns its id, or null when the code
  /// matches no group (e.g. the leader reset it).
  Future<String?> joinByInviteCode(String code) {
    return guardRemote(() async {
      final groupId = await _client.rpc('join_group_by_invite_code', params: {'invite_code': code});
      return groupId as String?;
    });
  }

  /// Leader only. Returns the new code; links already shared stop working.
  Future<String> resetInviteCode(String groupId) {
    return guardRemote(() async {
      final code = await _client.rpc('reset_group_invite_code', params: {'target_group_id': groupId});
      return code as String;
    });
  }

  /// Leader only. Fails while the group already has a trip open.
  Future<void> planTrip({required String groupId, required Place destination, required RouteResult route}) {
    return _rpc('plan_group_trip', {
      'target_group_id': groupId,
      'destination_lng': destination.location.longitude,
      'destination_lat': destination.location.latitude,
      'route_polyline6': route.encodedPolyline,
      'route_distance_m': route.distanceMeters,
      'route_duration_s': route.duration.inSeconds,
      'trip_name': destination.name,
      'route_maneuvers': ManeuverJson.encodeAll(route.maneuvers),
    });
  }

  /// Leader only, during the ride: replaces the group's route with [route]
  /// and returns its new version, which riders pick up.
  Future<int> rerouteTrip(String tripId, RouteResult route) => guardRemote(() async {
    final version = await _client.rpc(
      'reroute_group_trip',
      params: {
        'target_trip_id': tripId,
        'route_polyline6': route.encodedPolyline,
        'route_distance_m': route.distanceMeters,
        'route_duration_s': route.duration.inSeconds,
        'route_maneuvers': ManeuverJson.encodeAll(route.maneuvers),
      },
    );
    return (version as num).toInt();
  });

  /// The group's planned or active trip, or null.
  Future<GroupTrip?> fetchOpenTrip(String groupId) async {
    final trips = await _rpcList('get_open_group_trip', tripFromRow, {'target_group_id': groupId});
    return trips.firstOrNull;
  }

  /// Riders who have joined [tripId], by seat.
  Future<List<TripRider>> fetchTripRiders(String tripId) {
    return _rpcList('get_trip_riders', _riderFromRow, {'target_trip_id': tripId});
  }

  /// Joining again after leaving keeps the same seat.
  Future<void> joinTrip(String tripId) => _rpc('join_group_trip', {'target_trip_id': tripId});

  Future<void> leaveTrip(String tripId) => _rpc('leave_group_trip', {'target_trip_id': tripId});

  /// Leader only.
  Future<void> startTrip(String tripId) => _rpc('start_group_trip', {'target_trip_id': tripId});

  /// Leader only.
  Future<void> cancelTrip(String tripId) => _rpc('cancel_group_trip', {'target_trip_id': tripId});

  /// Leader only: ends a started ride for everyone.
  Future<void> completeTrip(String tripId) => _rpc('complete_group_trip', {'target_trip_id': tripId});

  /// The group's finished rides, newest first.
  Future<List<PastGroupRide>> fetchRideHistory(String groupId, {int limit = 20, int offset = 0}) {
    return _rpcList('get_group_ride_history', pastRideFromRow, {
      'target_group_id': groupId,
      'p_limit': limit,
      'p_offset': offset,
    });
  }

  Future<GroupRideSummary> fetchGroupRide(String tripId) async {
    final rides = await _rpcList('get_group_ride', groupRideFromRow, {'target_trip_id': tripId});
    if (rides.isEmpty) throw const NotFoundFailure("This group ride isn't available. You may have left the group.");
    return rides.first;
  }

  /// Leader first, then by distance ridden.
  Future<List<GroupRideRider>> fetchGroupRideRiders(String tripId) {
    return _rpcList('get_group_ride_riders', rideRiderFromRow, {'target_trip_id': tripId});
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
    openTripStatus: switch (row['open_trip_status']) {
      final String status => TripStatus.values.byName(status),
      _ => null,
    },
  );

  @visibleForTesting
  static GroupInvitePreview previewFromRow(Map<String, dynamic> row) => _previewFromRow(row);

  static GroupInvitePreview _previewFromRow(Map<String, dynamic> row) => GroupInvitePreview(
    groupId: row['group_id'] as String,
    name: row['name'] as String,
    leaderUsername: row['leader_username'] as String?,
    memberCount: (row['member_count'] as num).toInt(),
    myStatus: switch (row['my_status']) {
      final String status => _memberStatusFrom(status),
      _ => null,
    },
  );

  static MemberStatus _memberStatusFrom(String status) => switch (status) {
    'pending' => MemberStatus.pending,
    'left' => MemberStatus.left,
    'fell_behind' => MemberStatus.fellBehind,
    _ => MemberStatus.joined,
  };

  static GroupMember _memberFromRow(Map<String, dynamic> row) => GroupMember(
    userId: row['user_id'] as String,
    username: row['username'] as String?,
    avatarPath: row['avatar_path'] as String?,
    role: GroupRole.values.byName(row['role'] as String),
    status: _memberStatusFrom(row['status'] as String),
    joinedAt: DateTime.parse(row['joined_at'] as String),
  );

  static GroupInvite _inviteFromRow(Map<String, dynamic> row) => GroupInvite(
    groupId: row['group_id'] as String,
    groupName: row['group_name'] as String,
    invitedBy: row['invited_by'] as String?,
    invitedAt: DateTime.parse(row['invited_at'] as String),
  );

  @visibleForTesting
  static GroupTrip tripFromRow(Map<String, dynamic> row) => GroupTrip(
    id: row['id'] as String,
    groupId: row['group_id'] as String,
    leaderId: row['leader_id'] as String,
    name: row['name'] as String?,
    destination: GeoPoint(
      latitude: (row['destination_lat'] as num).toDouble(),
      longitude: (row['destination_lng'] as num).toDouble(),
    ),
    status: TripStatus.values.byName(row['status'] as String),
    route: TripRoute(
      version: (row['route_version'] as num).toInt(),
      path: PolylineCodec.decode(row['route_polyline6'] as String),
      distanceMeters: (row['distance_m'] as num).toDouble(),
      duration: Duration(seconds: (row['duration_s'] as num).toInt()),
      maneuvers: ManeuverJson.decodeAll(row['maneuvers']),
    ),
    createdAt: DateTime.parse(row['created_at'] as String),
    startedAt: _parseOptionalDate(row['started_at']),
  );

  static TripRider _riderFromRow(Map<String, dynamic> row) => TripRider(
    userId: row['user_id'] as String,
    username: row['username'] as String?,
    avatarPath: row['avatar_path'] as String?,
    seat: (row['seat'] as num).toInt(),
    isLeader: row['is_leader'] as bool,
  );

  @visibleForTesting
  static PastGroupRide pastRideFromRow(Map<String, dynamic> row) => PastGroupRide(
    tripId: row['trip_id'] as String,
    name: row['name'] as String?,
    startedAt: DateTime.parse(row['started_at'] as String).toLocal(),
    endedAt: _parseOptionalDate(row['ended_at'])?.toLocal(),
    plannedDistanceMeters: (row['planned_distance_m'] as num?)?.toDouble() ?? 0,
    riderCount: (row['rider_count'] as num).toInt(),
    myRideId: row['my_ride_id'] as String?,
  );

  @visibleForTesting
  static GroupRideSummary groupRideFromRow(Map<String, dynamic> row) {
    final polyline = row['route_polyline6'] as String?;
    return GroupRideSummary(
      tripId: row['trip_id'] as String,
      groupId: row['group_id'] as String,
      groupName: row['group_name'] as String,
      name: row['name'] as String?,
      leaderUsername: row['leader_username'] as String?,
      startedAt: DateTime.parse(row['started_at'] as String).toLocal(),
      endedAt: _parseOptionalDate(row['ended_at'])?.toLocal(),
      plannedDistanceMeters: (row['planned_distance_m'] as num?)?.toDouble() ?? 0,
      route: polyline == null ? const [] : PolylineCodec.decode(polyline),
    );
  }

  @visibleForTesting
  static GroupRideRider rideRiderFromRow(Map<String, dynamic> row) => GroupRideRider(
    userId: row['user_id'] as String,
    username: row['username'] as String?,
    isLeader: row['is_leader'] as bool,
    leftEarly: row['left_early'] as bool,
    distanceMeters: (row['distance_m'] as num?)?.toDouble(),
    movingTime: switch (row['moving_s']) {
      final num seconds => Duration(seconds: seconds.toInt()),
      _ => null,
    },
    maxSpeedMps: (row['max_speed_mps'] as num?)?.toDouble(),
    arrived: row['arrived'] as bool?,
  );

  static DateTime? _parseOptionalDate(Object? value) => value == null ? null : DateTime.parse(value as String);
}

@Riverpod(keepAlive: true)
GroupRepository groupRepository(Ref ref) => GroupRepository(ref.watch(supabaseClientProvider));
