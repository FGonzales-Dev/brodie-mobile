import 'dart:async';

import 'package:brodie/core/di/core_providers.dart';
import 'package:brodie/core/errors/app_failure.dart';
import 'package:brodie/features/map/application/my_location_providers.dart';
import 'package:brodie/features/map/data/directions_repository.dart';
import 'package:brodie/features/map/data/location_repository.dart';
import 'package:brodie/features/map/domain/location_health.dart';
import 'package:brodie/features/map/domain/map_models.dart';
import 'package:brodie/features/map/domain/route_rejoin.dart';
import 'package:brodie/features/map/presentation/ride_planning_controller.dart';
import 'package:brodie/features/map/presentation/solo_ride/solo_ride_controller.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/geo.dart';

const _start = GeoPoint(latitude: 14.1, longitude: 120.9);
final _end = north(_start, 2000);
final _t0 = DateTime(2026, 11, 26, 8);

RouteResult _routeFrom(GeoPoint from) =>
    RouteResult(path: [from, _end], distanceMeters: 2000, duration: const Duration(minutes: 4), encodedPolyline: '');

/// The rider previewed a 2 km route north.
class _Planned extends RidePlanningController {
  @override
  RidePlanState build() => RidePlanPreview(Place(name: 'Summit', location: _end), _routeFrom(_start));
}

class _NothingPlanned extends RidePlanningController {
  @override
  RidePlanState build() => const RidePlanIdle();
}

/// The map's own last position, which the ride starts from.
class _MapPosition extends MyLocationController {
  _MapPosition(this.fix);

  final GeoFix? fix;

  @override
  Future<GeoFix> build() async => fix ?? (throw const LocationFailure());
}

class _FakeLocation extends LocationRepository {
  final fixes = StreamController<GeoFix>.broadcast();
  var watches = 0;
  LocationAccess access = LocationAccess.whileInUse;

  @override
  Stream<GeoFix> watchPosition({int distanceFilterMeters = 10, bool keepRunningInBackground = false}) {
    watches++;
    return fixes.stream;
  }

  @override
  Future<LocationAccess> checkAccess() async => access;
}

class _FakeDirections implements DirectionsRepository {
  final requests = <(GeoPoint, GeoPoint)>[];
  final purposes = <RoutePurpose>[];
  Object? failWith;

