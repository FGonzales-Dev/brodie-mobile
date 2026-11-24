import 'package:brodie/features/groups/data/group_repository.dart';
import 'package:brodie/features/map/data/maneuver_json.dart';
import 'package:brodie/features/map/domain/map_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const maneuvers = [
    RouteManeuver(instruction: 'Head north', type: 'depart', location: GeoPoint(latitude: 14.1, longitude: 120.9)),
    RouteManeuver(
      instruction: 'Turn right onto Summit Road',
      type: 'turn',
      modifier: 'right',
      location: GeoPoint(latitude: 14.15, longitude: 120.9),
    ),
  ];

  test('directions survive being saved with a trip and read back', () {
    expect(ManeuverJson.decodeAll(ManeuverJson.encodeAll(maneuvers)), maneuvers);
  });

  test('a trip row carries its directions; older trips have none', () {
    Map<String, dynamic> row({Object? maneuvers}) => {
      'id': 'trip-1',
      'group_id': 'group-1',
      'leader_id': 'lea',
      'name': 'Tagaytay',
      'destination_lng': 120.91,
      'destination_lat': 14.11,
      'status': 'active',
      'route_polyline6': '_ar{Y_ycreF_pR??_pR',
      'route_version': 2,
      'distance_m': 2150,
      'duration_s': 300,
      'created_at': '2026-11-03T00:00:00+00:00',
      'started_at': null,
      'maneuvers': maneuvers,
    };
    expect(GroupRepository.tripFromRow(row(maneuvers: ManeuverJson.encodeAll(maneuvers))).route.maneuvers, maneuvers);
    expect(GroupRepository.tripFromRow(row()).route.maneuvers, isEmpty);
    expect(GroupRepository.tripFromRow(row()).route.version, 2);
  });
}
