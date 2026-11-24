import 'package:brodie/core/design_system/design_system.dart';
import 'package:brodie/features/settings/domain/legal_documents.dart';
import 'package:brodie/features/settings/presentation/info_screens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('the privacy policy shows its date, sections and bullet points', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: const LegalScreen(document: privacyPolicy),
      ),
    );

    expect(find.text('Last updated ${privacyPolicy.updated}'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('YOUR LOCATION'), 300);
    expect(find.text('YOUR LOCATION'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('DELETING YOUR DATA'), 300);
    expect(find.text('DELETING YOUR DATA'), findsOneWidget);
    // Bullets lose their marker character; it's drawn separately.
    expect(find.textContaining('• Your account'), findsNothing);
  });

  test('no placeholder text is left in either document', () {
    for (final document in [privacyPolicy, termsOfUse]) {
      final text = [document.intro, for (final s in document.sections) ...s.paragraphs].join(' ').toLowerCase();
      expect(text, isNot(contains('placeholder')));
      expect(document.sections, isNotEmpty);
    }
  });
}
