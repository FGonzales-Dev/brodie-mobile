import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';

import '../../../core/utils/debouncer.dart';
import '../application/my_location_providers.dart';
import '../data/last_location_store.dart';
import '../data/place_search_repository.dart';
import '../domain/map_models.dart';

part 'destination_search_controller.g.dart';

/// Debounced place search. Mapbox bills searches, so a request only goes out
/// once the user pauses typing with at least [minQueryLength] characters, and
/// one session token per screen visit groups suggest and retrieve calls into
/// a single billed session.
@riverpod
class DestinationSearchController extends _$DestinationSearchController {
  static const minQueryLength = 3;

  final _sessionToken = const Uuid().v4();
  final _debouncer = Debouncer(const Duration(milliseconds: 300));

  @override
  Future<List<PlaceSuggestion>> build(SearchPurpose purpose) {
    ref.onDispose(_debouncer.cancel);
    return Future.value(const []);
  }

  void search(String query) {
    final trimmed = query.trim();
    if (trimmed.length < minQueryLength) {
      _debouncer.cancel();
      state = const AsyncData([]);
      return;
    }
    _debouncer.run(() async {
      state = const AsyncLoading();
      state = await AsyncValue.guard(
        () => ref
            .read(placeSearchRepositoryProvider)
            .suggest(trimmed, sessionToken: _sessionToken, purpose: purpose, near: _near()),
      );
    });
  }

  /// Biases results toward the rider; without it Mapbox ranks matches
  /// worldwide (e.g. a chain's branches in another country first).
  GeoPoint? _near() =>
      ref.read(myLocationControllerProvider).value?.position ?? ref.read(lastLocationStoreProvider).read();

  Future<Place> resolve(PlaceSuggestion suggestion) {
    return ref.read(placeSearchRepositoryProvider).retrieve(suggestion, sessionToken: _sessionToken, purpose: purpose);
  }
}
