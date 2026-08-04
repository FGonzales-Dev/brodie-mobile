import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/models/group_invite.dart';
import '../../domain/models/group_member.dart';
import '../../domain/models/group_trip.dart';
import '../../domain/models/ride_group.dart';

part 'group_ride_repository.g.dart';

class GroupRideRepository {
  GroupRideRepository(this._client);

  final SupabaseClient _client;

  Future<RideGroup> createGroup({required String name}) async {
    final response = await _client.rpc('create_ride_group', params: {'group_name': name});
    final row = (response as List).first as Map<String, dynamic>;
    return RideGroup.fromJson(row);
  }

  Future<void> addMember({required String groupId, required String userId}) {
    return _client.rpc('add_group_member', params: {
      'target_group_id': groupId,
      'target_user_id': userId,
    });
  }

  Future<List<GroupMember>> getActiveMembers(String groupId) async {
    final response = await _client.rpc('get_active_group_members', params: {'target_group_id': groupId});
    return (response as List).map((row) => GroupMember.fromJson(row as Map<String, dynamic>)).toList();
  }

  Future<GroupTrip> createTrip({
    required String groupId,
    required double destinationLongitude,
    required double destinationLatitude,
    String? name,
  }) async {
    final response = await _client.rpc('create_group_trip', params: {
      'target_group_id': groupId,
      'destination_lng': destinationLongitude,
      'destination_lat': destinationLatitude,
      'trip_name': name,
    });
    final row = (response as List).first as Map<String, dynamic>;
    return GroupTrip.fromJson(row);
  }

  Future<List<GroupTrip>> getTrips(String groupId) async {
    final response = await _client.rpc('get_group_trips', params: {'target_group_id': groupId});
    return (response as List).map((row) => GroupTrip.fromJson(row as Map<String, dynamic>)).toList();
  }

  Future<void> acceptInvite(String groupId) {
    return _client.rpc('accept_group_invite', params: {'target_group_id': groupId});
  }

  Future<void> declineInvite(String groupId) {
    return _client.rpc('decline_group_invite', params: {'target_group_id': groupId});
  }

  Future<List<GroupInvite>> getPendingInvites() async {
    final response = await _client.rpc('get_pending_invites');
    return (response as List).map((row) => GroupInvite.fromJson(row as Map<String, dynamic>)).toList();
  }
}

@riverpod
GroupRideRepository groupRideRepository(Ref ref) {
  return GroupRideRepository(Supabase.instance.client);
}
