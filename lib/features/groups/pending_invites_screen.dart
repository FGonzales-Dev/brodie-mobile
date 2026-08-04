import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'application/pending_invites_controller.dart';

class PendingInvitesScreen extends ConsumerWidget {
  const PendingInvitesScreen({super.key});

  Future<void> _respond(BuildContext context, WidgetRef ref, String groupId, {required bool accept}) async {
    try {
      final controller = ref.read(pendingInvitesControllerProvider.notifier);
      if (accept) {
        await controller.accept(groupId);
      } else {
        await controller.decline(groupId);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not respond to invite: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invitesAsync = ref.watch(pendingInvitesControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Pending Invites')),
      body: invitesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Could not load invites: $error')),
        data: (invites) {
          if (invites.isEmpty) {
            return const Center(child: Text('No pending invites'));
          }
          return ListView.builder(
            itemCount: invites.length,
            itemBuilder: (context, index) {
              final invite = invites[index];
              return ListTile(
                leading: const Icon(Icons.groups_outlined),
                title: Text(invite.groupName),
                subtitle: invite.invitedBy != null ? Text('Invited by @${invite.invitedBy}') : null,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.check_circle_outline, color: Colors.green),
                      onPressed: () => _respond(context, ref, invite.groupId, accept: true),
                    ),
                    IconButton(
                      icon: Icon(Icons.cancel_outlined, color: Theme.of(context).colorScheme.error),
                      onPressed: () => _respond(context, ref, invite.groupId, accept: false),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
