import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../../../core/design_system/design_system.dart';
import '../../../core/photos/photo_picker.dart';
import '../../../core/photos/photo_storage.dart';
import '../../../core/photos/user_avatar.dart';
import '../../../core/presentation/feedback.dart';
import '../../auth/application/session_providers.dart';
import '../application/my_profile_provider.dart';
import '../data/profile_repository.dart';
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
    final profile = ref.watch(myProfileProvider).value;
    final username = profile?.username;
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
                  _Identity(username: username, email: email, avatarPath: profile?.avatarPath),
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

class _Identity extends ConsumerStatefulWidget {
  const _Identity({required this.username, required this.email, required this.avatarPath});

  final String? username;
  final String email;
  final String? avatarPath;

  @override
  ConsumerState<_Identity> createState() => _IdentityState();
}

class _IdentityState extends ConsumerState<_Identity> {
  var _busy = false;

  Future<void> _changePhoto() async {
    final current = widget.avatarPath;
    final choice = await pickPhoto(
      context,
      title: 'Profile picture',
      bucket: PhotoBucket.avatars,
      canRemove: current != null,
    );
    if (choice == null || !mounted) return;
    setState(() => _busy = true);
    final profiles = ref.read(profileRepositoryProvider);
    await context.runWithFeedback(() async {
      switch (choice) {
        case PhotoPicked(:final jpeg):
          await profiles.setAvatar(jpeg, replacing: current);
        case PhotoRemoved():
          await profiles.removeAvatar(current!);
      }
      ref.invalidate(myProfileProvider);
      await ref.read(myProfileProvider.future);
    });
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final username = widget.username;
    final email = widget.email;
    final handle = username == null ? email : '@$username';
    return Row(
      children: [
        Semantics(
          button: true,
          label: widget.avatarPath == null ? 'Add a profile picture' : 'Change your profile picture',
          child: InkWell(
            onTap: _busy ? null : _changePhoto,
            borderRadius: BrodieSize.borderRadius,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                UserAvatar(name: username ?? email, avatarPath: widget.avatarPath, size: 64, highlighted: true),
                Positioned(
                  right: -4,
                  bottom: -4,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: colors.surfaceRaised,
                      shape: BoxShape.circle,
                      border: Border.all(color: colors.background, width: 2),
                    ),
                    child: _busy
                        ? const Padding(padding: EdgeInsets.all(4), child: CircularProgressIndicator(strokeWidth: 2))
                        : Icon(Icons.photo_camera, size: 13, color: colors.textPrimary),
                  ),
                ),
              ],
            ),
          ),
        ),
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
