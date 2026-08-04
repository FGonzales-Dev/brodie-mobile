import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../data/repositories/group_ride_repository.dart';
import '../../../domain/models/group_member.dart';

part 'group_members_controller.g.dart';

@riverpod
class GroupMembersController extends _$GroupMembersController {
  @override
  FutureOr<List<GroupMember>> build(String groupId) {
    return ref.read(groupRideRepositoryProvider).getActiveMembers(groupId);
  }

  Future<void> addMember(String userId) async {
    await ref.read(groupRideRepositoryProvider).addMember(groupId: groupId, userId: userId);
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => ref.read(groupRideRepositoryProvider).getActiveMembers(groupId));
  }
}
