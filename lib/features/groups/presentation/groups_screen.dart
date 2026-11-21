import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../../../core/design_system/design_system.dart';
import '../../../core/utils/text.dart';
import '../application/group_providers.dart';
import '../domain/group_models.dart';

class GroupsScreen extends ConsumerWidget {
  const GroupsScreen({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    ref
      ..invalidate(myGroupsProvider)
      ..invalidate(pendingInvitesControllerProvider);
    await ref.read(myGroupsProvider.future);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invites = ref.watch(pendingInvitesControllerProvider).value ?? const [];

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ScreenHeader(
              title: 'Groups',
              trailing: BrodieIconButton(
                icon: Icons.mail_outline,
                tooltip: 'Pending invites',
                badgeCount: invites.length,
                onPressed: () => context.push(Routes.pendingInvites),
              ),
            ),
            Expanded(
              child: AsyncValueView(
                value: ref.watch(myGroupsProvider),
                onRetry: () => _refresh(ref),
                data: (groups) => RefreshIndicator(
                  onRefresh: () => _refresh(ref),
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: BrodieSpace.md),
                    children: [
                      if (invites.isNotEmpty) _InvitesCard(invites: invites),
                      if (groups.isEmpty)
                        const EmptyState(
                          icon: Icons.groups_outlined,
                          title: 'No groups yet',
                          message: 'Create a group, share the code, and ride together.',
                        )
                      else ...[
                        const SectionLabel('Your groups'),
                        BrodieListGroup(children: [for (final group in groups) _GroupTile(group: group)]),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(BrodieSpace.md),
              child: BrodieButton(
                label: 'New group ride',
                icon: Icons.add,
                onPressed: () => context.push(Routes.createGroup),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InvitesCard extends StatelessWidget {
  const _InvitesCard({required this.invites});

  final List<GroupInvite> invites;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return BrodieCard(
      highlighted: true,
      onTap: () => context.push(Routes.pendingInvites),
      child: Row(
        children: [
          const IconTile(icon: Icons.mail_outline),
          const SizedBox(width: BrodieSpace.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(countLabel(invites.length, 'invite'), style: BrodieType.bodyStrong.copyWith(color: colors.textPrimary)),
                Text(
                  invites.map((invite) => invite.groupName).join(', '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: BrodieType.caption.copyWith(color: colors.textSecondary),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: colors.textSecondary),
        ],
      ),
    );
  }
}

class _GroupTile extends StatelessWidget {
  const _GroupTile({required this.group});

  final RideGroup group;

  @override
  Widget build(BuildContext context) {
    return BrodieListTile(
      leading: BrodieAvatar(name: group.name),
      title: group.name,
      subtitle: [
        countLabel(group.memberCount, 'rider'),
        ?switch (group.openTripStatus) {
          TripStatus.planned => 'Ride planned',
          TripStatus.active => 'Riding now',
          _ => null,
        },
        'code ${group.inviteCode}',
      ].join(' · '),
      onTap: () => context.push(Routes.group(group.id)),
    );
  }
}
