import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/design_system/design_system.dart';
import '../../../core/photos/user_avatar.dart';
import '../../../core/presentation/feedback.dart';
import '../../auth/application/session_providers.dart';
import '../../profile/domain/profile.dart';
import '../application/group_providers.dart';
import '../data/group_repository.dart';
import '../domain/group_models.dart';
import '../domain/invite_links.dart';
import 'group_controllers.dart';

/// Share a group's invite link, code or QR code, and invite riders by
/// username. Loads the group by id, so it also works from a deep link.
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
            _InviteLinkCard(group: group),
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

/// The group's invite link and code: share, copy, show as a QR code to scan
/// in person, and (leader only) reset so old links stop working.
class _InviteLinkCard extends ConsumerStatefulWidget {
  const _InviteLinkCard({required this.group});

  final RideGroup group;

  @override
  ConsumerState<_InviteLinkCard> createState() => _InviteLinkCardState();
}

class _InviteLinkCardState extends ConsumerState<_InviteLinkCard> {
  var _showQr = false;
  var _resetting = false;

  Uri get _link => InviteLinks.forCode(widget.group.inviteCode);

  Future<void> _share() async {
    final box = context.findRenderObject() as RenderBox?;
    await SharePlus.instance.share(
      ShareParams(
        text: 'Join ${widget.group.name} on Brodie and ride with us: $_link',
        subject: 'Join ${widget.group.name} on Brodie',
        // iPad needs to know where the share sheet points from.
        sharePositionOrigin: box == null ? null : box.localToGlobal(Offset.zero) & box.size,
      ),
    );
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: _link.toString()));
    if (mounted) context.showMessage('Invite link copied');
  }

  Future<void> _reset() async {
    final confirmed = await showBrodieConfirmDialog(
      context,
      title: 'Reset invite code?',
      message: 'Links and codes you already shared stop working. Riders already in the group stay in it.',
      confirmLabel: 'Reset',
    );
    if (!confirmed || !mounted) return;
    setState(() => _resetting = true);
    await context.runWithFeedback(() async {
      await ref.read(groupRepositoryProvider).resetInviteCode(widget.group.id);
      ref.invalidate(myGroupsProvider);
      await ref.read(myGroupsProvider.future);
    }, successMessage: 'New invite code ready');
    if (mounted) setState(() => _resetting = false);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isLeader = ref.watch(currentUserProvider)?.id == widget.group.leaderId;
    return BrodieCard(
      highlighted: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('INVITE CODE', style: BrodieType.label.copyWith(color: colors.textSecondary)),
          Text(
            widget.group.inviteCode,
            style: BrodieType.stat.copyWith(color: colors.textPrimary, fontSize: 36, letterSpacing: 4),
          ),
          const SizedBox(height: BrodieSpace.xxs),
          Text(
            _link.toString(),
            style: BrodieType.caption.copyWith(color: colors.textSecondary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (_showQr) ...[
            const SizedBox(height: BrodieSpace.md),
            Center(
              child: Container(
                padding: const EdgeInsets.all(BrodieSpace.sm),
                // QR codes need a light background to scan reliably.
                color: const Color(0xFFFFFFFF),
                child: QrImageView(
                  data: _link.toString(),
                  size: 200,
                  semanticsLabel: 'QR code for the invite link',
                  eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Color(0xFF121417)),
                  dataModuleStyle: const QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,
                    color: Color(0xFF121417),
                  ),
                ),
              ),
            ),
            const SizedBox(height: BrodieSpace.xs),
            Text(
              'Scan with the phone camera to open the invite.',
              textAlign: TextAlign.center,
              style: BrodieType.caption.copyWith(color: colors.textSecondary),
            ),
          ],
          const SizedBox(height: BrodieSpace.md),
          BrodieButton(label: 'Share invite link', icon: Icons.ios_share, onPressed: _share),
          const SizedBox(height: BrodieSpace.xs),
          Row(
            children: [
              Expanded(
                child: BrodieButton.secondary(label: 'Copy link', icon: Icons.copy, compact: true, onPressed: _copy),
              ),
              const SizedBox(width: BrodieSpace.xs),
              Expanded(
                child: BrodieButton.secondary(
                  label: _showQr ? 'Hide QR' : 'QR code',
                  icon: Icons.qr_code_2,
                  compact: true,
                  onPressed: () => setState(() => _showQr = !_showQr),
                ),
              ),
            ],
          ),
          if (isLeader) ...[
            const SizedBox(height: BrodieSpace.xs),
            BrodieButton.secondary(
              label: 'Reset code',
              icon: Icons.refresh,
              compact: true,
              isLoading: _resetting,
              onPressed: _reset,
            ),
          ],
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
                        leading: UserAvatar(name: rider.username ?? '?', avatarPath: rider.avatarPath),
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
              leading: UserAvatar(name: member.username ?? '?', avatarPath: member.avatarPath),
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
