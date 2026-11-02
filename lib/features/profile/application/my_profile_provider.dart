import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../auth/application/session_providers.dart';
import '../data/profile_repository.dart';
import '../domain/profile.dart';

part 'my_profile_provider.g.dart';

/// The signed-in user's profile, or null when signed out. Single source for
/// both the profile screen and the router's "has a username" gate.
@Riverpod(keepAlive: true)
Future<Profile?> myProfile(Ref ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;
  return ref.watch(profileRepositoryProvider).fetchMine();
}
