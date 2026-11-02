import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../../../core/design_system/design_system.dart';
import '../../../core/presentation/feedback.dart';
import '../../auth/application/session_providers.dart';
import '../application/my_profile_provider.dart';
import 'account_controller.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  Future<void> _confirmDeleteAccount(BuildContext context, WidgetRef ref) async {
    final confirmed = await showBrodieConfirmDialog(
      context,
      title: 'Delete account?',
      message: 'This permanently deletes your profile, vehicles, ride history and group ride data.',
      confirmLabel: 'Delete',
    );
    if (confirmed) await ref.read(accountControllerProvider.notifier).deleteAccount();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.showErrorsOf(accountControllerProvider, context);
    final username = ref.watch(myProfileProvider).value?.username;
    final email = ref.watch(currentUserProvider)?.email ?? '';
    final isBusy = ref.watch(accountControllerProvider).isLoading;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: BrodieSpace.lg),
          children: [
            const ScreenHeader(title: 'Profile'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: BrodieSpace.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Identity(username: username, email: email),
                  const SectionLabel('Garage & safety'),
                  BrodieListGroup(
                    children: [
                      BrodieListTile(
                        leading: const IconTile(icon: Icons.two_wheeler),
                        title: 'Vehicles',
                        onTap: () => context.push(Routes.vehicles),
                      ),
                      BrodieListTile(
                        leading: const IconTile(icon: Icons.health_and_safety_outlined),
                        title: 'Emergency contacts',
                        subtitle: 'Alerted when you trigger an SOS',
                        onTap: () => context.push(Routes.emergencyContacts),
                      ),
                    ],
                  ),
                  const SectionLabel('App'),
                  BrodieListGroup(
                    children: [
                      BrodieListTile(
                        leading: const IconTile(icon: Icons.tune),
                        title: 'Settings',
                        subtitle: 'Theme, units, location',
                        onTap: () => context.push(Routes.settings),
                      ),
                      BrodieListTile(
                        leading: const IconTile(icon: Icons.data_usage),
                        title: 'Usage & limits',
                        subtitle: 'Route previews and searches left today',
                        onTap: () => context.push(Routes.usage),
                      ),
                      BrodieListTile(
                        leading: const IconTile(icon: Icons.privacy_tip_outlined),
                        title: 'Privacy policy',
                        onTap: () => context.push(Routes.privacy),
                      ),
                      BrodieListTile(
                        leading: const IconTile(icon: Icons.description_outlined),
                        title: 'Terms',
                        onTap: () => context.push(Routes.terms),
                      ),
                      BrodieListTile(
                        leading: const IconTile(icon: Icons.info_outline),
                        title: 'About',
                        onTap: () => context.push(Routes.about),
                      ),
                    ],
                  ),
                  const SectionLabel('Account'),
                  BrodieListGroup(
                    children: [
                      BrodieListTile(
                        leading: const IconTile(icon: Icons.logout),
                        title: 'Sign out',
                        onTap: isBusy ? null : () => ref.read(accountControllerProvider.notifier).signOut(),
                      ),
                      BrodieListTile(
                        leading: IconTile(icon: Icons.delete_forever_outlined, color: context.colors.danger),
                        title: 'Delete account',
                        destructive: true,
                        onTap: isBusy ? null : () => _confirmDeleteAccount(context, ref),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Identity extends StatelessWidget {
  const _Identity({required this.username, required this.email});

  final String? username;
  final String email;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final handle = username == null ? email : '@$username';
    return Row(
      children: [
        BrodieAvatar(name: username ?? email, size: 64, highlighted: true),
        const SizedBox(width: BrodieSpace.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Usernames are shown as typed, never uppercased.
              Text(handle, style: BrodieType.headline.copyWith(color: colors.textPrimary, fontSize: 28)),
              if (username != null) Text(email, style: BrodieType.body.copyWith(color: colors.textSecondary)),
            ],
          ),
        ),
      ],
    );
  }
}
