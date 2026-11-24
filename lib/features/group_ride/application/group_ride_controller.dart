import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';

import '../../auth/application/session_providers.dart';
import '../../groups/application/group_providers.dart';
import '../../groups/data/group_repository.dart';
import '../../groups/domain/group_models.dart';
import '../../history/domain/ride.dart';
import '../../map/data/location_repository.dart';
import '../../map/domain/map_models.dart';
import '../../map/domain/polyline_codec.dart';
import '../../map/domain/route_geometry.dart';
import '../../map/domain/route_tracker.dart';
import '../../map/domain/track_recorder.dart';
import '../../map/presentation/solo_ride/solo_ride_controller.dart';
import '../../settings/application/settings_controller.dart';
import '../data/trip_channel.dart';
import '../domain/gap_detector.dart';
import '../domain/group_ride_models.dart';
import '../domain/position_codec.dart';
import '../domain/send_policy.dart';

part 'group_ride_controller.freezed.dart';
part 'group_ride_controller.g.dart';

/// What this phone knows about one of the other riders.
@freezed
abstract class LiveRider with _$LiveRider {
  const factory LiveRider({
    required TripRider rider,

    /// Their latest position; null until the first one arrives.
    RiderFix? fix,

    /// When that position arrived, by this phone's clock.
    DateTime? heardAt,

    /// Null until a position has arrived.
    RiderStatus? status,

    /// Connected to the ride channel right now.
    @Default(false) bool online,

    /// Flagged by the gap detector.
    @Default(false) bool behind,

    /// How far behind this rider they are along the route, in meters;
    /// negative when they're ahead. Null without a position on both sides.
    double? metersBehindMe,

    /// When they sent an SOS that's still on; null otherwise.
    DateTime? sosAt,
  }) = _LiveRider;
}

/// Why the ride stopped on this phone.
enum GroupRideEnd {
  /// The leader ended it for everyone.
  endedByLeader,

  /// This rider left it.
  left,
}

@freezed
abstract class GroupRideState with _$GroupRideState {
  const factory GroupRideState({
    required GroupTrip trip,
    required TripRider me,

    /// Everyone else on the trip, by seat.
    required List<LiveRider> others,

    /// When this phone started riding, for the saved ride.
    required DateTime startedAt,
    GeoFix? lastFix,
    RideProgress? progress,
    @Default(0) double distanceRiddenMeters,

    /// Connected to the ride channel. Positions still go out over REST
    /// while not, but nothing comes in.
    @Default(false) bool connected,
    GroupRideEnd? end,
    DateTime? endedAt,

    /// When this rider sent an SOS that's still on; null otherwise.
    DateTime? mySosAt,
  }) = _GroupRideState;

  const GroupRideState._();

  bool get isLeader => me.isLeader;

  bool get ended => end != null;

  List<LiveRider> get behind => [for (final rider in others) if (rider.behind) rider];

  /// Riders whose SOS is on, earliest first.
  List<LiveRider> get sos => [for (final rider in others) if (rider.sosAt != null) rider]
    ..sort((a, b) => a.sosAt!.compareTo(b.sosAt!));
}

/// The clock the ride reads; tests replace it.
@riverpod
DateTime Function() rideClock(Ref ref) => DateTime.now;

/// A started group ride on this phone: shares the rider's position on the
/// trip's live channel, shows everyone else's, and flags riders who fall
/// behind. Positions only pass through the channel; nothing is written to
/// the database while riding.
///
/// Null when the group has no started ride this user is on (it ended, or
/// they never joined).
@riverpod
class GroupRideController extends _$GroupRideController {
  /// Re-check sends (heartbeats while stopped) and statuses this often.
  static const _tickEvery = Duration(seconds: 5);

  /// Confirm with the server that the ride is still on, in case the
  /// leader's "ended" message was missed (e.g. no signal at the time).
  static const _checkTripEvery = Duration(seconds: 30);

  /// Fetch the roster at most this often when an unknown seat shows up.
  static const _rosterRefreshMin = Duration(seconds: 15);

  static const _distanceFilterMeters = 5;

  late TripChannel _channel;
  late SendPolicy _policy;
  late RouteTracker _tracker;
  late RouteGeometry _geometry;
  late DateTime _tripStartedAt;
  final _gaps = GapDetector();
  final _track = TrackRecorder();
  final _others = <int, LiveRider>{};
  final _alongBySeat = <int, double>{};
  final _subscriptions = <StreamSubscription<Object?>>[];
  final _timers = <Timer>[];
  AppLifecycleListener? _lifecycle;
  var _channelOpen = true;
  var _inBackground = false;
  DateTime? _rosterRefreshedAt;

