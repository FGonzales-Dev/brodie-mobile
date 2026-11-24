import 'dart:async';

import 'package:brodie/core/di/core_providers.dart';
import 'package:brodie/features/auth/application/session_providers.dart';
import 'package:brodie/features/auth/domain/app_user.dart';
import 'package:brodie/features/group_ride/application/group_ride_controller.dart';
import 'package:brodie/features/group_ride/data/trip_channel.dart';
import 'package:brodie/features/group_ride/domain/group_ride_models.dart';
import 'package:brodie/features/groups/data/group_repository.dart';
import 'package:brodie/features/groups/domain/group_models.dart';
import 'package:brodie/features/map/data/location_repository.dart';
import 'package:brodie/features/map/domain/map_models.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/geo.dart';

const _start = GeoPoint(latitude: 14.1, longitude: 120.9);
final _destination = north(_start, 10000);
final _t0 = DateTime.utc(2026, 11, 24, 8);

TripRider _rider(String id, int seat, {bool leader = false}) =>
    TripRider(userId: id, username: id, seat: seat, isLeader: leader);

/// One group's server state.
class _FakeGroups implements GroupRepository {
  GroupTrip? trip = GroupTrip(
    id: 'trip-1',
    groupId: 'group-1',
    leaderId: 'lea',
    name: 'Tagaytay',
    destination: _destination,
    status: TripStatus.active,
    route: TripRoute(
      version: 1,
      path: [_start, north(_start, 5000), _destination],
      distanceMeters: 10000,
      duration: const Duration(minutes: 12),
    ),
    createdAt: _t0,
    startedAt: _t0,
  );
  List<TripRider> riders = [_rider('lea', 0, leader: true), _rider('sam', 1)];
  final calls = <String>[];

  @override
  Future<GroupTrip?> fetchOpenTrip(String groupId) async => trip;

  @override
  Future<List<TripRider>> fetchTripRiders(String tripId) async {
    calls.add('riders');
    return List.of(riders);
  }

  @override
  Future<void> completeTrip(String tripId) async => calls.add('complete');

  @override
  Future<void> leaveTrip(String tripId) async => calls.add('leave');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeChannel implements TripChannel {
  final _events = StreamController<TripChannelEvent>.broadcast();
  int? seat;
  final sent = <({RiderFix fix, bool viaRest})>[];
  var announcedEnd = false;
  var closed = false;

  void receive(TripChannelEvent event) => _events.add(event);

  @override
  Stream<TripChannelEvent> get events => _events.stream;

  @override
  Future<void> connect({required int seat}) async => this.seat = seat;

  @override
  Future<void> sendFix(RiderFix fix, {bool viaRest = false}) async => sent.add((fix: fix, viaRest: viaRest));

  @override
  Future<void> announceEnd() async => announcedEnd = true;

  @override
  Future<void> close() async => closed = true;
}

class _FakeLocation extends LocationRepository {
  final fixes = StreamController<GeoFix>.broadcast();
  bool? background;

  @override
  Stream<GeoFix> watchPosition({int distanceFilterMeters = 10, bool keepRunningInBackground = false}) {
    background = keepRunningInBackground;
    return fixes.stream;
  }
}

RiderFix _fixOf(int seat, GeoPoint at, {required int tripSeconds, int speedKmh = 40}) => RiderFix(
      seat: seat,
      latitude: at.latitude,
      longitude: at.longitude,
      headingDegrees: 0,
      speedKmh: speedKmh,
      tripSeconds: tripSeconds,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeGroups server;
  late _FakeChannel channel;
  late _FakeLocation location;

  void reset() {
    SharedPreferences.setMockInitialValues({});
    server = _FakeGroups();
    channel = _FakeChannel();
    location = _FakeLocation();
  }

  setUp(reset);

  /// Runs [body] on fake time: the ride's timers and clock move only when
  /// the test elapses time.
  void ride(String me, void Function(FakeAsync async, ProviderContainer container) body) {
    fakeAsync((async) {
      late SharedPreferences prefs;
      SharedPreferences.getInstance().then((value) => prefs = value);
      async.flushMicrotasks();
      final container = ProviderContainer(overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        currentUserProvider.overrideWithValue(AppUser(id: me)),
        groupRepositoryProvider.overrideWithValue(server),
        locationRepositoryProvider.overrideWithValue(location),
        tripChannelFactoryProvider.overrideWithValue((_) => channel),
        rideClockProvider.overrideWithValue(() => _t0.add(async.elapsed)),
      ]);
      container.listen(groupRideControllerProvider('group-1'), (_, _) {});
      async.flushMicrotasks();
      body(async, container);
      container.dispose();
      async.flushMicrotasks();
    });
  }

