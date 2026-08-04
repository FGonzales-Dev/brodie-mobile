import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'application/username_selection_controller.dart';

class ChooseUsernameScreen extends ConsumerStatefulWidget {
  const ChooseUsernameScreen({super.key});

  @override
  ConsumerState<ChooseUsernameScreen> createState() => _ChooseUsernameScreenState();
}

class _ChooseUsernameScreenState extends ConsumerState<ChooseUsernameScreen> {
  final _formKey = GlobalKey<FormState>();
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    await ref.read(usernameSelectionControllerProvider.notifier).submit(_controller.text.trim());
    // Router redirect picks up the newly-set username and moves on automatically.
  }

  IconData? _availabilityIcon(UsernameSelectionState state) {
    if (state.isChecking) return null;
    if (state.isAvailable == true) return Icons.check_circle;
    if (state.isAvailable == false) return Icons.cancel;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(usernameSelectionControllerProvider);
    final icon = _availabilityIcon(state);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 24),
                Text('Choose a username', style: theme.textTheme.displaySmall),
                const SizedBox(height: 8),
                Text(
                  "This is how other riders will find you when they invite you to a group ride.",
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 40),
                TextFormField(
                  controller: _controller,
                  autofocus: true,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(),
                  onChanged: (value) =>
                      ref.read(usernameSelectionControllerProvider.notifier).checkAvailability(value.trim()),
                  decoration: InputDecoration(
                    labelText: 'Username',
                    prefixIcon: const Icon(Icons.alternate_email),
                    suffixIcon: state.isChecking
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : icon != null
                            ? Icon(icon, color: state.isAvailable == true ? Colors.green : Colors.red)
                            : null,
                    helperText: '3-20 characters: lowercase letters, numbers, underscores',
                    errorText: state.errorMessage,
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) return 'Enter a username';
                    if (state.isAvailable != true) return 'Choose an available username';
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: state.isSubmitting ? null : _submit,
                    style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                    child: state.isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Continue'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
