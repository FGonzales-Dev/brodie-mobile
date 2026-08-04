import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'application/create_group_controller.dart';

class CreateGroupScreen extends ConsumerStatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  ConsumerState<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends ConsumerState<CreateGroupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final group = await ref.read(createGroupControllerProvider.notifier).createGroup(
          name: _nameController.text.trim(),
        );

    if (!mounted) return;

    final error = ref.read(createGroupControllerProvider).hasError;
    if (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not create group. Please try again.')),
      );
      return;
    }

    if (group != null) {
      context.pushReplacement('/groups/${group.id}/invite', extra: group.inviteCode);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(createGroupControllerProvider).isLoading;

    return Scaffold(
      appBar: AppBar(title: const Text('Create Group Ride')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nameController,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Group name'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return 'Enter a group name';
                  return null;
                },
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: isLoading ? null : _submit,
                style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                child: isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Create'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
