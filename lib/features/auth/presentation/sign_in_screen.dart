import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../../../core/design_system/design_system.dart';
import '../../../core/presentation/feedback.dart';
import '../../../core/utils/validators.dart';
import 'auth_controllers.dart';
import 'widgets/auth_scaffold.dart';
import 'widgets/email_field.dart';

class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    // On success the router redirects away from this screen.
    await ref.read(signInControllerProvider.notifier).signIn(email: _email.text.trim(), password: _password.text);
  }

  Future<void> _resetPassword() async {
    final email = await showBrodieSheet<String>(
      context,
      builder: (_) => _ResetPasswordSheet(initialEmail: _email.text.trim()),
    );
    if (email == null) return;
    final sent = await ref.read(signInControllerProvider.notifier).sendPasswordReset(email);
    if (sent && mounted) context.showMessage('Password reset email sent. Check your inbox.');
  }

  @override
  Widget build(BuildContext context) {
    ref.showErrorsOf(signInControllerProvider, context);
    final isLoading = ref.watch(signInControllerProvider).isLoading;

    return AuthScaffold(
      title: 'Ride together.',
      subtitle: 'Plan the route, roll out as a crew, and always know where everyone is.',
      form: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            EmailField(controller: _email, textInputAction: TextInputAction.next),
            const SizedBox(height: BrodieSpace.sm),
            BrodiePasswordField(
              controller: _password,
              validator: Validators.password,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(onPressed: isLoading ? null : _resetPassword, child: const Text('Forgot password?')),
            ),
            BrodieButton(label: 'Sign in', isLoading: isLoading, onPressed: _submit),
          ],
        ),
      ),
      footer: AuthFooterLink(
        prompt: 'New to Brodie?',
        action: 'Create an account',
        onTap: () => context.go(Routes.signUp),
      ),
    );
  }
}

class _ResetPasswordSheet extends StatefulWidget {
  const _ResetPasswordSheet({required this.initialEmail});

  final String initialEmail;

  @override
  State<_ResetPasswordSheet> createState() => _ResetPasswordSheetState();
}

class _ResetPasswordSheetState extends State<_ResetPasswordSheet> {
  late final _email = TextEditingController(text: widget.initialEmail);

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BrodieFormSheet<String>(
      title: 'Reset password',
      saveLabel: 'Send reset link',
      fields: [EmailField(controller: _email, autofocus: true)],
      onSave: () => _email.text.trim(),
    );
  }
}
