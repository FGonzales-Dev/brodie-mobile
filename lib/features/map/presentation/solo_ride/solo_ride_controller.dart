import 'dart:async';

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/di/core_providers.dart';
import '../../../../core/errors/app_failure.dart';
import '../../../history/domain/ride.dart';
import '../../../history/domain/ride_from_track.dart';
import '../../application/my_location_providers.dart';
import '../../data/directions_repository.dart';
import '../../data/location_repository.dart';
import '../../domain/location_health.dart';
import '../../domain/map_models.dart';
import '../../domain/route_rejoin.dart';
import '../../domain/route_tracker.dart';
import '../../domain/track_recorder.dart';
import '../ride_planning_controller.dart';

part 'solo_ride_controller.freezed.dart';
part 'solo_ride_controller.g.dart';

@freezed
abstract class SoloRideState with _$SoloRideState {
  const factory SoloRideState({
    required Place destination,
    required RouteResult route,
    required DateTime startedAt,

    /// Null until the first GPS fix.
    RideProgress? progress,
    GeoFix? lastFix,
    @Default(0) double distanceRiddenMeters,
    @Default(false) bool rerouting,

    /// A problem worth showing, e.g. the daily route limit blocked a reroute.
    String? notice,
    DateTime? arrivedAt,

    /// Set when the phone stopped giving the app locations mid-ride (access
    /// turned off, or location switched off); cleared once they're back.
    LocationAccess? locationLost,

    /// Since when the rider has been well off the route (see [RouteRejoin]);
    /// null while on or near it.
    DateTime? farOffRouteSince,
  }) = _SoloRideState;

  const SoloRideState._();

  bool get arrived => arrivedAt != null;
}

/// An active solo ride. It starts from the route the rider just previewed (no
/// extra Directions request) and spends one only when the rider asks for a
/// new route ([reroute]).
@riverpod
class SoloRideController extends _$SoloRideController {
  /// GPS updates during a ride: often enough for turn distances and speed.
  static const _distanceFilterMeters = 5;

  late RouteTracker _tracker;
  final _track = TrackRecorder();
  StreamSubscription<GeoFix>? _fixes;

  DateTime _now() => ref.read(clockProvider)();

  /// Null when there's no previewed route to ride (e.g. the app was
  /// restarted on this screen); the screen then offers a way back.
  @override
  SoloRideState? build() {
    final plan = ref.read(ridePlanningControllerProvider);
    if (plan is! RidePlanPreview) return null;

    _tracker = RouteTracker(plan.route, destination: plan.destination.location);
    _listen();
    ref.onDispose(() => _fixes?.cancel());

    // The ride's GPS feed only reports after the rider moves, so start from
    // the fix the map already has; the first turn shows before setting off.
    final lastKnown = ref.read(myLocationControllerProvider).value;
    if (lastKnown != null) Future.microtask(() => _onFix(lastKnown));

    return SoloRideState(destination: plan.destination, route: plan.route, startedAt: _now());
  }

  void _listen() {
    _fixes?.cancel();
    _fixes = ref
        .read(locationRepositoryProvider)
        .watchPosition(distanceFilterMeters: _distanceFilterMeters)
        .listen(_onFix, onError: _onLocationError);
  }

  void _onLocationError(Object error) {
    final current = state;
    if (error is LocationAccessLost && current != null && !current.arrived) {
      state = current.copyWith(locationLost: error.access);
    }
  }

  /// Call when the app comes back to the foreground: if location was lost
  /// and is allowed again, tracking restarts.
  Future<void> recheckLocation() async {
    final lost = state?.locationLost;
    if (lost == null) return;
    final access = await ref.read(locationRepositoryProvider).checkAccess();
    final current = state;
    if (!ref.mounted || current == null || current.locationLost == null) return;
    if (access.isGranted) {
      state = current.copyWith(locationLost: null);
      _listen();
    } else {
      state = current.copyWith(locationLost: access);
    }
  }

  void _onFix(GeoFix fix) {
    final current = state;
    if (current == null || current.arrived) return;

    _track.add(fix);
    final progress = _tracker.progressAt(fix);
    var next = current.copyWith(
      progress: progress,
      lastFix: fix,
      distanceRiddenMeters: _track.distanceMeters,
      locationLost: null,
      farOffRouteSince: RouteRejoin.farOffSince(progress, since: current.farOffRouteSince, now: _now()),
    );
    if (progress.arrived) {
      next = next.copyWith(arrivedAt: _now());
      _fixes?.cancel();
    }
    state = next;
  }

  /// Stops tracking and returns the ride to save, or null when it was too
  /// short to keep.
  Ride? finish() {
    final current = state;
    _fixes?.cancel();
    if (current == null) return null;

    return rideFromTrack(
      _track,
      startedAt: current.startedAt,
      endedAt: current.arrivedAt ?? _now(),
      arrived: current.arrived,
      destinationName: current.destination.name,
    );
  }

  /// A new route from where the rider is now. Each one is a billed
  /// Directions request, so it happens only when the rider asks.
  Future<void> reroute() async {
    final current = state;
    final from = current?.lastFix;
    if (current == null || from == null || current.arrived || current.rerouting) return;

    state = current.copyWith(rerouting: true, notice: null);
    try {
      final destination = current.destination.location;
      final route = await ref
          .read(directionsRepositoryProvider)
          .fetchRoute(from: from.position, to: destination, purpose: RoutePurpose.reroute);
      if (!ref.mounted) return;
      _tracker = RouteTracker(route, destination: destination);
      // Progress on the new route straight away, not after the next fix.
      final latest = state?.lastFix ?? from;
      state = state?.copyWith(
        route: route,
        progress: _tracker.progressAt(latest),
        rerouting: false,
        farOffRouteSince: null,
      );
    } catch (error) {
      if (!ref.mounted) return;
      state = state?.copyWith(rerouting: false, notice: AppFailure.messageFor(error));
    }
  }
}
