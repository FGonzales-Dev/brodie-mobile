import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';

import '../../../core/utils/debouncer.dart';
import '../application/my_location_providers.dart';
import '../data/last_location_store.dart';
import '../data/place_search_repository.dart';
import '../domain/map_models.dart';

part 'destination_search_controller.g.dart';

/// Debounced place search. Mapbox bills searches, so a request only goes out
/// once the user pauses typing with at least [minQueryLength] characters,
/// one session token per screen visit groups suggest and retrieve calls into
/// a single billed session, and suggestions already fetched in this visit
/// are reused (e.g. when backspacing to an earlier query).
@riverpod
class DestinationSearchController extends _$DestinationSearchController {
  static const minQueryLength = 3;
  static const typingPause = Duration(milliseconds: 450);

  final _sessionToken = const Uuid().v4();
  final _debouncer = Debouncer(typingPause);

  /// Suggestions by normalized query, for this screen visit only.
  final _cache = <String, List<PlaceSuggestion>>{};

  /// The query the list currently shows (or is loading), normalized.
  String? _shown;

  @override
  Future<List<PlaceSuggestion>> build(SearchPurpose purpose) {
    ref.onDispose(_debouncer.cancel);
    return Future.value(const []);
  }

  void search(String query) {
    final trimmed = query.trim();
    if (trimmed.length < minQueryLength) {
      _debouncer.cancel();
      _shown = null;
      state = const AsyncData([]);
      return;
    }
    final key = trimmed.toLowerCase();
    if (key == _shown) return _debouncer.cancel();
    if (_cache[key] case final cached?) {
      _debouncer.cancel();
      _shown = key;
      state = AsyncData(cached);
      return;
    }
    _debouncer.run(() async {
      _shown = key;
      state = const AsyncLoading();
      final result = await AsyncValue.guard(
        () => ref
            .read(placeSearchRepositoryProvider)
            .suggest(trimmed, sessionToken: _sessionToken, purpose: purpose, near: _near()),
      );
      if (!ref.mounted || _shown != key) return;
      // Failures aren't cached, so trying again asks Mapbox again.
      if (result case AsyncData(:final value)) _cache[key] = value;
      if (result.hasError) _shown = null;
      state = result;
    });
  }

  /// Asks again after a failure (the failed query isn't cached).
  void retry(String query) {
    _shown = null;
    search(query);
  }

  /// Biases results toward the rider; without it Mapbox ranks matches
  /// worldwide (e.g. a chain's branches in another country first).
  GeoPoint? _near() =>
      ref.read(myLocationControllerProvider).value?.position ?? ref.read(lastLocationStoreProvider).read();

  Future<Place> resolve(PlaceSuggestion suggestion) {
    return ref.read(placeSearchRepositoryProvider).retrieve(suggestion, sessionToken: _sessionToken, purpose: purpose);
  }
}
