import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/di/core_providers.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/errors/guard_remote.dart';
import '../../../core/photos/photo_storage.dart';
import '../domain/profile.dart';

part 'profile_repository.g.dart';

class ProfileRepository {
  ProfileRepository(this._client, this._photos);

  final SupabaseClient _client;
  final PhotoStorage _photos;

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

  /// Uploads [jpeg] as the profile picture, then removes the old one.
  Future<void> setAvatar(Uint8List jpeg, {String? replacing}) =>
      _photos.replace(PhotoBucket.avatars, jpeg, save: _setAvatarPath, replaces: replacing);

  Future<void> removeAvatar(String path) =>
      _photos.remove(PhotoBucket.avatars, path, clear: () => _setAvatarPath(null));

  Future<void> _setAvatarPath(String? path) => guardRemote(() async {
    final userId = _client.auth.currentUser?.id ?? (throw const UnauthenticatedFailure());
    await _client.from('profiles').update({'avatar_path': path}).eq('id', userId);
  });

  /// Deletes the rider's photos and the account server-side, then ends the
  /// local session.
  Future<void> deleteAccount() => guardRemote(() async {
    // Files aren't removed with the account's rows, so delete them first.
    await _photos.deleteAllMine();
    await _client.rpc('delete_own_account');
    await _client.auth.signOut();
  });

  static Profile profileFromRow(Map<String, dynamic> row) =>
      Profile(id: row['id'] as String, username: row['username'] as String?, avatarPath: row['avatar_path'] as String?);
}

@Riverpod(keepAlive: true)
ProfileRepository profileRepository(Ref ref) =>
    ProfileRepository(ref.watch(supabaseClientProvider), ref.watch(photoStorageProvider));
