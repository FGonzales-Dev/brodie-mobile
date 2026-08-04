import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/config/env.dart';
import '../../domain/models/retrieved_place.dart';
import '../../domain/models/search_suggestion.dart';

part 'search_repository.g.dart';

class SearchRepository {
  SearchRepository(this._client);

  final http.Client _client;

  static const _baseUrl = 'https://api.mapbox.com/search/searchbox/v1';

  Future<List<SearchSuggestion>> suggest({
    required String query,
    required String sessionToken,
    double? proximityLongitude,
    double? proximityLatitude,
  }) async {
    if (query.trim().isEmpty) return [];

    final params = {
      'q': query,
      'access_token': Env.mapboxAccessToken,
      'session_token': sessionToken,
      'language': 'en',
      'limit': '5',
      if (proximityLongitude != null && proximityLatitude != null)
        'proximity': '$proximityLongitude,$proximityLatitude',
    };
    final uri = Uri.parse('$_baseUrl/suggest').replace(queryParameters: params);
    final response = await _client.get(uri);
    if (response.statusCode != 200) {
      throw Exception('Search suggest failed: ${response.statusCode} ${response.body}');
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final suggestions = body['suggestions'] as List? ?? [];
    return suggestions.map((json) => SearchSuggestion.fromJson(json as Map<String, dynamic>)).toList();
  }

  Future<RetrievedPlace> retrieve({required String mapboxId, required String sessionToken}) async {
    final params = {
      'access_token': Env.mapboxAccessToken,
      'session_token': sessionToken,
    };
    final uri = Uri.parse('$_baseUrl/retrieve/$mapboxId').replace(queryParameters: params);
    final response = await _client.get(uri);
    if (response.statusCode != 200) {
      throw Exception('Search retrieve failed: ${response.statusCode} ${response.body}');
    }
    return RetrievedPlace.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }
}

@riverpod
SearchRepository searchRepository(Ref ref) => SearchRepository(http.Client());
