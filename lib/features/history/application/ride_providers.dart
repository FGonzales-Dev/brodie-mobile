import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/errors/app_failure.dart';
import '../../auth/application/session_providers.dart';
import '../../vehicles/data/vehicle_repository.dart';
import '../data/ride_device_store.dart';
import '../data/ride_repository.dart';
import '../domain/ride.dart';
import '../domain/ride_filter.dart';

part 'ride_providers.g.dart';

/// Saving finished rides. A ride is kept on the phone first and uploaded
/// after, staying queued until the server confirms it, so a ride that ends
/// out of signal isn't lost: [uploadPending] retries on app start and resume.
///
/// State: the signed-in rider's rides still waiting to upload, newest first.
@Riverpod(keepAlive: true)
class RideSync extends _$RideSync {
  /// Rides with an upload under way, so overlapping retries don't repeat it.
  final _uploading = <String>{};

  @override
  List<Ride> build() {
    final userId = ref.watch(currentUserProvider)?.id;
    return userId == null ? const [] : ref.watch(rideDeviceStoreProvider).readPending(userId);
  }

  String? get _userId => ref.read(currentUserProvider)?.id;

  /// Queues [ride], gives it the rider's usual vehicle, and uploads it.
  /// Returns whether it reached the server; if not, it stays queued.
  Future<bool> save(Ride ride) async {
    _uploading.add(ride.id);
    try {
      await _setPending([ride, ...state]);
      final vehicleId = await _defaultVehicleId();
      if (vehicleId != null) await _replacePending(ride.copyWith(vehicleId: vehicleId));
      return await _upload(ride.id);
    } finally {
      _uploading.remove(ride.id);
    }
  }

  /// Retries every queued ride; failures stay queued for next time.
  Future<void> uploadPending() async {
    for (final ride in state) {
      if (!_uploading.add(ride.id)) continue;
      try {
        await _upload(ride.id);
      } catch (_) {
        // Rejected by the server and dropped (see _upload); nothing to show here.
      } finally {
        _uploading.remove(ride.id);
      }
    }
  }

  /// Null clears the vehicle. The choice becomes the default for new rides.
  Future<void> setVehicle(String rideId, String? vehicleId) async {
    final userId = _userId;
    if (userId == null) return;
    final pending = _pendingRide(rideId);
    if (pending != null) {
      await _replacePending(pending.copyWith(vehicleId: vehicleId));
      // In case an earlier upload reached the server without confirming.
      try {
        await ref.read(rideRepositoryProvider).setVehicle(rideId, vehicleId);
      } catch (_) {}
    } else {
      await ref.read(rideRepositoryProvider).setVehicle(rideId, vehicleId);
      ref
      ..invalidate(rideHistoryControllerProvider)
      ..invalidate(rideHistoryTotalsProvider);
    }
    ref.invalidate(rideDetailProvider(rideId));
    await ref.read(rideDeviceStoreProvider).saveLastVehicle(userId, vehicleId);
  }

  Future<void> delete(String rideId) async {
    if (_pendingRide(rideId) != null) {
      await _setPending([for (final ride in state) if (ride.id != rideId) ride]);
      // It may have reached the server without confirming; if it didn't,
      // there's nothing to delete there.
      try {
        await ref.read(rideRepositoryProvider).delete(rideId);
      } catch (_) {}
    } else {
      await ref.read(rideRepositoryProvider).delete(rideId);
    }
    ref
      ..invalidate(rideHistoryControllerProvider)
      ..invalidate(rideHistoryTotalsProvider);
  }

  /// The vehicle picked last, else the only one in the garage.
  Future<String?> _defaultVehicleId() async {
    final userId = _userId;
    if (userId == null) return null;
    final remembered = ref.read(rideDeviceStoreProvider).readLastVehicle(userId);
    if (remembered != null) return remembered;
    try {
      final vehicles = await ref.read(vehicleRepositoryProvider).fetchMine();
      return vehicles.length == 1 ? vehicles.single.id : null;
    } catch (_) {
      return null;
    }
  }

