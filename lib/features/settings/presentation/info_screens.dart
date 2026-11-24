import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design_system/design_system.dart';
import '../data/settings_repository.dart';
import '../domain/legal_documents.dart';

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

/// The privacy policy or the terms: a date, an intro, then headed sections.
class LegalScreen extends StatelessWidget {
  const LegalScreen({super.key, required this.document});

  final LegalDocument document;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final body = BrodieType.body.copyWith(color: colors.textPrimary, fontSize: 15);
    return Scaffold(
      appBar: BrodieAppBar(title: document.title),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(BrodieSpace.lg, BrodieSpace.md, BrodieSpace.lg, BrodieSpace.xl),
        children: [
          Text('Last updated ${document.updated}', style: BrodieType.caption.copyWith(color: colors.textSecondary)),
          const SizedBox(height: BrodieSpace.sm),
          Text(document.intro, style: body),
          for (final section in document.sections) ...[
            const SizedBox(height: BrodieSpace.lg),
            Text(section.heading.toUpperCase(), style: BrodieType.title.copyWith(color: colors.textPrimary)),
            for (final paragraph in section.paragraphs)
              Padding(
                padding: const EdgeInsets.only(top: BrodieSpace.xs),
                child: paragraph.startsWith('• ')
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('•  ', style: body),
                          Expanded(child: Text(paragraph.substring(2), style: body)),
                        ],
                      )
                    : Text(paragraph, style: body),
              ),
          ],
        ],
      ),
    );
  }
}
