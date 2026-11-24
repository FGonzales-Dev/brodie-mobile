import 'package:flutter/material.dart';

import '../../../../core/design_system/design_system.dart';
import 'road_art.dart';

/// Shared layout for the sign-in, sign-up and username screens: road-map
/// artwork, brand mark, headline, then the screen's form and footer.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({super.key, required this.title, required this.subtitle, required this.form, this.footer});

  final String title;
  final String subtitle;
  final Widget form;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 220, child: RoadArt()),
            Padding(
              padding: const EdgeInsets.fromLTRB(BrodieSpace.lg, 0, BrodieSpace.lg, BrodieSpace.xl),
              child: SafeArea(
                top: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Align(alignment: Alignment.centerLeft, child: BrandMark()),
                    const SizedBox(height: BrodieSpace.md),
                    Text(
                      title.toUpperCase(),
                      style: BrodieType.screenTitle.copyWith(fontSize: 48, color: colors.textPrimary),
                    ),
                    const SizedBox(height: BrodieSpace.xs),
                    Text(subtitle, style: BrodieType.body.copyWith(color: colors.textSecondary, fontSize: 15)),
                    const SizedBox(height: BrodieSpace.lg),
                    form,
                    if (footer != null) ...[const SizedBox(height: BrodieSpace.md), footer!],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "New to Brodie? Create an account" style link under an auth form.
class AuthFooterLink extends StatelessWidget {
  const AuthFooterLink({super.key, required this.prompt, required this.action, required this.onTap});

  final String prompt;
  final String action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(prompt, style: BrodieType.body.copyWith(color: context.colors.textSecondary)),
        TextButton(onPressed: onTap, child: Text(action)),
      ],
    );
  }
}
