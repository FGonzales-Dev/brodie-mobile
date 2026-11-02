import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/auth_repository.dart';
import '../domain/app_user.dart';

part 'session_providers.g.dart';

@Riverpod(keepAlive: true)
Stream<AppUser?> authUserChanges(Ref ref) => ref.watch(authRepositoryProvider).userChanges();

/// The signed-in user, or null. Rebuilds on every sign-in and sign-out, which
/// is what drives the router's redirects.
@Riverpod(keepAlive: true)
AppUser? currentUser(Ref ref) {
  ref.watch(authUserChangesProvider);
  return ref.watch(authRepositoryProvider).currentUser;
}
