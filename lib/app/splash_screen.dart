import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/design_system/design_system.dart';
import '../features/profile/application/my_profile_provider.dart';
import '../features/profile/presentation/account_controller.dart';

/// Shown while the signed-in user's profile loads, so the username step
/// doesn't flash before the router knows where they belong. If loading
/// fails, offers a retry or a way out.
class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(myProfileProvider);

    return Scaffold(
      body: SafeArea(
        child: profile.hasError && !profile.isLoading
            ? EmptyState(
                icon: Icons.cloud_off_outlined,
                title: "Couldn't load your profile",
                message: 'Check your connection and try again.',
                action: Column(
                  children: [
                    BrodieButton(label: 'Try again', onPressed: () => ref.invalidate(myProfileProvider)),
                    TextButton(
                      onPressed: () => ref.read(accountControllerProvider.notifier).signOut(),
                      child: const Text('Sign out'),
                    ),
                  ],
                ),
              )
            : const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    BrandMark(size: 72),
                    SizedBox(height: BrodieSpace.lg),
                    SizedBox.square(dimension: 24, child: CircularProgressIndicator(strokeWidth: 2.5)),
                  ],
                ),
              ),
      ),
    );
  }
}
