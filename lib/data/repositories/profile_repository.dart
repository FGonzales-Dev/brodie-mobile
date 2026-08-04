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

  Future<void> deleteAccount() {
    return _client.rpc('delete_own_account');
  }

  Future<bool> isUsernameAvailable(String username) async {
    final response = await _client.rpc('is_username_available', params: {'check_username': username});
    return response as bool;
  }

  Future<Profile> setUsername(String username) async {
    final response = await _client.rpc('set_username', params: {'new_username': username});
    return Profile.fromJson(response as Map<String, dynamic>);
  }

  Future<List<Profile>> searchUsers(String query) async {
    final response = await _client.rpc('search_users', params: {'search_query': query});
    return (response as List).map((row) => Profile.fromJson(row as Map<String, dynamic>)).toList();
  }
}

@riverpod
ProfileRepository profileRepository(Ref ref) {
  return ProfileRepository(Supabase.instance.client);
}
