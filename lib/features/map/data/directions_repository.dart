import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../domain/map_models.dart';
import '../domain/polyline_codec.dart';
import 'mapbox_functions.dart';

part 'directions_repository.g.dart';

/// Routes come from the `mapbox-directions` Edge Function, which enforces
/// per-user and global daily limits so the app can't run up the bill.
class DirectionsRepository {
  DirectionsRepository(this._mapbox);

  final MapboxFunctions _mapbox;

  Future<RouteResult> fetchRoute({required GeoPoint from, required GeoPoint to}) async {
    final json = await _mapbox.invoke(
      'mapbox-directions',
      {
        'coordinates': [lngLat(from), lngLat(to)],
      },
      notFoundMessage: 'No route found to that destination.',
      limitMessage: "You've reached today's route limit. Try again tomorrow.",
    );
    return routeFromResponse(json);
  }

  @visibleForTesting
  static RouteResult routeFromResponse(Map<String, dynamic> json) {
    final encoded = json['polyline6'] as String;
    return RouteResult(
      path: PolylineCodec.decode(encoded),
      distanceMeters: (json['distance_m'] as num).toDouble(),
      duration: Duration(seconds: (json['duration_s'] as num).round()),
      encodedPolyline: encoded,
      maneuvers: [
        for (final maneuver in (json['maneuvers'] as List? ?? const []).cast<Map<String, dynamic>>())
          RouteManeuver(
            instruction: maneuver['instruction'] as String,
            type: maneuver['type'] as String,
            modifier: maneuver['modifier'] as String?,
            location: GeoPoint(
              latitude: (maneuver['lat'] as num).toDouble(),
              longitude: (maneuver['lng'] as num).toDouble(),
            ),
          ),
      ],
    );
  }
}

@Riverpod(keepAlive: true)
DirectionsRepository directionsRepository(Ref ref) => DirectionsRepository(ref.watch(mapboxFunctionsProvider));
