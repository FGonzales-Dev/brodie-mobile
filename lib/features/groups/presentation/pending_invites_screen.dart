import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design_system/design_system.dart';
import '../../../core/presentation/feedback.dart';
import '../application/group_providers.dart';
import '../domain/group_models.dart';

class PendingInvitesScreen extends ConsumerWidget {
  const PendingInvitesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: const BrodieAppBar(title: 'Invites'),
      body: AsyncValueView(
        value: ref.watch(pendingInvitesControllerProvider),
        onRetry: () => ref.invalidate(pendingInvitesControllerProvider),
        data: (invites) => invites.isEmpty
            ? const EmptyState(
                icon: Icons.mark_email_read_outlined,
                title: 'No pending invites',
                message: 'When a rider adds you to a group, it shows up here.',
              )
            : ListView.separated(
                padding: const EdgeInsets.all(BrodieSpace.md),
                itemCount: invites.length,
                separatorBuilder: (_, _) => const SizedBox(height: BrodieSpace.sm),
                itemBuilder: (context, index) => _InviteCard(invite: invites[index]),
              ),
      ),
    );
  }
}

class _InviteCard extends ConsumerWidget {
  const _InviteCard({required this.invite});

  final GroupInvite invite;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final controller = ref.read(pendingInvitesControllerProvider.notifier);
    return BrodieCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(invite.groupName.toUpperCase(), style: BrodieType.title.copyWith(color: colors.textPrimary)),
          if (invite.invitedBy != null)
            Text('Invited by @${invite.invitedBy}', style: BrodieType.caption.copyWith(color: colors.textSecondary)),
          const SizedBox(height: BrodieSpace.sm),
          Row(
            children: [
              Expanded(
                child: BrodieButton.secondary(
                  label: 'Decline',
                  compact: true,
                  onPressed: () => context.runWithFeedback(
                    () => controller.decline(invite.groupId),
                    successMessage: 'Invite declined',
                  ),
                ),
              ),
              const SizedBox(width: BrodieSpace.sm),
              Expanded(
                child: BrodieButton(
                  label: 'Join',
                  compact: true,
                  onPressed: () => context.runWithFeedback(
                    () => controller.accept(invite.groupId),
                    successMessage: 'You joined ${invite.groupName}',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