  @override
  Future<RouteResult> fetchRoute({required GeoPoint from, required GeoPoint to, required RoutePurpose purpose}) async {
    requests.add((from, to));
    purposes.add(purpose);
    if (failWith case final error?) throw error;
    return _routeFrom(from);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _FakeLocation location;
  late _FakeDirections directions;

  setUp(() {
    location = _FakeLocation();
    directions = _FakeDirections();
  });

  /// Runs [body] on fake time, with the ride already started.
  void ride(
    void Function(FakeAsync async, ProviderContainer container) body, {
    bool planned = true,
    GeoFix? mapPosition,
  }) {
    fakeAsync((async) {
      final container = ProviderContainer(
        overrides: [
          ridePlanningControllerProvider.overrideWith(planned ? _Planned.new : _NothingPlanned.new),
          myLocationControllerProvider.overrideWith(() => _MapPosition(mapPosition)),
          locationRepositoryProvider.overrideWithValue(location),
          directionsRepositoryProvider.overrideWithValue(directions),
          clockProvider.overrideWithValue(() => _t0.add(async.elapsed)),
        ],
      );
      // The map has its position before a ride starts.
      container.read(myLocationControllerProvider.future).ignore();
      async.flushMicrotasks();
      container.listen(soloRideControllerProvider, (_, _) {});
      async.flushMicrotasks();
      body(async, container);
      container.dispose();
      async.flushMicrotasks();
    });
  }

  SoloRideState? stateOf(ProviderContainer container) => container.read(soloRideControllerProvider);
  SoloRideController controllerOf(ProviderContainer container) => container.read(soloRideControllerProvider.notifier);

  /// A fix [meters] along the route, at the fake clock's time.
  void riderAt(FakeAsync async, double meters, {double speedMps = 10}) {
    location.fixes.add(fixAt(north(_start, meters), _t0.add(async.elapsed), speedMps: speedMps));
    async.flushMicrotasks();
  }

  test('there is no ride without a previewed route', () {
    ride(planned: false, (async, container) => expect(stateOf(container), isNull));
  });

  test("starts from the map's position, so progress shows before setting off", () {
    ride(mapPosition: fixAt(_start, _t0), (async, container) {
      final state = stateOf(container)!;
      expect(state.startedAt, _t0);
      expect(state.progress?.distanceRemainingMeters, closeTo(2000, 5));
    });
  });

  test('follows the rider along the route', () {
    ride((async, container) {
      expect(stateOf(container)!.progress, isNull, reason: 'waiting for GPS');

      riderAt(async, 0);
      async.elapse(const Duration(seconds: 30));
      riderAt(async, 500);

      final state = stateOf(container)!;
      expect(state.progress!.distanceRemainingMeters, closeTo(1500, 5));
      expect(state.progress!.fractionRidden, closeTo(.25, .01));
      expect(state.distanceRiddenMeters, closeTo(500, 5));
      expect(state.arrived, isFalse);
    });
  });

  test('arriving stops tracking and records when', () {
    ride((async, container) {
      riderAt(async, 0);
      async.elapse(const Duration(minutes: 3));
      riderAt(async, 1990);

      final state = stateOf(container)!;
      expect(state.arrived, isTrue);
      expect(state.arrivedAt, _t0.add(const Duration(minutes: 3)));

      // Later positions no longer count.
      riderAt(async, 500);
      expect(stateOf(container)!.lastFix?.position, north(_start, 1990));
    });
  });

  test('a ride too short to count is not saved', () {
    ride((async, container) {
      riderAt(async, 0);
      async.elapse(const Duration(seconds: 20));
      riderAt(async, 100);
      expect(controllerOf(container).finish(), isNull);
    });
  });

  test('a finished ride is saved as a solo ride', () {
    ride((async, container) {
      for (var step = 0; step <= 10; step++) {
        riderAt(async, step * 100.0);
        async.elapse(const Duration(seconds: 10));
      }

      final saved = controllerOf(container).finish()!;
      expect(saved.destinationName, 'Summit');
      expect(saved.arrived, isFalse);
      expect(saved.groupTripId, isNull);
      expect(saved.distanceMeters, closeTo(1000, 10));
      expect(saved.duration, const Duration(seconds: 110));
    });
  });

  test('rerouting asks for a route from where the rider is now', () {
    ride((async, container) {
      riderAt(async, 300);
      controllerOf(container).reroute();
      async.flushMicrotasks();

      expect(directions.requests, [(north(_start, 300), _end)]);
      expect(directions.purposes, [RoutePurpose.reroute]);
      final state = stateOf(container)!;
      expect(state.rerouting, isFalse);
      expect(state.route.path.first, north(_start, 300));
      expect(state.progress!.fractionRidden, closeTo(0, .01), reason: 'none of the new route is ridden');
    });
  });

  test('a failed reroute keeps the route and says why', () {
    ride((async, container) {
      riderAt(async, 300);
      directions.failWith = const RateLimitedFailure();
      controllerOf(container).reroute();
      async.flushMicrotasks();

      final state = stateOf(container)!;
      expect(state.rerouting, isFalse);
      expect(state.notice, isNotNull);
      expect(state.route.path.first, _start);
    });
  });

  test('losing location access is shown, and the next position clears it', () {
    ride((async, container) {
      location.fixes.addError(const LocationAccessLost(LocationAccess.serviceDisabled));
      async.flushMicrotasks();
      expect(stateOf(container)!.locationLost, LocationAccess.serviceDisabled);

      riderAt(async, 0);
      expect(stateOf(container)!.locationLost, isNull);
    });
  });

  test('coming back to the app restarts tracking once location is allowed again', () {
    ride((async, container) {
      location.fixes.addError(const LocationAccessLost(LocationAccess.denied));
      async.flushMicrotasks();

      location.access = LocationAccess.denied;
      controllerOf(container).recheckLocation();
      async.flushMicrotasks();
      expect(location.watches, 1);
      expect(stateOf(container)!.locationLost, LocationAccess.denied);

      location.access = LocationAccess.whileInUse;
      controllerOf(container).recheckLocation();
      async.flushMicrotasks();
      expect(location.watches, 2);
      expect(stateOf(container)!.locationLost, isNull);
    });
  });

  test('staying well off the route for a minute suggests a reroute; rerouting clears it', () {
    ride((async, container) {
      riderAt(async, 0);
      location.fixes.add(fixAt(east(north(_start, 500), 200), _t0.add(async.elapsed), speedMps: 8));
      async.flushMicrotasks();
      final since = stateOf(container)!.farOffRouteSince;
      expect(since, _t0);

      async.elapse(const Duration(seconds: 70));
      location.fixes.add(fixAt(east(north(_start, 600), 220), _t0.add(async.elapsed), speedMps: 8));
      async.flushMicrotasks();
      expect(stateOf(container)!.farOffRouteSince, since, reason: 'still off since then');
      expect(RouteRejoin.suggestReroute(farOffSince: since, now: _t0.add(async.elapsed)), isTrue);

      controllerOf(container).reroute();
      async.flushMicrotasks();
      expect(stateOf(container)!.farOffRouteSince, isNull);
    });
  });
}
