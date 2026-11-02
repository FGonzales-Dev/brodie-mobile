import 'package:brodie/core/errors/app_failure.dart';
import 'package:brodie/features/map/data/mapbox_functions.dart';
import 'package:brodie/features/map/data/place_search_repository.dart';
import 'package:brodie/features/map/domain/map_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  Object failureFor(int status, [Object? details]) => MapboxFunctions.failureFor(
        FunctionException(status: status, details: details),
        notFoundMessage: 'not found message',
        limitMessage: 'limit message',
      );

  group('MapboxFunctions.failureFor', () {
    test("uses the caller's message when the function itself says not found", () {
      final failure = failureFor(404, {'error': 'no_route'});

      expect(failure, isA<NotFoundFailure>());
      expect((failure as AppFailure).message, 'not found message');
    });

    test('reports an undeployed function as unavailable, not as "not found"', () {
      final failure = failureFor(404, {'code': 'NOT_FOUND', 'message': 'Requested function was not found'});

      expect(failure, isA<UnknownFailure>());
      expect((failure as AppFailure).message, "This isn't available right now. Try again later.");
    });

    test('uses the caller\'s message for a daily limit', () {
      final failure = failureFor(429, {'error': 'rate_limited'});

      expect(failure, isA<RateLimitedFailure>());
      expect((failure as AppFailure).message, 'limit message');
    });

    test('leaves other statuses for guardRemote to map', () {
      expect(failureFor(502), isA<FunctionException>());
    });
  });

  test('lngLat puts longitude first, as GeoJSON does', () {
    expect(lngLat(const GeoPoint(latitude: 14.5, longitude: 120.9)), [120.9, 14.5]);
  });

  group('PlaceSearchRepository parses the mapbox-search function', () {
    test('suggestions', () {
      final suggestions = PlaceSearchRepository.suggestionsFromResponse({
        'suggestions': [
          {'id': 'dXJuOm1ieHBvaTo1', 'name': 'Jollibee Lucao', 'address': 'Dagupan City, Philippines'},
          {'id': 'dXJuOm1ieHBvaTo2', 'name': 'Jollibee', 'address': null},
        ],
      });

      expect(suggestions, [
        const PlaceSuggestion(id: 'dXJuOm1ieHBvaTo1', name: 'Jollibee Lucao', address: 'Dagupan City, Philippines'),
        const PlaceSuggestion(id: 'dXJuOm1ieHBvaTo2', name: 'Jollibee'),
      ]);
    });

    test('retrieved place', () {
      final place = PlaceSearchRepository.placeFromResponse({
        'name': 'Jollibee Lucao',
        'address': 'Dagupan City, Philippines',
        'lng': 120.3333,
        'lat': 16.0433,
      });

      expect(place.location, const GeoPoint(latitude: 16.0433, longitude: 120.3333));
      expect(place.name, 'Jollibee Lucao');
    });
  });
}
