import 'package:brodie/features/groups/data/group_repository.dart';
import 'package:brodie/features/groups/domain/group_models.dart';
import 'package:flutter_test/flutter_test.dart';

/// Reading the rows the group stored procedures return.
void main() {
  test('reads past group ride rows', () {
    final past = GroupRepository.pastRideFromRow({
      'trip_id': 'trip-1',
      'name': 'Tagaytay',
      'started_at': '2026-11-23T00:00:00+00:00',
      'ended_at': '2026-11-23T01:30:00+00:00',
      'planned_distance_m': 52000,
      'rider_count': 4,
      'my_ride_id': null,
    });
    expect(past.riderCount, 4);
    expect(past.plannedDistanceMeters, 52000);
    expect(past.myRideId, isNull);
    expect(past.endedAt!.difference(past.startedAt), const Duration(minutes: 90));

    final ride = GroupRepository.groupRideFromRow({
      'trip_id': 'trip-1',
      'group_id': 'group-1',
      'group_name': 'Sunday crew',
      'name': 'Tagaytay',
      'leader_username': 'lea',
      'started_at': '2026-11-23T00:00:00+00:00',
      'ended_at': null,
      'planned_distance_m': 52000,
      'route_polyline6': '_ar{Y_ycreF_pR??_pR',
    });
    expect(ride.groupName, 'Sunday crew');
    expect(ride.route, hasLength(3));

    final saved = GroupRepository.rideRiderFromRow({
      'user_id': 'u1',
      'username': 'lea',
      'is_leader': true,
      'left_early': false,
      'distance_m': 51800,
      'moving_s': 4800,
      'max_speed_mps': 27.5,
      'arrived': true,
    });
    expect(saved.hasStats, isTrue);
    expect(saved.movingTime, const Duration(minutes: 80));

    final unsaved = GroupRepository.rideRiderFromRow({
      'user_id': 'u2',
      'username': 'sam',
      'is_leader': false,
      'left_early': true,
      'distance_m': null,
      'moving_s': null,
      'max_speed_mps': null,
      'arrived': null,
    });
    expect(unsaved.hasStats, isFalse);
    expect(unsaved.leftEarly, isTrue);
  });

  test('reads a row from get_group_invite_preview', () {
    final preview = GroupRepository.previewFromRow({
      'group_id': 'group-1',
      'name': 'Sunday crew',
      'leader_username': 'lea',
      'member_count': 3,
      'my_status': 'pending',
    });
    expect(preview.name, 'Sunday crew');
    expect(preview.leaderUsername, 'lea');
    expect(preview.memberCount, 3);
    expect(preview.myStatus, MemberStatus.pending);

    final stranger = GroupRepository.previewFromRow({
      'group_id': 'group-1',
      'name': 'Sunday crew',
      'leader_username': 'lea',
      'member_count': 3,
      'my_status': null,
    });
    expect(stranger.myStatus, isNull);
  });
}
