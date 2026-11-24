import 'package:brodie/core/data/owned_rows_table.dart';
import 'package:brodie/core/design_system/app_theme.dart';
import 'package:brodie/features/emergency_contacts/data/emergency_contact_repository.dart';
import 'package:brodie/features/emergency_contacts/domain/emergency_contact.dart';
import 'package:brodie/features/map/data/location_repository.dart';
import 'package:brodie/features/map/domain/map_models.dart';
import 'package:brodie/features/profile/application/my_profile_provider.dart';
import 'package:brodie/features/profile/domain/profile.dart';
import 'package:brodie/features/sos/presentation/sos_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

/// Records the links the screen opens instead of opening apps.
class _FakeLauncher extends Fake with MockPlatformInterfaceMixin implements UrlLauncherPlatform {
  final opened = <String>[];

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    opened.add(url);
    return true;
  }
}

class _Contacts implements EmergencyContactRepository {
  _Contacts(this.contacts);

  final List<EmergencyContact> contacts;

  @override
  Future<List<EmergencyContact>> fetchMine() async => contacts;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _NoFreshFix extends LocationRepository {
  @override
  Future<GeoFix> currentFix() => Future.error(Exception('no GPS'));
}

final _lastFix = GeoFix(
  position: const GeoPoint(latitude: 14.1153, longitude: 120.9621),
  accuracyMeters: 8,
  speedMps: 0,
  headingDegrees: 0,
  timestamp: DateTime(2026, 11, 25, 8, 4),
);

void main() {
  late _FakeLauncher launcher;

  setUp(() {
    launcher = _FakeLauncher();
    UrlLauncherPlatform.instance = launcher;
  });

  Future<void> openSos(WidgetTester tester, List<EmergencyContact> contacts) async {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, _) => Scaffold(
            body: TextButton(onPressed: () => context.push('/sos', extra: _lastFix), child: const Text('ride')),
          ),
        ),
        GoRoute(path: '/sos', builder: (_, state) => SosScreen(lastFix: state.extra as GeoFix?)),
        GoRoute(path: '/profile/emergency-contacts', builder: (_, _) => const Text('contacts screen')),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          emergencyContactRepositoryProvider.overrideWithValue(_Contacts(contacts) as OwnedRowsTable<EmergencyContact, EmergencyContactDraft>),
          locationRepositoryProvider.overrideWithValue(_NoFreshFix()),
          myProfileProvider.overrideWith((ref) async => const Profile(id: 'user-1', username: 'alex_rides')),
        ],
        child: MaterialApp.router(theme: AppTheme.dark, routerConfig: router),
      ),
    );
    await tester.tap(find.text('ride'));
    await tester.pumpAndSettle();
  }

  const mom = EmergencyContact(id: 'c1', name: 'Mom', phone: '+63 917 123 4567', relationship: 'Mother');

  testWidgets('cancelling during the countdown sends nothing', (tester) async {
    await openSos(tester, [mom]);
    expect(find.text('5'), findsOneWidget);

    await tester.pump(const Duration(seconds: 2));
    expect(find.text('3'), findsOneWidget);
    await tester.tap(find.text('CANCEL'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 10));

    expect(find.text('ride'), findsOneWidget);
    expect(launcher.opened, isEmpty);
  });

  testWidgets('after the countdown, a text to the contacts opens with the location', (tester) async {
    await openSos(tester, [mom]);

    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    final sms = launcher.opened.single;
    expect(sms, startsWith('sms:'));
    expect(sms, contains('+639171234567'));
    expect(Uri.decodeComponent(sms), contains('maps.google.com/?q=14.115300,120.962100'));
    expect(find.text('Tap Send in your messages app'), findsOneWidget);

    await tester.tap(find.byTooltip('Call Mom'));
    await tester.pumpAndSettle();
    expect(launcher.opened.last, 'tel:+639171234567');
  });

  testWidgets('without contacts, it says so and offers to add some', (tester) async {
    await openSos(tester, const []);

    await tester.tap(find.text('Send now'));
    await tester.pumpAndSettle();

    expect(launcher.opened, isEmpty);
    expect(find.text('No emergency contacts yet'), findsOneWidget);
    await tester.tap(find.text('ADD CONTACTS'));
    await tester.pumpAndSettle();
    expect(find.text('contacts screen'), findsOneWidget);
  });
}
