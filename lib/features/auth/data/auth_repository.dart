import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/di/core_providers.dart';
import '../../../core/errors/guard_remote.dart';
import '../domain/app_user.dart';
import '../domain/sign_up_outcome.dart';

part 'auth_repository.g.dart';

class AuthRepository {
  AuthRepository(this._auth);

  final GoTrueClient _auth;

  /// Emits the signed-in user, or null, on every auth state change.
  Stream<AppUser?> userChanges() => _auth.onAuthStateChange.map((state) => _toAppUser(state.session?.user));

  AppUser? get currentUser => _toAppUser(_auth.currentUser);

  Future<void> signIn({required String email, required String password}) {
    return guardRemote(() => _auth.signInWithPassword(email: email, password: password));
  }

  Future<SignUpOutcome> signUp({required String email, required String password}) {
    return guardRemote(() async {
      final response = await _auth.signUp(email: email, password: password);
      return response.session == null ? SignUpOutcome.needsEmailConfirmation : SignUpOutcome.signedIn;
    });
  }

  Future<void> sendPasswordReset(String email) => guardRemote(() => _auth.resetPasswordForEmail(email));

  Future<void> signOut() => guardRemote(() => _auth.signOut());

  static AppUser? _toAppUser(User? user) => user == null ? null : AppUser(id: user.id, email: user.email);
}

@Riverpod(keepAlive: true)
AuthRepository authRepository(Ref ref) => AuthRepository(ref.watch(supabaseClientProvider).auth);
