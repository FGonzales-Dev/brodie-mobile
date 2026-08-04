import 'package:flutter/material.dart';

/// Shared shell for Privacy Policy / Terms — content is placeholder copy
/// until real legal text is drafted.
class LegalScreen extends StatelessWidget {
  const LegalScreen({super.key, required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Text(body, style: Theme.of(context).textTheme.bodyMedium),
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
