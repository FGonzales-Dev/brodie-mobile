import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../group_ride/domain/group_ride_models.dart';
import '../../map/data/directions_repository.dart';
import '../../map/data/location_repository.dart';
import '../../map/domain/map_models.dart';
import '../data/group_repository.dart';
import '../domain/group_models.dart';
import 'group_providers.dart';

part 'group_lobby_controller.g.dart';

/// A group's open trip and the riders who have joined it.
typedef GroupLobby = ({GroupTrip trip, List<TripRider> riders});

/// The lobby on a group's screen: its planned or active trip (null when
/// there is none), refreshed every few seconds while the screen is open so
/// riders see each other join and the leader start.
@riverpod
class GroupLobbyController extends _$GroupLobbyController {
  static const _refreshEvery = Duration(seconds: 5);

  @override
  Future<GroupLobby?> build(String groupId) async {
    final timer = Timer.periodic(_refreshEvery, (_) => _refreshQuietly());
    ref.onDispose(timer.cancel);
    return _load();
  }

  Future<GroupLobby?> _load() async {
    final repository = ref.read(groupRepositoryProvider);
    final trip = await repository.fetchOpenTrip(groupId);
    if (trip == null) return null;
    return (trip: trip, riders: await repository.fetchTripRiders(trip.id));
  }

  var _hidden = false;

  /// Call when the lobby is covered by another screen (e.g. the ride) or
  /// shown again. While hidden it stops checking the server every few
  /// seconds; when shown again it catches up at once.
  void setVisible(bool visible) {
    final wasHidden = _hidden;
    _hidden = !visible;
    if (visible && wasHidden) unawaited(_refreshQuietly());
  }

  /// Keeps what's on screen when a background refresh fails (e.g. no signal).
  Future<void> _refreshQuietly() async {
    if (state.isLoading || _hidden) return;
    try {
      final lobby = await _load();
      if (ref.mounted) state = AsyncData(lobby);
    } catch (_) {}
  }

  /// Leader only: plans a ride to [destination] along a route from where the
  /// leader is now, which is where the group meets.
  Future<void> planTo(Place destination) async {
    final origin = await ref.read(locationRepositoryProvider).currentPosition();
    final route = await ref.read(directionsRepositoryProvider).fetchRoute(from: origin, to: destination.location);
    await ref.read(groupRepositoryProvider).planTrip(groupId: groupId, destination: destination, route: route);
    await _reload();
  }

  Future<void> join() => _onTrip(ref.read(groupRepositoryProvider).joinTrip);

  Future<void> leave() => _onTrip(ref.read(groupRepositoryProvider).leaveTrip);

  Future<void> start() => _onTrip(ref.read(groupRepositoryProvider).startTrip);

  Future<void> cancel() => _onTrip(ref.read(groupRepositoryProvider).cancelTrip);

  Future<void> _onTrip(Future<void> Function(String tripId) action) async {
    final trip = state.value?.trip;
    if (trip == null) return;
    await action(trip.id);
    await _reload();
  }

  /// Also refreshes the groups list, which shows each group's trip status.
  Future<void> _reload() async {
    ref.invalidate(myGroupsProvider);
    state = AsyncData(await _load());
  }
}
