import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/router/profile_gate.dart';
import '../../../data/repositories/profile_repository.dart';
import '../../profile/application/profile_controller.dart';

part 'username_selection_controller.g.dart';

final _usernamePattern = RegExp(r'^[a-z0-9_]{3,20}$');

class UsernameSelectionState {
  const UsernameSelectionState({
    this.isChecking = false,
    this.isAvailable,
    this.isSubmitting = false,
    this.errorMessage,
  });

  final bool isChecking;
  final bool? isAvailable;
  final bool isSubmitting;
  final String? errorMessage;
}

@riverpod
class UsernameSelectionController extends _$UsernameSelectionController {
  Timer? _debounce;

  @override
  UsernameSelectionState build() {
    ref.onDispose(() => _debounce?.cancel());
    return const UsernameSelectionState();
  }

  void checkAvailability(String username) {
    _debounce?.cancel();

    if (!_usernamePattern.hasMatch(username)) {
      state = const UsernameSelectionState(
        errorMessage: '3-20 characters: lowercase letters, numbers, and underscores only.',
      );
      return;
    }

    state = const UsernameSelectionState(isChecking: true);
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      try {
        final available = await ref.read(profileRepositoryProvider).isUsernameAvailable(username);
        state = UsernameSelectionState(isAvailable: available);
      } catch (_) {
        state = const UsernameSelectionState(errorMessage: 'Could not check availability. Try again.');
      }
    });
  }

  Future<bool> submit(String username) async {
    state = UsernameSelectionState(isAvailable: state.isAvailable, isSubmitting: true);
    try {
      await ref.read(profileRepositoryProvider).setUsername(username);
      ref.invalidate(profileControllerProvider);
      ProfileGate.instance.markHasUsername();
      state = UsernameSelectionState(isAvailable: state.isAvailable);
      return true;
    } on PostgrestException catch (e) {
      state = UsernameSelectionState(isAvailable: state.isAvailable, errorMessage: e.message);
      return false;
    } catch (_) {
      state = UsernameSelectionState(
        isAvailable: state.isAvailable,
        errorMessage: 'Something went wrong. Please try again.',
      );
      return false;
    }
  }
}
