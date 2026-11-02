import 'package:brodie/core/di/core_providers.dart';
import 'package:brodie/core/errors/app_failure.dart';
import 'package:brodie/features/auth/application/session_providers.dart';
import 'package:brodie/features/auth/domain/app_user.dart';
import 'package:brodie/features/history/application/ride_providers.dart';
import 'package:brodie/features/history/data/ride_repository.dart';
import 'package:brodie/features/history/domain/ride.dart';
import 'package:brodie/features/map/domain/map_models.dart';
import 'package:brodie/features/vehicles/data/vehicle_repository.dart';
import 'package:brodie/features/vehicles/domain/vehicle.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The server: rides by id. [failWith] makes the next calls throw it.
class _FakeRides implements RideRepository {
  final saved = <String, Ride>{};
  Object? failWith;

  void _maybeFail() {
    if (failWith case final error?) throw error;
  }

  @override
  Future<void> save(Ride ride) async {
    _maybeFail();
    saved.putIfAbsent(ride.id, () => ride);
  }

  @override
  Future<void> delete(String rideId) async {
    _maybeFail();
    saved.remove(rideId);
  }

  @override
  Future<void> setVehicle(String rideId, String? vehicleId) async {
    _maybeFail();
    final ride = saved[rideId];
    if (ride != null) saved[rideId] = ride.copyWith(vehicleId: vehicleId);
  }

  @override
  Future<List<Ride>> fetchHistory({required int limit, required int offset}) async =>
      saved.values.skip(offset).take(limit).toList();

  @override
  Future<Ride> fetchRide(String id) async => saved[id] ?? (throw const NotFoundFailure());
}

class _FakeVehicles implements VehicleRepository {
  _FakeVehicles(this.vehicles);

  final List<Vehicle> vehicles;

  @override
  Future<List<Vehicle>> fetchMine() async => vehicles;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Ride ride(String id) => Ride(
      id: id,
      arrived: true,
      distanceMeters: 5000,
      duration: const Duration(minutes: 12),
      movingTime: const Duration(minutes: 10),
      maxSpeedMps: 20,
      startedAt: DateTime(2026, 11, 2, 8),
      endedAt: DateTime(2026, 11, 2, 8, 12),
      path: const [GeoPoint(latitude: 14.1, longitude: 120.9), GeoPoint(latitude: 14.14, longitude: 120.9)],
    );

void main() {
  late SharedPreferences prefs;
  late _FakeRides server;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    server = _FakeRides();
  });

  /// A fresh app session for [userId] over the same phone storage and server.
  ProviderContainer session({String userId = 'rider', List<Vehicle> vehicles = const []}) {
    final container = ProviderContainer(overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      currentUserProvider.overrideWithValue(AppUser(id: userId)),
      rideRepositoryProvider.overrideWithValue(server),
      vehicleRepositoryProvider.overrideWithValue(_FakeVehicles(vehicles)),
    ]);
    addTearDown(container.dispose);
    container.listen(rideSyncProvider, (_, _) {});
    return container;
  }

  test('uploads a finished ride and clears it from the phone', () async {
    final app = session();

    expect(await app.read(rideSyncProvider.notifier).save(ride('a')), isTrue);
    expect(server.saved.keys, ['a']);
    expect(app.read(rideSyncProvider), isEmpty);
  });

  test('keeps a ride on the phone while offline and uploads it on a later launch', () async {
    server.failWith = const NetworkFailure();
    final offline = session();
    expect(await offline.read(rideSyncProvider.notifier).save(ride('a')), isFalse);
    expect([for (final r in offline.read(rideSyncProvider)) r.id], ['a']);

    server.failWith = null;
    final later = session();
    expect([for (final r in later.read(rideSyncProvider)) r.id], ['a'], reason: 'survives an app restart');
    await later.read(rideSyncProvider.notifier).uploadPending();

    expect(server.saved.keys, ['a']);
    expect(later.read(rideSyncProvider), isEmpty);
  });

  test('drops a ride the server rejects, since retrying cannot help', () async {
    server.failWith = const ValidationFailure('A ride route needs at least 2 points.');
    final app = session();

    await expectLater(app.read(rideSyncProvider.notifier).save(ride('a')), throwsA(isA<ValidationFailure>()));
    expect(app.read(rideSyncProvider), isEmpty);
  });

  test('gives a ride the only vehicle in the garage', () async {
    final app = session(vehicles: [const Vehicle(id: 'adv', type: VehicleType.motorcycle, name: 'ADV 160')]);
    await app.read(rideSyncProvider.notifier).save(ride('a'));

    expect(server.saved['a']?.vehicleId, 'adv');
  });

  test('a vehicle picked for one ride becomes the default for the next', () async {
    final garage = [
      const Vehicle(id: 'adv', type: VehicleType.motorcycle, name: 'ADV 160'),
      const Vehicle(id: 'mtb', type: VehicleType.bike, name: 'Trek'),
    ];
    final app = session(vehicles: garage);
    final sync = app.read(rideSyncProvider.notifier);

    await sync.save(ride('a'));
    expect(server.saved['a']?.vehicleId, isNull, reason: 'two vehicles and no history: no guess');

    await sync.setVehicle('a', 'mtb');
    await sync.save(ride('b'));

    expect(server.saved['a']?.vehicleId, 'mtb');
    expect(server.saved['b']?.vehicleId, 'mtb');
  });

  test('deleting a ride still on the phone removes it there', () async {
    server.failWith = const NetworkFailure();
    final app = session();
    final sync = app.read(rideSyncProvider.notifier);
    await sync.save(ride('a'));

    await sync.delete('a');

    expect(app.read(rideSyncProvider), isEmpty);
    expect(session().read(rideSyncProvider), isEmpty, reason: 'gone after a restart too');
  });

  test("another rider on the same phone doesn't see or upload your queued rides", () async {
    server.failWith = const NetworkFailure();
    await session(userId: 'alex').read(rideSyncProvider.notifier).save(ride('a'));
    server.failWith = null;

    final sam = session(userId: 'sam');
    await sam.read(rideSyncProvider.notifier).uploadPending();

    expect(sam.read(rideSyncProvider), isEmpty);
    expect(server.saved, isEmpty);
    expect(session(userId: 'alex').read(rideSyncProvider), hasLength(1));
  });
}
