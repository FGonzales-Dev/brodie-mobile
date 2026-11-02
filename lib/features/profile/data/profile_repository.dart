import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/di/core_providers.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/errors/guard_remote.dart';
import '../domain/profile.dart';

part 'profile_repository.g.dart';

class ProfileRepository {
  ProfileRepository(this._client);

  final SupabaseClient _client;

  Future<Profile> fetchMine() => guardRemote(() async {
        final userId = _client.auth.currentUser?.id ?? (throw const UnauthenticatedFailure());
        final row = await _client.from('profiles').select().eq('id', userId).single();
        return profileFromRow(row);
      });

  Future<bool> isUsernameAvailable(String username) => guardRemote(() async {
        final available = await _client.rpc('is_username_available', params: {'check_username': username});
        return available as bool;
      });

  Future<Profile> setUsername(String username) => guardRemote(() async {
        final row = await _client.rpc('set_username', params: {'new_username': username});
        return profileFromRow(row as Map<String, dynamic>);
      });

  Future<List<Profile>> searchUsers(String query) => guardRemote(() async {
        final rows = await _client.rpc('search_users', params: {'search_query': query});
        return (rows as List).cast<Map<String, dynamic>>().map(profileFromRow).toList();
      });

  /// Deletes the account server-side, then ends the local session.
  Future<void> deleteAccount() => guardRemote(() async {
        await _client.rpc('delete_own_account');
        await _client.auth.signOut();
      });

  static Profile profileFromRow(Map<String, dynamic> row) => Profile(
        id: row['id'] as String,
        username: row['username'] as String?,
        avatarUrl: row['avatar_url'] as String?,
      );
}

@Riverpod(keepAlive: true)
ProfileRepository profileRepository(Ref ref) => ProfileRepository(ref.watch(supabaseClientProvider));
