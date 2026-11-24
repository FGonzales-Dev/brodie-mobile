import 'package:brodie/core/di/core_providers.dart';
import 'package:brodie/core/errors/app_failure.dart';
import 'package:brodie/features/auth/application/session_providers.dart';
import 'package:brodie/features/auth/domain/app_user.dart';
import 'package:brodie/features/history/application/ride_providers.dart';
import 'package:brodie/features/history/data/ride_repository.dart';
import 'package:brodie/features/history/domain/ride.dart';
import 'package:brodie/features/history/domain/ride_filter.dart';
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

  /// Each history request's filter and clock, in order.
  final historyRequests = <({RideFilter filter, DateTime? now, int offset})>[];

  /// Filters and sorts like `get_ride_history`.
  List<Ride> _matching(RideFilter filter, DateTime? now) =>
      saved.values.where((ride) => filter.matches(ride, now ?? DateTime.now())).toList()..sort(filter.compare);

  @override
  Future<List<Ride>> fetchHistory({
    required int limit,
    required int offset,
    RideFilter filter = const RideFilter(),
    DateTime? now,
  }) async {
    _maybeFail();
    historyRequests.add((filter: filter, now: now, offset: offset));
    return _matching(filter, now).skip(offset).take(limit).toList();
  }

  @override
  Future<RideTotals> fetchTotals({RideFilter filter = const RideFilter(), DateTime? now}) async {
    _maybeFail();
    final rides = _matching(filter, now);
    return (
      count: rides.length,
      distanceMeters: rides.fold(0.0, (sum, ride) => sum + ride.distanceMeters),
      movingTime: rides.fold(Duration.zero, (sum, ride) => sum + ride.movingTime),
    );
  }

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

  group('history filters', () {
    Ride at(String id, DateTime startedAt, {double km = 5, String? trip, String? vehicle}) => ride(id).copyWith(
          startedAt: startedAt,
          endedAt: startedAt.add(const Duration(minutes: 12)),
          distanceMeters: km * 1000,
          groupTripId: trip,
          vehicleId: vehicle,
        );

    test('the list reloads with the filter, and every page uses the same one', () async {
      final now = DateTime.now();
      for (var i = 0; i < 25; i++) {
        server.saved['g$i'] = at('g$i', now.subtract(Duration(hours: i)), trip: 'trip-1');
      }
      server.saved['solo'] = at('solo', now);
      final container = session();
      container.listen(rideHistoryControllerProvider, (_, _) {});
      await container.read(rideHistoryControllerProvider.future);

      container.read(rideFilterControllerProvider.notifier).update((f) => f.copyWith(kind: RideKind.group));
      final firstPage = await container.read(rideHistoryControllerProvider.future);
      expect(firstPage.rides, hasLength(20));
      expect(firstPage.rides.every((ride) => ride.groupTripId != null), isTrue);

      await container.read(rideHistoryControllerProvider.notifier).loadMore();
      expect(container.read(rideHistoryControllerProvider).value!.rides, hasLength(25));
      final requests = server.historyRequests;
      final (page1, page2) = (requests[requests.length - 2], requests.last);
      expect(page2.offset, 20);
      expect(page2.filter, page1.filter);
      expect(page2.now, page1.now, reason: 'what "this month" means mustn\'t shift between pages');
    });

    test('totals follow the filter', () async {
      final now = DateTime.now();
      server.saved['a'] = at('a', now, km: 10, vehicle: 'adv');
      server.saved['b'] = at('b', now, km: 30);
      final container = session();

      expect((await container.read(rideHistoryTotalsProvider.future)).count, 2);
      container.read(rideFilterControllerProvider.notifier).update((f) => f.copyWith(vehicleId: 'adv'));
      final totals = await container.read(rideHistoryTotalsProvider.future);
      expect(totals.count, 1);
      expect(totals.distanceMeters, 10000);
    });

    test('clearing goes back to everything, newest first', () {
      final container = session();
      final filter = container.read(rideFilterControllerProvider.notifier)
        ..update((f) => f.copyWith(kind: RideKind.solo, sort: RideSort.distance));
      expect(container.read(rideFilterControllerProvider).isDefault, isFalse);
      filter.clear();
      expect(container.read(rideFilterControllerProvider).isDefault, isTrue);
    });
  });
}
