import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../domain/map_models.dart';
import 'mapbox_functions.dart';

part 'place_search_repository.g.dart';

/// Place search through the `mapbox-search` Edge Function. Suggest and
/// retrieve calls sharing a [sessionToken] count as one search session, which
/// is how Mapbox bills and how the function's daily quota counts.
class PlaceSearchRepository {
  PlaceSearchRepository(this._mapbox);

  final MapboxFunctions _mapbox;

  static const _function = 'mapbox-search';
  static const _limitMessage = "You've reached today's search limit. Your recent places still work.";

  Future<List<PlaceSuggestion>> suggest(String query, {required String sessionToken, GeoPoint? near}) async {
    if (query.trim().isEmpty) return const [];
    final json = await _mapbox.invoke(
      _function,
      {'action': 'suggest', 'q': query, 'session_token': sessionToken, if (near != null) 'proximity': lngLat(near)},
      notFoundMessage: 'No places found.',
      limitMessage: _limitMessage,
    );
    return suggestionsFromResponse(json);
  }

  Future<Place> retrieve(PlaceSuggestion suggestion, {required String sessionToken}) async {
    final json = await _mapbox.invoke(
      _function,
      {'action': 'retrieve', 'id': suggestion.id, 'session_token': sessionToken},
      notFoundMessage: 'That place is no longer available.',
      limitMessage: _limitMessage,
    );
    return placeFromResponse(json);
  }

  @visibleForTesting
  static List<PlaceSuggestion> suggestionsFromResponse(Map<String, dynamic> json) {
    return (json['suggestions'] as List)
        .cast<Map<String, dynamic>>()
        .map(
          (item) => PlaceSuggestion(
            id: item['id'] as String,
            name: item['name'] as String,
            address: item['address'] as String?,
          ),
        )
        .toList();
  }

  @visibleForTesting
  static Place placeFromResponse(Map<String, dynamic> json) => Place(
    name: json['name'] as String,
    address: json['address'] as String?,
    location: GeoPoint(latitude: (json['lat'] as num).toDouble(), longitude: (json['lng'] as num).toDouble()),
  );
}

@Riverpod(keepAlive: true)
PlaceSearchRepository placeSearchRepository(Ref ref) => PlaceSearchRepository(ref.watch(mapboxFunctionsProvider));
