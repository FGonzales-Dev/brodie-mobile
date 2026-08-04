import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../data/repositories/profile_repository.dart';
import '../../../domain/models/profile.dart';

part 'profile_controller.g.dart';

@riverpod
class ProfileController extends _$ProfileController {
  @override
  FutureOr<Profile> build() {
    final userId = Supabase.instance.client.auth.currentUser!.id;
    return ref.read(profileRepositoryProvider).getProfile(userId);
  }

  Future<void> updateDisplayName(String displayName) async {
    final userId = Supabase.instance.client.auth.currentUser!.id;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() {
      return ref.read(profileRepositoryProvider).updateProfile(userId: userId, displayName: displayName);
    });
  }

  Future<void> deleteAccount() async {
    await ref.read(profileRepositoryProvider).deleteAccount();
  }
}
