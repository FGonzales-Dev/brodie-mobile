import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design_system/design_system.dart';
import '../data/settings_repository.dart';

class AboutScreen extends ConsumerWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final version = ref.watch(appVersionProvider).value;
    return Scaffold(
      appBar: const BrodieAppBar(title: 'About'),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const BrandMark(size: 72),
            const SizedBox(height: BrodieSpace.md),
            Text('BRODIE', style: BrodieType.screenTitle.copyWith(color: colors.textPrimary)),
            const SizedBox(height: BrodieSpace.xxs),
            Text(
              version == null ? '' : 'Version $version',
              style: BrodieType.body.copyWith(color: colors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shared layout for Privacy Policy and Terms. The copy is placeholder until
/// reviewed legal text exists.
class LegalScreen extends StatelessWidget {
  const LegalScreen({super.key, required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: BrodieAppBar(title: title),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(BrodieSpace.lg),
        child: Text(body, style: BrodieType.body.copyWith(color: context.colors.textPrimary, fontSize: 15)),
      ),
    );
  }
}

const privacyPolicyPlaceholder = '''
Placeholder Privacy Policy.

Brodie collects location data to provide navigation and group ride features, account information for authentication, and vehicle/emergency contact details you choose to add. This text is a placeholder and must be replaced with reviewed legal copy before release.
''';

const termsPlaceholder = '''
Placeholder Terms of Service.

By using Brodie you agree to ride safely and use group ride and SOS features responsibly. This text is a placeholder and must be replaced with reviewed legal copy before release.
''';
