import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../auth/application/session_providers.dart';
import '../data/recent_places_store.dart';
import '../domain/map_models.dart';

part 'recent_places_controller.g.dart';

/// The signed-in user's recent destinations, newest first. Picking a recent
/// place reuses its saved coordinates, so it costs no Mapbox request.
@riverpod
class RecentPlacesController extends _$RecentPlacesController {
  static const maxPlaces = 10;

  @override
  List<Place> build() {
    final userId = ref.watch(currentUserProvider)?.id;
    if (userId == null) return const [];
    return ref.watch(recentPlacesStoreProvider).read(userId);
  }

  /// Puts [place] first, dropping an earlier copy and anything past [maxPlaces].
  Future<void> add(Place place) {
    return _replace([place, ...state.where((recent) => !recent.isSameAs(place))].take(maxPlaces).toList());
  }

  Future<void> remove(Place place) => _replace(state.where((recent) => !recent.isSameAs(place)).toList());

  Future<void> clear() => _replace(const []);

  Future<void> _replace(List<Place> places) async {
    final userId = ref.read(currentUserProvider)?.id;
    if (userId == null) return;
    state = places;
    await ref.read(recentPlacesStoreProvider).save(userId, places);
  }
}
