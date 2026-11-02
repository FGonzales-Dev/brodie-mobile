import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../../../core/design_system/design_system.dart';
import '../../../core/presentation/feedback.dart';
import '../../../core/utils/validators.dart';
import '../domain/sign_up_outcome.dart';
import 'auth_controllers.dart';
import 'widgets/auth_scaffold.dart';
import 'widgets/email_field.dart';

class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final outcome = await ref
        .read(signUpControllerProvider.notifier)
        .signUp(email: _email.text.trim(), password: _password.text);
    // When signed in, the router moves on to choosing a username by itself.
    if (outcome == SignUpOutcome.needsEmailConfirmation && mounted) {
      context.showMessage('Check your email to confirm your account, then sign in.');
      context.go(Routes.signIn);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.showErrorsOf(signUpControllerProvider, context);
    final isLoading = ref.watch(signUpControllerProvider).isLoading;

    return AuthScaffold(
      title: 'Join the crew.',
      subtitle: 'Create an account to plan rides and roll out with your group.',
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
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: BrodieSpace.sm),
            BrodiePasswordField(
              controller: _confirmPassword,
              label: 'Confirm password',
              validator: (value) => value == _password.text ? null : 'Passwords do not match',
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: BrodieSpace.lg),
            BrodieButton(label: 'Create account', isLoading: isLoading, onPressed: _submit),
          ],
        ),
      ),
      footer: AuthFooterLink(
        prompt: 'Already have an account?',
        action: 'Sign in',
        onTap: () => context.go(Routes.signIn),
      ),
    );
  }
}