  GroupRideState? stateOf(ProviderContainer container) => container.read(groupRideControllerProvider('group-1')).value;

  GroupRideController controllerOf(ProviderContainer container) =>
      container.read(groupRideControllerProvider('group-1').notifier);

  test('there is no ride when the trip has not started, or the user is not on it', () {
    server.trip = server.trip!.copyWith(status: TripStatus.planned);
    ride('sam', (async, container) => expect(stateOf(container), isNull));

    reset();
    ride('outsider', (async, container) => expect(stateOf(container), isNull));
  });

  test('joins the trip channel as its seat, with background location', () {
    ride('sam', (async, container) {
      final state = stateOf(container)!;
      expect(state.me.seat, 1);
      expect(state.isLeader, isFalse);
      expect([for (final other in state.others) other.rider.userId], ['lea']);
      expect(channel.seat, 1);
      expect(location.background, isTrue);
    });
  });

  test('sends the first fix at once, then only after the interval and real movement', () {
    ride('sam', (async, container) {
      location.fixes.add(fixAt(_start, _t0));
      async.flushMicrotasks();
      expect(channel.sent, hasLength(1));
      expect(channel.sent.single.fix.seat, 1);

      // Moved far, but too soon: held back...
      async.elapse(const Duration(seconds: 2));
      location.fixes.add(fixAt(north(_start, 100), _t0.add(async.elapsed)));
      async.flushMicrotasks();
      expect(channel.sent, hasLength(1));

      // ...and sent on the 5 s tick, once the interval allows.
      async.elapse(const Duration(seconds: 3));
      expect(channel.sent, hasLength(2));
      expect(channel.sent.last.fix.tripSeconds, 2);
      expect(channel.sent.last.viaRest, isFalse);

      // Past the interval again, but barely moved: no send.
      async.elapse(const Duration(seconds: 6));
      location.fixes.add(fixAt(north(_start, 120), _t0.add(async.elapsed)));
      async.flushMicrotasks();
      expect(channel.sent, hasLength(2));

      location.fixes.add(fixAt(north(_start, 300), _t0.add(async.elapsed)));
      async.flushMicrotasks();
      expect(channel.sent, hasLength(3));
    });
  });

  test('keeps sending heartbeats while stopped', () {
    ride('sam', (async, container) {
      location.fixes.add(fixAt(_start, _t0));
      async.flushMicrotasks();

      async.elapse(const Duration(seconds: 65));

      expect(channel.sent, hasLength(2));
    });
  });

  test('shows other riders, ignoring out-of-order fixes', () {
    ride('sam', (async, container) {
      channel.receive(RiderFixReceived(_fixOf(0, north(_start, 300), tripSeconds: 60)));
      async.flushMicrotasks();
      channel.receive(RiderFixReceived(_fixOf(0, north(_start, 100), tripSeconds: 50)));
      async.flushMicrotasks();

      final lea = stateOf(container)!.others.single;
      expect(lea.fix?.tripSeconds, 60);
      expect(lea.status, RiderStatus.live);

      // Their own fixes echoed back are not another rider.
      channel.receive(RiderFixReceived(_fixOf(1, _start, tripSeconds: 70)));
      async.flushMicrotasks();
      expect(stateOf(container)!.others, hasLength(1));
    });
  });

