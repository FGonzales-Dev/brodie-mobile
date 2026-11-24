import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../../../core/design_system/design_system.dart';
import '../../../core/presentation/feedback.dart';
import '../../../core/utils/text.dart';
import '../application/group_providers.dart';
import '../data/group_repository.dart';
import '../domain/group_models.dart';
import '../domain/invite_links.dart';

/// Where an invite link or code lands: the group's name and leader, and a
/// Join button. Opened from `https://<site>/join/<code>` or the code form.
class JoinGroupScreen extends ConsumerStatefulWidget {
  const JoinGroupScreen({super.key, required this.code});

  final String code;

  @override
  ConsumerState<JoinGroupScreen> createState() => _JoinGroupScreenState();
}

class _JoinGroupScreenState extends ConsumerState<JoinGroupScreen> {
  var _joining = false;

  String get _code => InviteLinks.normalize(widget.code);

  /// A link opened from outside the app may be the only screen on the
  /// stack, so leaving goes to the Groups tab rather than popping.
  void _leave() => context.canPop() ? context.pop() : context.go(Routes.groups);

  void _openGroup(String groupId) {
    final router = GoRouter.of(context);
    router.go(Routes.groups);
    router.push(Routes.group(groupId));
  }

  Future<void> _join(GroupInvitePreview preview) async {
    setState(() => _joining = true);
    String? groupId;
    final ok = await context.runWithFeedback(() async {
      groupId = await ref.read(groupRepositoryProvider).joinByInviteCode(_code);
    });
    if (!mounted) return;
    setState(() => _joining = false);
    if (!ok) return;
    final joined = groupId;
    if (joined == null) {
      // The leader reset the code between the preview and the tap.
      ref.invalidate(groupInvitePreviewProvider(_code));
      return;
    }
    ref
      ..invalidate(myGroupsProvider)
      ..invalidate(pendingInvitesControllerProvider);
    context.showMessage('You joined ${preview.name}');
    _openGroup(joined);
  }

  @override
  Widget build(BuildContext context) {
    final preview = ref.watch(groupInvitePreviewProvider(_code));
    return Scaffold(
      appBar: const BrodieAppBar(title: 'Join a group'),
      body: AsyncValueView(
        value: preview,
        onRetry: () => ref.invalidate(groupInvitePreviewProvider(_code)),
        data: (preview) => preview == null
            ? EmptyState(
                icon: Icons.link_off,
                title: 'Invite not found',
                message: "The code $_code doesn't match a group. The leader may have reset it; ask them for a new link.",
                action: BrodieButton.secondary(
                  label: 'Enter a code',
                  onPressed: () => context.pushReplacement(Routes.joinWithCode),
                ),
              )
            : _Preview(
                preview: preview,
                joining: _joining,
                onJoin: () => _join(preview),
                onOpen: () => _openGroup(preview.groupId),
                onNotNow: _leave,
              ),
      ),
    );
  }
}

class _Preview extends StatelessWidget {
  const _Preview({
    required this.preview,
    required this.joining,
    required this.onJoin,
    required this.onOpen,
    required this.onNotNow,
  });

  final GroupInvitePreview preview;
  final bool joining;
  final VoidCallback onJoin;
  final VoidCallback onOpen;
  final VoidCallback onNotNow;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final member = preview.myStatus == MemberStatus.joined;
    final leader = preview.leaderUsername;
    return ListView(
      padding: const EdgeInsets.all(BrodieSpace.md),
      children: [
        BrodieCard(
          highlighted: true,
          child: Row(
            children: [
              BrodieAvatar(name: preview.name, size: 56),
              const SizedBox(width: BrodieSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(preview.name.toUpperCase(), style: BrodieType.headline.copyWith(color: colors.textPrimary)),
                    Text(
                      [if (leader != null) 'Led by @$leader', countLabel(preview.memberCount, 'rider')].join(' · '),
                      style: BrodieType.body.copyWith(color: colors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: BrodieSpace.md),
        Text(
          member
              ? "You're already in this group."
              : 'Joining lets you see and join the group\'s rides. While you ride together, the group sees where you are.',
          style: BrodieType.body.copyWith(color: colors.textSecondary),
        ),
        const SizedBox(height: BrodieSpace.lg),
        if (member)
          BrodieButton(label: 'Open group', icon: Icons.groups, onPressed: onOpen)
        else ...[
          BrodieButton(label: 'Join group', icon: Icons.group_add_outlined, isLoading: joining, onPressed: onJoin),
          const SizedBox(height: BrodieSpace.sm),
          BrodieButton.secondary(label: 'Not now', onPressed: joining ? null : onNotNow),
        ],
      ],
    );
  }
}

/// Type or paste an invite code (or a whole invite link).
class JoinWithCodeScreen extends StatefulWidget {
  const JoinWithCodeScreen({super.key});

  @override
  State<JoinWithCodeScreen> createState() => _JoinWithCodeScreenState();
}

class _JoinWithCodeScreenState extends State<JoinWithCodeScreen> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final code = InviteLinks.codeFrom(_controller.text);
    if (code == null) {
      setState(() => _error = 'Enter the code from your invite, like 7A879D.');
      return;
    }
    context.pushReplacement(Routes.join(code));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const BrodieAppBar(title: 'Join with code'),
      body: ListView(
        padding: const EdgeInsets.all(BrodieSpace.md),
        children: [
          Text(
            "Ask your group's leader for its invite code, or paste the invite link they sent.",
            style: BrodieType.body.copyWith(color: context.colors.textSecondary),
          ),
          const SizedBox(height: BrodieSpace.md),
          BrodieTextField(
            controller: _controller,
            label: 'Invite code',
            hint: '7A879D',
            icon: Icons.key,
            errorText: _error,
            autofocus: true,
            keyboardType: TextInputType.visiblePassword,
            textInputAction: TextInputAction.go,
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: BrodieSpace.md),
          BrodieButton(label: 'Find group', icon: Icons.search, onPressed: _submit),
        ],
      ),
    );
  }
}
