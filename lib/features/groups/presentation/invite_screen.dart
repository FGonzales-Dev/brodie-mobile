import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design_system/design_system.dart';
import '../../../core/presentation/feedback.dart';
import '../../profile/domain/profile.dart';
import '../application/group_providers.dart';
import '../domain/group_models.dart';
import 'group_controllers.dart';

/// Share a group's code and invite riders by username. Loads the group by
/// id, so it also works from a deep link.
class InviteScreen extends ConsumerWidget {
  const InviteScreen({super.key, required this.groupId});

  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final group = ref.watch(groupByIdProvider(groupId));
    return Scaffold(
      appBar: BrodieAppBar(title: group.value?.name ?? 'Invite riders'),
      body: AsyncValueView(
        value: group,
        onRetry: () => ref.invalidate(myGroupsProvider),
        data: (group) => ListView(
          padding: const EdgeInsets.all(BrodieSpace.md),
          children: [
            _InviteCodeCard(code: group.inviteCode),
            const SectionLabel('Invite by username or email'),
            _RiderSearch(groupId: groupId),
            const SectionLabel('Members'),
            _MemberList(groupId: groupId),
          ],
        ),
      ),
    );
  }
}

class _InviteCodeCard extends StatelessWidget {
  const _InviteCodeCard({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return BrodieCard(
      highlighted: true,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('INVITE CODE', style: BrodieType.label.copyWith(color: colors.textSecondary)),
                Text(code, style: BrodieType.stat.copyWith(color: colors.textPrimary, fontSize: 36, letterSpacing: 4)),
              ],
            ),
          ),
          BrodieIconButton(
            icon: Icons.copy,
            tooltip: 'Copy code',
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: code));
              if (context.mounted) context.showMessage('Invite code copied');
            },
          ),
        ],
      ),
    );
  }
}

class _RiderSearch extends ConsumerStatefulWidget {
  const _RiderSearch({required this.groupId});

  final String groupId;

  @override
  ConsumerState<_RiderSearch> createState() => _RiderSearchState();
}

class _RiderSearchState extends ConsumerState<_RiderSearch> {
  final _invited = <String>{};
  var _query = '';

  void _onQueryChanged(String value) {
    setState(() => _query = value.trim());
    ref.read(riderSearchControllerProvider.notifier).search(value);
  }

  Future<void> _invite(Profile rider) async {
    final invited = await context.runWithFeedback(
      () => ref.read(groupMembersControllerProvider(widget.groupId).notifier).invite(rider.id),
      successMessage: 'Invited @${rider.username}. Waiting for them to accept.',
    );
    if (invited && mounted) setState(() => _invited.add(rider.id));
  }

  @override
  Widget build(BuildContext context) {
    final results = ref.watch(riderSearchControllerProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BrodieTextField(
          hint: 'Username or email',
          icon: Icons.search,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.search,
          onChanged: _onQueryChanged,
        ),
        const SizedBox(height: BrodieSpace.xs),
        AsyncValueView(
          value: results,
          data: (riders) => riders.isEmpty
              ? _NoRidersHint(query: _query)
              : BrodieListGroup(
                  children: [
                    for (final rider in riders)
                      BrodieListTile(
                        leading: BrodieAvatar(name: rider.username ?? '?'),
                        title: '@${rider.username}',
                        trailing: SizedBox(
                          width: 110,
                          child: BrodieButton(
                            label: _invited.contains(rider.id) ? 'Invited' : 'Invite',
                            compact: true,
                            onPressed: _invited.contains(rider.id) ? null : () => _invite(rider),
                          ),
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _MemberList extends ConsumerWidget {
  const _MemberList({required this.groupId});

  final String groupId;

  static String _statusLabel(MemberStatus status) => switch (status) {
        MemberStatus.pending => 'Invited',
        MemberStatus.joined => 'Joined',
        MemberStatus.fellBehind => 'Fell behind',
        MemberStatus.left => 'Left',
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    return AsyncValueView(
      value: ref.watch(groupMembersControllerProvider(groupId)),
      onRetry: () => ref.invalidate(groupMembersControllerProvider(groupId)),
      data: (members) => BrodieListGroup(
        children: [
          for (final member in members)
            BrodieListTile(
              leading: BrodieAvatar(name: member.username ?? '?'),
              title: '@${member.username ?? 'unknown'}',
              subtitle: _statusLabel(member.status),
              trailing: member.role == GroupRole.leader
                  ? Container(
                      padding: const EdgeInsets.symmetric(horizontal: BrodieSpace.xs, vertical: 2),
                      color: colors.accent,
                      child: Text('LEAD', style: BrodieType.navLabel.copyWith(color: colors.onAccent)),
                    )
                  : null,
            ),
        ],
      ),
    );
  }
}

/// Explains an empty search. Emails only match in full (see `search_users`
/// in brodie-supabase), so say so when the query looks like one.
class _NoRidersHint extends StatelessWidget {
  const _NoRidersHint({required this.query});

  final String query;

  @override
  Widget build(BuildContext context) {
    if (query.length < 2) return const SizedBox.shrink();
    final message = query.contains('@')
        ? 'No rider with that email. Type their full email address.'
        : 'No riders found. You can also search by their full email address.';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: BrodieSpace.xs),
      child: Text(message, style: BrodieType.caption.copyWith(color: context.colors.textSecondary)),
    );
  }
}
