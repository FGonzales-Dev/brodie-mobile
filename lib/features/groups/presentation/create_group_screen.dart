import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../../../core/design_system/design_system.dart';
import '../../../core/presentation/feedback.dart';
import '../../../core/utils/validators.dart';
import 'group_controllers.dart';

class CreateGroupScreen extends ConsumerStatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  ConsumerState<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends ConsumerState<CreateGroupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final group = await ref.read(createGroupControllerProvider.notifier).create(_name.text.trim());
    if (group != null && mounted) context.pushReplacement(Routes.groupInvite(group.id));
  }

  @override
  Widget build(BuildContext context) {
    ref.showErrorsOf(createGroupControllerProvider, context);
    final isLoading = ref.watch(createGroupControllerProvider).isLoading;

    return Scaffold(
      appBar: const BrodieAppBar(title: 'New group ride'),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(BrodieSpace.md),
          children: [
            Text(
              "Name the group, then invite riders by username or share the code.",
              style: BrodieType.body.copyWith(color: context.colors.textSecondary, fontSize: 15),
            ),
            const SizedBox(height: BrodieSpace.lg),
            BrodieTextField(
              controller: _name,
              label: 'Group name',
              hint: 'e.g. Sunday Tagaytay Run',
              icon: Icons.groups_outlined,
              autofocus: true,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              validator: Validators.required('Enter a group name'),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            left: BrodieSpace.md,
            right: BrodieSpace.md,
            bottom: BrodieSpace.md + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: BrodieButton(label: 'Create group', isLoading: isLoading, onPressed: _submit),
        ),
      ),
    );
  }
}
