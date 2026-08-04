import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../data/repositories/profile_repository.dart';
import '../../../domain/models/profile.dart';

part 'user_search_controller.g.dart';

@riverpod
class UserSearchController extends _$UserSearchController {
  Timer? _debounce;

  @override
  FutureOr<List<Profile>> build() {
    ref.onDispose(() => _debounce?.cancel());
    return [];
  }

  void updateQuery(String query) {
    _debounce?.cancel();
    if (query.trim().length < 2) {
      state = const AsyncData([]);
      return;
    }
    state = const AsyncLoading();
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      state = await AsyncValue.guard(() => ref.read(profileRepositoryProvider).searchUsers(query));
    });
  }
}