  test('a rider goes stale, then lost, when nothing arrives from them', () {
    ride('sam', (async, container) {
      channel.receive(RiderFixReceived(_fixOf(0, _start, tripSeconds: 1)));
      async.flushMicrotasks();

      async.elapse(const Duration(seconds: 45));
      expect(stateOf(container)!.others.single.status, RiderStatus.stale);

      async.elapse(const Duration(minutes: 3));
      expect(stateOf(container)!.others.single.status, RiderStatus.lost);
    });
  });

  test('a rider who joined late is added, and named once the roster loads', () {
    ride('sam', (async, container) {
      server.riders = [...server.riders, _rider('kai', 2)];
      // The roster was just loaded; the refresh waits out its minimum gap.
      async.elapse(const Duration(seconds: 16));

      channel.receive(RiderFixReceived(_fixOf(2, _start, tripSeconds: 30)));
      async.flushMicrotasks();

      final kai = stateOf(container)!.others.firstWhere((other) => other.rider.seat == 2);
      expect(kai.rider.username, 'kai');
      expect(kai.fix, isNotNull);
    });
  });

  test('presence marks who is online', () {
    ride('sam', (async, container) {
      channel.receive(const OnlineSeatsChanged({0, 1}));
      async.flushMicrotasks();
      expect(stateOf(container)!.others.single.online, isTrue);

      channel.receive(const OnlineSeatsChanged({1}));
      async.flushMicrotasks();
      expect(stateOf(container)!.others.single.online, isFalse);
    });
  });

  test('flags a rider who stays far behind, and says how far', () {
    ride('lea', (async, container) {
      // Lea (leader) is 6 km along; Sam keeps reporting from 2 km along.
      for (var second = 0; second <= 70; second += 5) {
        location.fixes.add(fixAt(north(_start, 6000), _t0.add(async.elapsed), speedMps: 11));
        channel.receive(RiderFixReceived(_fixOf(1, north(_start, 2000), tripSeconds: second)));
        async.elapse(const Duration(seconds: 5));
      }

      final sam = stateOf(container)!.others.single;
      expect(sam.behind, isTrue);
      expect(sam.metersBehindMe, closeTo(4000, 5));
      expect(stateOf(container)!.behind, [sam]);
    });
  });

  test('the leader ends the ride for everyone', () {
    ride('lea', (async, container) {
      controllerOf(container).endForEveryone();
      async.flushMicrotasks();

      expect(server.calls, contains('complete'));
      expect(channel.announcedEnd, isTrue);
      expect(channel.closed, isTrue);
      expect(stateOf(container)!.end, GroupRideEnd.endedByLeader);
    });
  });

  test('a rider leaves; the leader cannot leave', () {
    ride('sam', (async, container) {
      controllerOf(container).leave();
      async.flushMicrotasks();
      expect(server.calls, contains('leave'));
      expect(stateOf(container)!.end, GroupRideEnd.left);
      expect(channel.closed, isTrue);
    });

    reset();
    ride('lea', (async, container) {
      controllerOf(container).leave();
      async.flushMicrotasks();
      expect(server.calls, isNot(contains('leave')));
      expect(stateOf(container)!.ended, isFalse);
    });
  });

  test("riders find out the ride ended from the leader's message", () {
    ride('sam', (async, container) {
      channel.receive(const TripEndedByLeader());
      async.flushMicrotasks();
      expect(stateOf(container)!.end, GroupRideEnd.endedByLeader);
      expect(channel.closed, isTrue);
    });
  });

  test('...or from the periodic trip check, if they missed the message', () {
    ride('sam', (async, container) {
      server.trip = server.trip!.copyWith(status: TripStatus.completed);
      async.elapse(const Duration(seconds: 31));
      expect(stateOf(container)!.end, GroupRideEnd.endedByLeader);
    });
  });

  test('a ride too short to count is not saved', () {
    ride('sam', (async, container) {
      location.fixes.add(fixAt(_start, _t0));
      async.flushMicrotasks();
      expect(controllerOf(container).rideToSave(), isNull);
    });
  });
}
