import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../data/repositories/group_ride_repository.dart';
import '../../../domain/models/group_invite.dart';

part 'pending_invites_controller.g.dart';

@riverpod
class PendingInvitesController extends _$PendingInvitesController {
  @override
  FutureOr<List<GroupInvite>> build() {
    return ref.read(groupRideRepositoryProvider).getPendingInvites();
  }

  Future<void> accept(String groupId) async {
    await ref.read(groupRideRepositoryProvider).acceptInvite(groupId);
    await _refresh();
  }

  Future<void> decline(String groupId) async {
    await ref.read(groupRideRepositoryProvider).declineInvite(groupId);
    await _refresh();
  }

  Future<void> _refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => ref.read(groupRideRepositoryProvider).getPendingInvites());
  }
}
