import 'package:brodie/features/history/data/ride_device_store.dart';
import 'package:brodie/features/history/data/ride_repository.dart';
import 'package:brodie/features/history/domain/ride.dart';
import 'package:brodie/features/map/domain/map_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final ride = Ride(
    id: 'ride-1',
    destinationName: 'Tagaytay Picnic Grove',
    arrived: true,
    vehicleId: 'vehicle-1',
    distanceMeters: 2150,
    duration: const Duration(minutes: 10),
    movingTime: const Duration(minutes: 9),
    maxSpeedMps: 22.5,
    startedAt: DateTime.utc(2026, 11, 2, 0),
    endedAt: DateTime.utc(2026, 11, 2, 0, 10),
    path: const [
      GeoPoint(latitude: 14.1, longitude: 120.9),
      GeoPoint(latitude: 14.11, longitude: 120.9),
      GeoPoint(latitude: 14.11, longitude: 120.91),
    ],
  );

  test('sends the route as polyline6 and times in UTC', () {
    final params = RideRepository.saveParams(ride);

    // The same string PostGIS decodes to these three points.
    expect(params['p_route_polyline6'], '_ar{Y_ycreF_pR??_pR');
    expect(params['p_started_at'], '2026-11-02T00:00:00.000Z');
    expect(params['p_duration_s'], 600);
    expect(params['p_moving_s'], 540);
  });

  test('reads a ride with its route back', () {
    final read = RideRepository.rideFromRow({
      'id': 'ride-1',
      'vehicle_id': 'vehicle-1',
      'destination_name': 'Tagaytay Picnic Grove',
      'arrived': true,
      'distance_m': 2150,
      'duration_s': 600,
      'moving_s': 540,
      'max_speed_mps': 22.5,
      'started_at': '2026-11-02T00:00:00+00:00',
      'ended_at': '2026-11-02T00:10:00+00:00',
      'route_polyline6': '_ar{Y_ycreF_pR??_pR',
    });

    expect(read.path, ride.path);
    expect(read.copyWith(path: ride.path, startedAt: ride.startedAt, endedAt: ride.endedAt), ride);
    expect(read.startedAt.isAtSameMomentAs(ride.startedAt), isTrue);
  });

  test('a group ride is saved with its trip, and history names the group', () async {
    final groupRide = ride.copyWith(groupTripId: 'trip-1');
    expect(RideRepository.saveParams(groupRide)['p_group_trip_id'], 'trip-1');
    expect(RideRepository.saveParams(ride)['p_group_trip_id'], isNull);

    final read = RideRepository.rideFromRow({
      'id': 'ride-1',
      'distance_m': 2150,
      'duration_s': 600,
      'started_at': '2026-11-02T00:00:00+00:00',
      'ended_at': '2026-11-02T00:10:00+00:00',
      'group_trip_id': 'trip-1',
      'group_name': 'Sunday crew',
    });
    expect(read.groupTripId, 'trip-1');
    expect(read.groupName, 'Sunday crew');

    // A group ride waiting offline keeps its trip until it uploads.
    SharedPreferences.setMockInitialValues({});
    final store = RideDeviceStore(await SharedPreferences.getInstance());
    await store.savePending('user-1', [groupRide]);
    expect(store.readPending('user-1').single.groupTripId, 'trip-1');
  });

  test('fills gaps in older rows', () {
    final read = RideRepository.rideFromRow({
      'id': 'old',
      'distance_m': 1000,
      'duration_s': 300,
      'started_at': '2026-08-05T00:00:00+00:00',
      'ended_at': null,
    });

    expect(read.arrived, isFalse);
    expect(read.movingTime, const Duration(seconds: 300));
    expect(read.endedAt.difference(read.startedAt), const Duration(seconds: 300));
    expect(read.path, isEmpty);
  });
}
