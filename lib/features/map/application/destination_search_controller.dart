import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';

import '../../../data/repositories/search_repository.dart';
import '../../../domain/models/retrieved_place.dart';
import '../../../domain/models/search_suggestion.dart';

part 'destination_search_controller.g.dart';

@riverpod
class DestinationSearchController extends _$DestinationSearchController {
  final _sessionToken = const Uuid().v4();
  Timer? _debounce;

  @override
  FutureOr<List<SearchSuggestion>> build() {
    ref.onDispose(() => _debounce?.cancel());
    return [];
  }

  void updateQuery(String query) {
    _debounce?.cancel();
    if (query.trim().isEmpty) {
      state = const AsyncData([]);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      state = const AsyncLoading();
      state = await AsyncValue.guard(() {
        return ref.read(searchRepositoryProvider).suggest(query: query, sessionToken: _sessionToken);
      });
    });
  }

  Future<RetrievedPlace> retrieve(SearchSuggestion suggestion) {
    return ref.read(searchRepositoryProvider).retrieve(mapboxId: suggestion.mapboxId, sessionToken: _sessionToken);
  }
}
