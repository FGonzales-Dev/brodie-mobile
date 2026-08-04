import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:brodie/main.dart';

void main() {
  testWidgets('App shows the Map tab by default with bottom nav', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: BrodieApp()));
    await tester.pumpAndSettle();

    expect(find.text('Map'), findsWidgets);
    expect(find.text('Groups'), findsOneWidget);
    expect(find.text('History'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);
  });
}
