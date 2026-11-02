import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/utils/debouncer.dart';
import '../../../core/utils/validators.dart';
import '../../profile/application/my_profile_provider.dart';
import '../../profile/data/profile_repository.dart';
import '../data/auth_repository.dart';
import '../domain/sign_up_outcome.dart';

part 'auth_controllers.freezed.dart';
part 'auth_controllers.g.dart';

/// Sign-in and password reset. Each action returns whether it succeeded;
/// failures land in [state] for the screen's error listener.
@riverpod
class SignInController extends _$SignInController {
  @override
  FutureOr<void> build() {}

  Future<bool> signIn({required String email, required String password}) {
    return _run(() => ref.read(authRepositoryProvider).signIn(email: email, password: password));
  }

  Future<bool> sendPasswordReset(String email) {
    return _run(() => ref.read(authRepositoryProvider).sendPasswordReset(email));
  }

  Future<bool> _run(Future<void> Function() action) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(action);
    return !state.hasError;
  }
}

@riverpod
class SignUpController extends _$SignUpController {
  @override
  FutureOr<void> build() {}

  /// Returns the outcome, or null on failure (the error lands in [state]).
  Future<SignUpOutcome?> signUp({required String email, required String password}) async {
    state = const AsyncLoading();
    SignUpOutcome? outcome;
    state = await AsyncValue.guard(() async {
      outcome = await ref.read(authRepositoryProvider).signUp(email: email, password: password);
    });
    return outcome;
  }
}

@freezed
abstract class UsernameState with _$UsernameState {
  const factory UsernameState({
    @Default(false) bool isChecking,
    bool? isAvailable,
    @Default(false) bool isSubmitting,
    String? errorMessage,
  }) = _UsernameState;
}

/// Live availability check (debounced) and submission for the username step.
/// On success the router moves on by itself once the profile reloads.
@riverpod
class UsernameController extends _$UsernameController {
  final _debouncer = Debouncer(const Duration(milliseconds: 400));

  @override
  UsernameState build() {
    ref.onDispose(_debouncer.cancel);
    return const UsernameState();
  }

  void checkAvailability(String username) {
    if (!Validators.isValidUsername(username)) {
      _debouncer.cancel();
      state = const UsernameState(errorMessage: Validators.usernameRule);
      return;
    }
    state = const UsernameState(isChecking: true);
    _debouncer.run(() async {
      try {
        final available = await ref.read(profileRepositoryProvider).isUsernameAvailable(username);
        state = UsernameState(isAvailable: available, errorMessage: available ? null : 'That username is taken.');
      } catch (error) {
        state = UsernameState(errorMessage: AppFailure.messageFor(error));
      }
    });
  }

  Future<void> submit(String username) async {
    state = state.copyWith(isSubmitting: true, errorMessage: null);
    try {
      await ref.read(profileRepositoryProvider).setUsername(username);
      ref.invalidate(myProfileProvider);
    } catch (error) {
      state = state.copyWith(isSubmitting: false, errorMessage: AppFailure.messageFor(error));
    }
  }
}
