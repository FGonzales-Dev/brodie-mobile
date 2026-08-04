import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/profile.dart';
import 'application/group_members_controller.dart';
import 'application/user_search_controller.dart';

class InviteScreen extends ConsumerStatefulWidget {
  const InviteScreen({super.key, required this.groupId, required this.inviteCode});

  final String groupId;
  final String inviteCode;

  @override
  ConsumerState<InviteScreen> createState() => _InviteScreenState();
}

class _InviteScreenState extends ConsumerState<InviteScreen> {
  final _searchController = TextEditingController();
  final _invitedUserIds = <String>{};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _addMember(Profile user) async {
    try {
      await ref.read(groupMembersControllerProvider(widget.groupId).notifier).addMember(user.id);
      if (mounted) {
        setState(() => _invitedUserIds.add(user.id));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Invited @${user.username} — waiting for them to accept.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not invite @${user.username}: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final searchResultsAsync = ref.watch(userSearchControllerProvider);
    final membersAsync = ref.watch(groupMembersControllerProvider(widget.groupId));

    return Scaffold(
      appBar: AppBar(title: const Text('Invite Riders')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Invite code', style: theme.textTheme.labelMedium),
                        Text(widget.inviteCode, style: theme.textTheme.headlineSmall),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy_outlined),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: widget.inviteCode));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Invite code copied.')),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text('Search by username', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          TextField(
            controller: _searchController,
            decoration: const InputDecoration(
              hintText: 'Search riders',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (value) => ref.read(userSearchControllerProvider.notifier).updateQuery(value.trim()),
          ),
          const SizedBox(height: 8),
          searchResultsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text('Search failed: $error'),
            ),
            data: (results) => Column(
              children: results.map((user) {
                final isPending = _invitedUserIds.contains(user.id);
                return ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: Text('@${user.username}'),
                  trailing: TextButton(
                    onPressed: isPending ? null : () => _addMember(user),
                    child: Text(isPending ? 'Pending' : 'Add'),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 24),
          const Divider(),
          Text('Members (joined)', style: theme.textTheme.titleMedium),
          membersAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text('Could not load members: $error'),
            ),
            data: (members) => Column(
              children: members
                  .map(
                    (member) => ListTile(
                      leading: const Icon(Icons.two_wheeler_outlined),
                      title: Text('@${member.username ?? 'unknown'}'),
                      trailing: member.role == 'leader' ? const Chip(label: Text('Leader')) : null,
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}
