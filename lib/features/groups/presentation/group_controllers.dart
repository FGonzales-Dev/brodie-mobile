import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/utils/debouncer.dart';
import '../../profile/data/profile_repository.dart';
import '../../profile/domain/profile.dart';
import '../application/group_providers.dart';
import '../data/group_repository.dart';
import '../domain/group_models.dart';

part 'group_controllers.g.dart';

@riverpod
class CreateGroupController extends _$CreateGroupController {
  @override
  FutureOr<void> build() {}

  /// Returns the new group, or null on failure (the error lands in [state]).
  Future<RideGroup?> create(String name) async {
    state = const AsyncLoading();
    RideGroup? group;
    state = await AsyncValue.guard(() async {
      group = await ref.read(groupRepositoryProvider).createGroup(name);
    });
    if (group != null) ref.invalidate(myGroupsProvider);
    return group;
  }
}

@riverpod
class GroupMembersController extends _$GroupMembersController {
  @override
  Future<List<GroupMember>> build(String groupId) => ref.watch(groupRepositoryProvider).fetchActiveMembers(groupId);

  Future<void> invite(String userId) async {
    await ref.read(groupRepositoryProvider).inviteMember(groupId: groupId, userId: userId);
    ref.invalidateSelf();
    await future;
  }
}

/// Debounced rider search by username prefix or full email address; needs at
/// least two characters.
@riverpod
class RiderSearchController extends _$RiderSearchController {
  static const _minQueryLength = 2;
  final _debouncer = Debouncer(const Duration(milliseconds: 300));

  @override
  Future<List<Profile>> build() {
    ref.onDispose(_debouncer.cancel);
    return Future.value(const []);
  }

  void search(String query) {
    if (query.trim().length < _minQueryLength) {
      _debouncer.cancel();
      state = const AsyncData([]);
      return;
    }
    state = const AsyncLoading();
    _debouncer.run(() async {
      state = await AsyncValue.guard(() => ref.read(profileRepositoryProvider).searchUsers(query.trim()));
    });
  }
}
