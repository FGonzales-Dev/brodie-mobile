import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../auth/data/auth_repository.dart';
import '../data/profile_repository.dart';

part 'account_controller.g.dart';

/// Sign-out and account deletion. Both end the session, after which the
/// router sends the user to sign-in; failures land in [state].
@riverpod
class AccountController extends _$AccountController {
  @override
  FutureOr<void> build() {}

  Future<void> signOut() => _run(() => ref.read(authRepositoryProvider).signOut());

  Future<void> deleteAccount() => _run(() => ref.read(profileRepositoryProvider).deleteAccount());

  Future<void> _run(Future<void> Function() action) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(action);
  }
}
