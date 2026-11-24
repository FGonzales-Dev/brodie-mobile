import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/di/core_providers.dart';
import '../../auth/application/session_providers.dart';

part 'onboarding_store.g.dart';

/// Whether each account has been through onboarding on this phone. Kept on
/// the device: seeing the intro again on a new phone is harmless.
class OnboardingStore {
  OnboardingStore(this._prefs);

  final SharedPreferences _prefs;

  static String _key(String userId) => 'onboarding.done.$userId';

  bool isDone(String userId) => _prefs.getBool(_key(userId)) ?? false;

  Future<void> markDone(String userId) => _prefs.setBool(_key(userId), true);
}

@Riverpod(keepAlive: true)
OnboardingStore onboardingStore(Ref ref) => OnboardingStore(ref.watch(sharedPreferencesProvider));

/// Whether the signed-in rider has finished or skipped onboarding. The
/// router sends them through it once, after they pick a username.
@Riverpod(keepAlive: true)
class OnboardingDone extends _$OnboardingDone {
  @override
  bool build() {
    final userId = ref.watch(currentUserProvider)?.id;
    return userId != null && ref.watch(onboardingStoreProvider).isDone(userId);
  }

  Future<void> complete() async {
    final userId = ref.read(currentUserProvider)?.id;
    if (userId == null) return;
    await ref.read(onboardingStoreProvider).markDone(userId);
    state = true;
  }
}
