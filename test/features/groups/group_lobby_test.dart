import 'package:brodie/core/errors/app_failure.dart';
import 'package:brodie/features/group_ride/domain/group_ride_models.dart';
import 'package:brodie/features/groups/application/group_lobby_controller.dart';
import 'package:brodie/features/groups/data/group_repository.dart';
import 'package:brodie/features/groups/domain/group_models.dart';
import 'package:brodie/features/map/data/directions_repository.dart';
import 'package:brodie/features/map/data/location_repository.dart';
import 'package:brodie/features/map/domain/map_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _start = GeoPoint(latitude: 14.1, longitude: 120.9);
const _tagaytay = Place(name: 'Tagaytay', location: GeoPoint(latitude: 14.11, longitude: 120.91));
const _route = RouteResult(
  path: [_start, GeoPoint(latitude: 14.11, longitude: 120.91)],
  distanceMeters: 2150,
  duration: Duration(minutes: 5),
  encodedPolyline: '_ar{Y_ycreF_pR??_pR',
);

/// One group's server state, following the rules of the stored procedures.
class _FakeGroups implements GroupRepository {
  _FakeGroups({required this.me});

  String me;
  GroupTrip? trip;
  final riders = <TripRider>[];
  ({String groupId, Place destination, RouteResult route})? planned;

  @override
  Future<void> planTrip({required String groupId, required Place destination, required RouteResult route}) async {
    if (trip != null) throw const ValidationFailure('This group already has a ride planned.');
    planned = (groupId: groupId, destination: destination, route: route);
    trip = GroupTrip(
      id: 'trip-1',
      groupId: groupId,
      leaderId: me,
      name: destination.name,
      destination: destination.location,
      status: TripStatus.planned,
      route: TripRoute(version: 1, path: route.path, distanceMeters: route.distanceMeters, duration: route.duration),
      createdAt: DateTime(2026, 11, 3),
    );
    riders.add(TripRider(userId: me, seat: 0, isLeader: true));
  }

  @override
  Future<GroupTrip?> fetchOpenTrip(String groupId) async => trip;

  @override
  Future<List<TripRider>> fetchTripRiders(String tripId) async => List.of(riders);

  @override
  Future<void> joinTrip(String tripId) async => riders.add(TripRider(userId: me, seat: riders.length, isLeader: false));

  @override
  Future<void> leaveTrip(String tripId) async => riders.removeWhere((rider) => rider.userId == me);

  @override
  Future<void> startTrip(String tripId) async => trip = trip!.copyWith(status: TripStatus.active);

  @override
  Future<void> cancelTrip(String tripId) async {
    trip = null;
    riders.clear();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FixedLocation extends LocationRepository {
  @override
  Future<GeoPoint> currentPosition() async => _start;
}

class _FakeDirections implements DirectionsRepository {
  final requests = <(GeoPoint, GeoPoint)>[];

  @override
  Future<RouteResult> fetchRoute({required GeoPoint from, required GeoPoint to}) async {
    requests.add((from, to));
    return _route;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _FakeGroups server;
  late _FakeDirections directions;

  setUp(() {
    server = _FakeGroups(me: 'leader');
    directions = _FakeDirections();
  });

  ProviderContainer app() {
    final container = ProviderContainer(overrides: [
      groupRepositoryProvider.overrideWithValue(server),
      locationRepositoryProvider.overrideWithValue(_FixedLocation()),
      directionsRepositoryProvider.overrideWithValue(directions),
    ]);
    addTearDown(container.dispose);
    container.listen(groupLobbyControllerProvider('group-1'), (_, _) {});
    return container;
  }

  test('a group with no planned ride has an empty lobby', () async {
    expect(await app().read(groupLobbyControllerProvider('group-1').future), isNull);
  });

  test('the leader plans a ride from where they are, and is its first rider', () async {
    final container = app();
    await container.read(groupLobbyControllerProvider('group-1').future);

    await container.read(groupLobbyControllerProvider('group-1').notifier).planTo(_tagaytay);

    expect(directions.requests, [(_start, _tagaytay.location)]);
    expect(server.planned?.groupId, 'group-1');
    final lobby = container.read(groupLobbyControllerProvider('group-1')).value!;
    expect(lobby.trip.name, 'Tagaytay');
    expect(lobby.trip.status, TripStatus.planned);
    expect([for (final rider in lobby.riders) rider.userId], ['leader']);
  });

  test('riders join and leave, and the leader starts the ride', () async {
    final container = app();
    final lobby = container.read(groupLobbyControllerProvider('group-1').notifier);
    await container.read(groupLobbyControllerProvider('group-1').future);
    await lobby.planTo(_tagaytay);

    server.me = 'sam';
    await lobby.join();
    expect([for (final r in container.read(groupLobbyControllerProvider('group-1')).value!.riders) r.userId], ['leader', 'sam']);
    await lobby.leave();
    expect(container.read(groupLobbyControllerProvider('group-1')).value!.riders, hasLength(1));

    server.me = 'leader';
    await lobby.start();
    expect(container.read(groupLobbyControllerProvider('group-1')).value!.trip.status, TripStatus.active);
  });

  test('cancelling empties the lobby', () async {
    final container = app();
    final lobby = container.read(groupLobbyControllerProvider('group-1').notifier);
    await container.read(groupLobbyControllerProvider('group-1').future);
    await lobby.planTo(_tagaytay);

    await lobby.cancel();

    expect(container.read(groupLobbyControllerProvider('group-1')).value, isNull);
  });

  test("planning while a ride is open fails and keeps the current one", () async {
    final container = app();
    final lobby = container.read(groupLobbyControllerProvider('group-1').notifier);
    await container.read(groupLobbyControllerProvider('group-1').future);
    await lobby.planTo(_tagaytay);

    await expectLater(lobby.planTo(_tagaytay), throwsA(isA<ValidationFailure>()));
    expect(container.read(groupLobbyControllerProvider('group-1')).value?.trip.id, 'trip-1');
  });

  test('reads a trip row from get_open_group_trip', () {
    final trip = GroupRepository.tripFromRow({
      'id': 'trip-1',
      'group_id': 'group-1',
      'leader_id': 'leader',
      'name': 'Tagaytay',
      'destination_lng': 120.91,
      'destination_lat': 14.11,
      'status': 'active',
      'route_polyline6': '_ar{Y_ycreF_pR??_pR',
      'route_version': 1,
      'distance_m': 2150,
      'duration_s': 300,
      'created_at': '2026-11-03T00:00:00+00:00',
      'started_at': '2026-11-03T00:05:00+00:00',
    });

    expect(trip.destination, _tagaytay.location);
    expect(trip.status, TripStatus.active);
    expect(trip.route.path, hasLength(3));
    expect(trip.route.duration, const Duration(minutes: 5));
    expect(trip.startedAt, isNotNull);
  });
}
