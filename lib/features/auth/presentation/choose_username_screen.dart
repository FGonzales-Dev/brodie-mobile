import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design_system/design_system.dart';
import '../../../core/utils/validators.dart';
import 'auth_controllers.dart';
import 'widgets/auth_scaffold.dart';

class ChooseUsernameScreen extends ConsumerStatefulWidget {
  const ChooseUsernameScreen({super.key});

  @override
  ConsumerState<ChooseUsernameScreen> createState() => _ChooseUsernameScreenState();
}

class _ChooseUsernameScreenState extends ConsumerState<ChooseUsernameScreen> {
  final _formKey = GlobalKey<FormState>();
  final _username = TextEditingController();

  @override
  void dispose() {
    _username.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    // The router moves on once the profile reloads with the new username.
    await ref.read(usernameControllerProvider.notifier).submit(_username.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(usernameControllerProvider);
    final canSubmit = state.isAvailable == true && !state.isChecking;

    return AuthScaffold(
      title: 'Pick your handle.',
      subtitle: 'This is how other riders find you when they invite you to a group ride.',
      form: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            BrodieTextField(
              controller: _username,
              label: 'Username',
              icon: Icons.alternate_email,
              autofocus: true,
              textInputAction: TextInputAction.done,
              helperText: Validators.usernameRule,
              errorText: state.errorMessage,
              suffix: _AvailabilityIndicator(state: state),
              onChanged: (value) => ref.read(usernameControllerProvider.notifier).checkAvailability(value.trim()),
              onSubmitted: (_) => _submit(),
              validator: (_) => state.isAvailable == true ? null : 'Choose an available username',
            ),
            const SizedBox(height: BrodieSpace.lg),
            BrodieButton(label: 'Continue', isLoading: state.isSubmitting, onPressed: canSubmit ? _submit : null),
          ],
        ),
      ),
    );
  }
}

class _AvailabilityIndicator extends StatelessWidget {
  const _AvailabilityIndicator({required this.state});

  final UsernameState state;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    if (state.isChecking) {
      return const Padding(
        padding: EdgeInsets.all(14),
        child: SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    return switch (state.isAvailable) {
      true => Icon(Icons.check_circle, color: colors.success),
      false => Icon(Icons.cancel, color: colors.danger),
      null => const SizedBox.shrink(),
    };
  }
}