  DateTime _now() => ref.read(rideClockProvider)();

  GroupRepository get _repository => ref.read(groupRepositoryProvider);

  @override
  Future<GroupRideState?> build(String groupId) async {
    final myId = ref.read(currentUserProvider)?.id;
    if (myId == null) return null;
    final trip = await _repository.fetchOpenTrip(groupId);
    if (trip == null || trip.status != TripStatus.active) return null;
    final roster = await _repository.fetchTripRiders(trip.id);
    final me = roster.where((rider) => rider.userId == myId).firstOrNull;
    if (me == null || !ref.mounted) return null;

    final now = _now();
    _tripStartedAt = trip.startedAt ?? now;
    final route = trip.route;
    _geometry = RouteGeometry(route.path);
    _tracker = RouteTracker(
      RouteResult(
        path: route.path,
        distanceMeters: route.distanceMeters,
        duration: route.duration,
        encodedPolyline: PolylineCodec.encode(route.path),
      ),
      destination: trip.destination,
    );
    _policy = SendPolicy(_sendProfile());
    _setRoster(roster, mySeat: me.seat);
    _rosterRefreshedAt = now;

    ref.onDispose(_stop);
    _channel = ref.read(tripChannelFactoryProvider)(trip.id);
    _subscriptions
      ..add(_channel.events.listen(_onChannelEvent))
      ..add(
        ref
            .read(locationRepositoryProvider)
            .watchPosition(distanceFilterMeters: _distanceFilterMeters, keepRunningInBackground: true)
            .listen(_onFix, onError: (Object _) {}),
      );
    _timers
      ..add(Timer.periodic(_tickEvery, (_) => _onTick()))
      ..add(Timer.periodic(_checkTripEvery, (_) => _checkTrip()));
    _lifecycle = AppLifecycleListener(onStateChange: _onLifecycle);
    // Failing to join isn't fatal: positions still go out over REST, and the
    // client keeps retrying the connection.
    unawaited(_channel.connect(seat: me.seat).catchError((Object _) {}));

    return GroupRideState(trip: trip, me: me, others: _sortedOthers(), startedAt: now);
  }

  SendProfile _sendProfile() {
    final settings = ref.read(settingsControllerProvider);
    return SendProfile.forRide(
      intervalSeconds: settings.broadcastIntervalSeconds,
      batterySaver: settings.batterySaver,
      inBackground: _inBackground,
    );
  }

  void _onLifecycle(AppLifecycleState lifecycle) {
    _inBackground = lifecycle != AppLifecycleState.resumed;
    _policy.profile = _sendProfile();
  }

  void _onFix(GeoFix fix) {
    final current = state.value;
    if (current == null || current.ended) return;

    _track.add(fix);
    _alongBySeat[current.me.seat] = _geometry.project(fix.position).alongRoute;
    _maybeSend(fix, mySeat: current.me.seat);
    _emit(
      current.copyWith(
        lastFix: fix,
        progress: _tracker.progressAt(fix),
        distanceRiddenMeters: _track.distanceMeters,
      ),
    );
  }

  void _maybeSend(GeoFix fix, {required int mySeat}) {
    final now = _now();
    if (!_policy.shouldSend(fix, now)) return;
    _policy.markSent(fix, now);
    final riderFix = PositionCodec.fromDeviceFix(fix, seat: mySeat, tripStartedAt: _tripStartedAt);
    // A lost send is replaced by the next one; nothing to retry.
    unawaited(_channel.sendFix(riderFix, viaRest: _inBackground).catchError((Object _) {}));
  }

  /// GPS goes quiet while the rider is stopped, so heartbeats and statuses
  /// run on a timer too.
  void _onTick() {
    final current = state.value;
    if (current == null || current.ended) return;
    final fix = current.lastFix;
    if (fix != null) _maybeSend(fix, mySeat: current.me.seat);
    _emit(current);
  }

