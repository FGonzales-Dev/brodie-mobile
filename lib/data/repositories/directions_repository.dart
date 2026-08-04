import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/config/env.dart';
import '../../domain/models/route_result.dart';

part 'directions_repository.g.dart';

class DirectionsRepository {
  DirectionsRepository(this._client);

  final http.Client _client;

  static const _baseUrl = 'https://api.mapbox.com/directions/v5/mapbox/driving';

  Future<RouteResult> getRoute({
    required double originLongitude,
    required double originLatitude,
    required double destinationLongitude,
    required double destinationLatitude,
  }) async {
    final coordinates = '$originLongitude,$originLatitude;$destinationLongitude,$destinationLatitude';
    final params = {
      'geometries': 'geojson',
      'overview': 'full',
      'access_token': Env.mapboxAccessToken,
    };
    final uri = Uri.parse('$_baseUrl/$coordinates').replace(queryParameters: params);
    final response = await _client.get(uri);
    if (response.statusCode != 200) {
      throw Exception('Directions request failed: ${response.statusCode} ${response.body}');
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final routes = body['routes'] as List? ?? [];
    if (routes.isEmpty) {
      throw Exception('No route found between the given points');
    }
    return RouteResult.fromJson(body);
  }
}

@riverpod
DirectionsRepository directionsRepository(Ref ref) => DirectionsRepository(http.Client());