  /// Returns whether the ride reached the server. A ride the server rejects
  /// can never upload, so it's dropped and the failure rethrown.
  Future<bool> _upload(String rideId) async {
    final ride = _pendingRide(rideId);
    if (ride == null) return true;
    try {
      await ref.read(rideRepositoryProvider).save(ride);
    } on ValidationFailure {
      await _removePending(rideId);
      rethrow;
    } catch (_) {
      return false;
    }
    await _removePending(rideId);
    ref
      ..invalidate(rideHistoryControllerProvider)
      ..invalidate(rideHistoryTotalsProvider);
    return true;
  }

  Ride? _pendingRide(String rideId) => state.where((ride) => ride.id == rideId).firstOrNull;

  Future<void> _replacePending(Ride updated) {
    return _setPending([for (final ride in state) ride.id == updated.id ? updated : ride]);
  }

  Future<void> _removePending(String rideId) {
    return _setPending([for (final ride in state) if (ride.id != rideId) ride]);
  }

  Future<void> _setPending(List<Ride> rides) async {
    final userId = _userId;
    if (userId == null) return;
    state = rides;
    await ref.read(rideDeviceStoreProvider).savePending(userId, rides);
  }
}

typedef RideHistoryPage = ({List<Ride> rides, bool hasMore});

/// How the History tab is filtered and sorted. Kept while the app runs, so
/// it survives switching tabs; a fresh launch starts unfiltered.
@Riverpod(keepAlive: true)
class RideFilterController extends _$RideFilterController {
  @override
  RideFilter build() {
    ref.watch(currentUserProvider);
    return const RideFilter();
  }

  void update(RideFilter Function(RideFilter current) change) => state = change(state);

  void clear() => state = const RideFilter();
}

/// The rider's saved rides matching the current filter, a page at a time.
/// Rides still waiting to upload come from [rideSyncProvider] instead.
@riverpod
class RideHistoryController extends _$RideHistoryController {
  static const pageSize = 20;

  /// Fixed when the list loads, so every page agrees on what "this month"
  /// means.
  late DateTime _now;
  late RideFilter _filter;

  @override
  Future<RideHistoryPage> build() async {
    ref.watch(currentUserProvider);
    _filter = ref.watch(rideFilterControllerProvider);
    _now = DateTime.now();
    final rides = await ref
        .watch(rideRepositoryProvider)
        .fetchHistory(limit: pageSize, offset: 0, filter: _filter, now: _now);
    return (rides: rides, hasMore: rides.length == pageSize);
  }

  /// Failures propagate to the caller; the loaded rides stay.
  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasMore || state.isLoading) return;
    final next = await ref
        .read(rideRepositoryProvider)
        .fetchHistory(limit: pageSize, offset: current.rides.length, filter: _filter, now: _now);
    // A ride saved since the first page shifts the offsets by one.
    final known = {for (final ride in current.rides) ride.id};
    state = AsyncData((
      rides: [...current.rides, ...next.where((ride) => !known.contains(ride.id))],
      hasMore: next.length == pageSize,
    ));
  }
}

/// What the filtered history adds up to, for the line above the list.
@riverpod
Future<RideTotals> rideHistoryTotals(Ref ref) {
  ref.watch(currentUserProvider);
  return ref.watch(rideRepositoryProvider).fetchTotals(filter: ref.watch(rideFilterControllerProvider));
}

/// One ride with its route: from the upload queue while it's waiting there,
/// otherwise from the server. The queue is read, not watched, so the ride
/// on screen doesn't reload when it finishes uploading or is deleted;
/// [RideSync.setVehicle] refreshes it instead.
@riverpod
Future<Ride> rideDetail(Ref ref, String rideId) async {
  final pending = ref.read(rideSyncProvider).where((ride) => ride.id == rideId).firstOrNull;
  return pending ?? ref.watch(rideRepositoryProvider).fetchRide(rideId);
}