  void _onChannelEvent(TripChannelEvent event) {
    final current = state.value;
    if (current == null || current.ended) return;
    switch (event) {
      case RiderFixReceived(:final fix):
        _onRiderFix(fix, current);
      case OnlineSeatsChanged(:final seats):
        for (final MapEntry(key: seat, value: rider) in _others.entries) {
          _others[seat] = rider.copyWith(online: seats.contains(seat));
        }
        if (seats.any((seat) => seat != current.me.seat && !_others.containsKey(seat))) {
          unawaited(_refreshRoster());
        }
        _emit(current);
      case RiderSosChanged(:final signal):
        _onRiderSos(signal, current);
      case TripEndedByLeader():
        _finishRiding(GroupRideEnd.endedByLeader);
      case ChannelConnectionChanged(:final connected):
        _emit(current.copyWith(connected: connected));
    }
  }

  void _onRiderFix(RiderFix fix, GroupRideState current) {
    if (fix.seat == current.me.seat) return;
    final known = _others[fix.seat];
    if (known == null) {
      // Someone joined after this phone loaded the roster. Show them now;
      // their name arrives with the roster.
      _others[fix.seat] = LiveRider(rider: TripRider(userId: '', seat: fix.seat, isLeader: false));
      unawaited(_refreshRoster());
    }
    final rider = _others[fix.seat]!;
    // Fixes can arrive out of order; keep the newest.
    final previous = rider.fix;
    if (previous != null && fix.tripSeconds < previous.tripSeconds) return;

    _others[fix.seat] = rider.copyWith(fix: fix, heardAt: _now());
    _alongBySeat[fix.seat] = _geometry.project(GeoPoint(latitude: fix.latitude, longitude: fix.longitude)).alongRoute;
    _emit(current);
  }

  void _onRiderSos(SosSignal signal, GroupRideState current) {
    if (signal.seat == current.me.seat) return;
    if (!_others.containsKey(signal.seat)) {
      _others[signal.seat] = LiveRider(rider: TripRider(userId: '', seat: signal.seat, isLeader: false));
      unawaited(_refreshRoster());
    }
    final rider = _others[signal.seat]!;
    _others[signal.seat] = rider.copyWith(sosAt: signal.active ? (rider.sosAt ?? _now()) : null);
    // The alert's position counts as a fix, so the map shows where they are
    // (unless a newer fix already arrived).
    if (signal.fix case final fix?) _onRiderFix(fix, current);
    // Published even when the fix was dropped as out of date.
    _emit(state.value ?? current);
  }

  /// Tells the group this rider needs help, with their latest position.
  /// Stays on until [cancelSos]. Throws when it couldn't be sent.
  Future<void> sendSos() async {
    final current = state.value;
    if (current == null || current.ended) return;
    final fix = current.lastFix;
    await _channel.sendSos((
      seat: current.me.seat,
      active: true,
      fix: fix == null ? null : PositionCodec.fromDeviceFix(fix, seat: current.me.seat, tripStartedAt: _tripStartedAt),
    ));
    final latest = state.value;
    if (latest != null && ref.mounted) state = AsyncData(latest.copyWith(mySosAt: latest.mySosAt ?? _now()));
  }

  /// Tells the group this rider is safe again.
  Future<void> cancelSos() async {
    final current = state.value;
    if (current == null || current.mySosAt == null) return;
    await _channel.sendSos((seat: current.me.seat, active: false, fix: null));
    final latest = state.value;
    if (latest != null && ref.mounted) state = AsyncData(latest.copyWith(mySosAt: null));
  }

  /// Recomputes every rider's status and gap, then publishes [next].
  void _emit(GroupRideState next) {
    final now = _now();
    final mySeat = next.me.seat;
    final myAlong = _alongBySeat[mySeat];

    final progress = <int, RiderProgress>{
      if (myAlong != null)
        mySeat: (alongRouteMeters: myAlong, speedMps: _speedMps(next.lastFix), lastHeardAt: now),
      for (final MapEntry(key: seat, value: rider) in _others.entries)
        if ((rider.fix, rider.heardAt, _alongBySeat[seat]) case (final fix?, final heardAt?, final along?))
          seat: (alongRouteMeters: along, speedMps: fix.speedKmh / 3.6, lastHeardAt: heardAt),
    };
    final behind = _gaps.evaluate(progress, now);

    for (final MapEntry(key: seat, value: rider) in _others.entries) {
      final heardAt = rider.heardAt;
      final along = _alongBySeat[seat];
      _others[seat] = rider.copyWith(
        status: heardAt == null ? null : RiderStatus.at(lastHeardAt: heardAt, now: now),
        behind: behind.contains(seat),
        metersBehindMe: myAlong == null || along == null ? null : myAlong - along,
      );
    }
    state = AsyncData(next.copyWith(others: _sortedOthers()));
  }

