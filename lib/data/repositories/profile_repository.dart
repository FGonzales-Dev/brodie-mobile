import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/models/profile.dart';

part 'profile_repository.g.dart';

class ProfileRepository {
  ProfileRepository(this._client);

  final SupabaseClient _client;

  Future<Profile> getProfile(String userId) async {
    final response = await _client.from('profiles').select().eq('id', userId).single();
    return Profile.fromJson(response);
  }

  Future<Profile> updateProfile({required String userId, required String displayName}) async {
    final response = await _client
        .from('profiles')
        .update({'display_name': displayName, 'updated_at': DateTime.now().toIso8601String()})
        .eq('id', userId)
        .select()
        .single();
    return Profile.fromJson(response);
  }

  Future<void> deleteAccount() {
    return _client.rpc('delete_own_account');
  }
}

@riverpod
ProfileRepository profileRepository(Ref ref) {
  return ProfileRepository(Supabase.instance.client);
}
