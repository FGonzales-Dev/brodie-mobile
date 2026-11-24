import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/errors/app_failure.dart';
import '../data/group_repository.dart';
import '../domain/group_models.dart';

part 'group_providers.g.dart';

/// Groups the user has joined; shared by the groups list and invite screens.
@riverpod
Future<List<RideGroup>> myGroups(Ref ref) => ref.watch(groupRepositoryProvider).fetchMyGroups();

@riverpod
Future<RideGroup> groupById(Ref ref, String groupId) async {
  final groups = await ref.watch(myGroupsProvider.future);
  return groups.firstWhere(
    (group) => group.id == groupId,
    orElse: () => throw const NotFoundFailure('That group no longer exists.'),
  );
}

/// Invites waiting for the user. Read by the Groups tab badge and the
/// invites screen, which also accepts or declines them.
@riverpod
class PendingInvitesController extends _$PendingInvitesController {
  @override
  Future<List<GroupInvite>> build() => ref.watch(groupRepositoryProvider).fetchPendingInvites();

  Future<void> accept(String groupId) async {
    await ref.read(groupRepositoryProvider).acceptInvite(groupId);
    ref.invalidate(myGroupsProvider);
    await _reload();
  }

  Future<void> decline(String groupId) async {
    await ref.read(groupRepositoryProvider).declineInvite(groupId);
    await _reload();
  }

  Future<void> _reload() async {
    ref.invalidateSelf();
    await future;
  }
}

/// The group behind an invite code, for the join screen; null when the code
/// matches none.
@riverpod
Future<GroupInvitePreview?> groupInvitePreview(Ref ref, String code) {
  return ref.watch(groupRepositoryProvider).fetchInvitePreview(code);
}