  static double _speedMps(GeoFix? fix) {
    final speed = fix?.speedMps ?? 0;
    return speed.isFinite && speed > 0 ? speed : 0;
  }

  List<LiveRider> _sortedOthers() => [
        for (final seat in _others.keys.toList()..sort()) _others[seat]!,
      ];

  /// Keeps what's known about riders still on the trip; drops riders who left.
  void _setRoster(List<TripRider> roster, {required int mySeat}) {
    final onTrip = {for (final rider in roster) if (rider.seat != mySeat) rider.seat: rider};
    _others.removeWhere((seat, _) => !onTrip.containsKey(seat));
    _alongBySeat.removeWhere((seat, _) => seat != mySeat && !onTrip.containsKey(seat));
    for (final MapEntry(key: seat, value: rider) in onTrip.entries) {
      _others[seat] = (_others[seat] ?? LiveRider(rider: rider)).copyWith(rider: rider);
    }
  }

  Future<void> _refreshRoster() async {
    final current = state.value;
    final last = _rosterRefreshedAt;
    final now = _now();
    if (current == null || (last != null && now.difference(last) < _rosterRefreshMin)) return;
    _rosterRefreshedAt = now;
    try {
      final roster = await _repository.fetchTripRiders(current.trip.id);
      final latest = state.value;
      if (!ref.mounted || latest == null || latest.ended) return;
      _setRoster(roster, mySeat: latest.me.seat);
      _emit(latest);
    } catch (_) {
      // No signal; the next check tries again.
    }
  }

  Future<void> _checkTrip() async {
    final current = state.value;
    if (current == null || current.ended) return;
    try {
      final trip = await _repository.fetchOpenTrip(current.trip.groupId);
      if (!ref.mounted) return;
      if (trip == null || trip.id != current.trip.id || trip.status != TripStatus.active) {
        _finishRiding(GroupRideEnd.endedByLeader);
        return;
      }
      _rosterRefreshedAt = null;
      await _refreshRoster();
    } catch (_) {
      // No signal; try again next time.
    }
  }

  /// Leader only: ends the ride for everyone.
  Future<void> endForEveryone() async {
    final current = state.value;
    if (current == null || current.ended || !current.isLeader) return;
    await _repository.completeTrip(current.trip.id);
    // Riders who miss this find out on their next trip check.
    await _channel.announceEnd().catchError((Object _) {});
    _finishRiding(GroupRideEnd.endedByLeader);
  }

  /// Not for the leader, who ends the ride instead.
  Future<void> leave() async {
    final current = state.value;
    if (current == null || current.ended || current.isLeader) return;
    await _repository.leaveTrip(current.trip.id);
    _finishRiding(GroupRideEnd.left);
  }

  void _finishRiding(GroupRideEnd end) {
    final current = state.value;
    if (current == null || current.ended) return;
    _stop();
    ref
      ..invalidate(myGroupsProvider)
      ..invalidate(groupRideHistoryProvider(current.trip.groupId));
    state = AsyncData(current.copyWith(end: end, endedAt: _now()));
  }

  /// This rider's part of the ride, for their history, or null when it was
  /// too short to keep (same rule as a solo ride).
  Ride? rideToSave() {
    final current = state.value;
    if (current == null) return null;
    final endedAt = current.endedAt ?? _now();
    final duration = endedAt.difference(current.startedAt);
    final path = _track.path;
    if (path.length < 2 ||
        _track.distanceMeters < SoloRideController.minSavedDistanceMeters ||
        duration < SoloRideController.minSavedDuration) {
      return null;
    }
    final progress = current.progress;
    return Ride(
      id: const Uuid().v4(),
      destinationName: current.trip.name,
      arrived: progress?.arrived ?? false,
      distanceMeters: _track.distanceMeters,
      duration: duration,
      movingTime: _track.movingTime,
      maxSpeedMps: _track.maxSpeedMps,
      startedAt: current.startedAt,
      endedAt: endedAt,
      path: path,
      groupTripId: current.trip.id,
    );
  }

  /// Stops GPS, timers and the channel. Safe to call more than once.
  void _stop() {
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    _subscriptions.clear();
    for (final timer in _timers) {
      timer.cancel();
    }
    _timers.clear();
    _lifecycle?.dispose();
    _lifecycle = null;
    if (_channelOpen) {
      _channelOpen = false;
      unawaited(_channel.close().catchError((Object _) {}));
    }
  }
}
