import 'package:brodie/core/design_system/design_system.dart';
import 'package:brodie/features/map/data/location_repository.dart';
import 'package:brodie/features/map/domain/location_health.dart';
import 'package:brodie/features/map/domain/map_models.dart';
import 'package:brodie/features/map/presentation/widgets/location_issue_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final _start = DateTime(2026, 11, 26, 8);

GeoFix _fix({required DateTime at, double speedMps = 10, double accuracy = 8}) => GeoFix(
  position: const GeoPoint(latitude: 14.1, longitude: 120.9),
  accuracyMeters: accuracy,
  speedMps: speedMps,
  headingDegrees: 0,
  timestamp: at,
);

LocationIssue _issue({GeoFix? lastFix, LocationAccess? lost, required Duration after}) =>
    LocationIssue.at(lastFix: lastFix, accessLost: lost, startedAt: _start, now: _start.add(after));

void main() {
  test('a fresh, accurate position is fine', () {
    expect(
      _issue(
        lastFix: _fix(at: _start),
        after: const Duration(seconds: 5),
      ),
      LocationIssue.none,
    );
  });

  test("a rider stopped at the lights isn't flagged, however long they wait", () {
    expect(
      _issue(
        lastFix: _fix(at: _start, speedMps: 0),
        after: const Duration(minutes: 5),
      ),
      LocationIssue.none,
    );
  });

  test('a moving rider who goes quiet has lost the signal', () {
    final fix = _fix(at: _start, speedMps: 15);
    expect(_issue(lastFix: fix, after: const Duration(seconds: 20)), LocationIssue.none);
    expect(_issue(lastFix: fix, after: const Duration(seconds: 30)), LocationIssue.signalLost);
  });

  test('no position at all for a while counts as lost', () {
    expect(_issue(after: const Duration(seconds: 10)), LocationIssue.none);
    expect(_issue(after: const Duration(seconds: 40)), LocationIssue.signalLost);
  });

  test('inaccurate positions are a weak signal', () {
    expect(
      _issue(
        lastFix: _fix(at: _start, accuracy: 120),
        after: Duration.zero,
      ),
      LocationIssue.weakSignal,
    );
  });

  test('losing access matters more than anything about the signal', () {
    final fresh = _fix(at: _start);
    expect(
      _issue(lastFix: fresh, lost: LocationAccess.serviceDisabled, after: Duration.zero),
      LocationIssue.serviceDisabled,
    );
    expect(_issue(lastFix: fresh, lost: LocationAccess.denied, after: Duration.zero), LocationIssue.permissionDenied);
    expect(
      _issue(lastFix: fresh, lost: LocationAccess.deniedForever, after: Duration.zero),
      LocationIssue.permissionDenied,
    );
  });

  group('banner', () {
    Future<void> pump(WidgetTester tester, {GeoFix? lastFix, LocationAccess? lost}) => tester.pumpWidget(
      ProviderScope(
        overrides: [locationRepositoryProvider.overrideWithValue(LocationRepository())],
        child: MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: LocationIssueBanner(lastFix: lastFix, accessLost: lost, startedAt: DateTime.now(), inGroupRide: true),
          ),
        ),
      ),
    );

    testWidgets('says nothing while all is well', (tester) async {
      await pump(tester, lastFix: _fix(at: DateTime.now()));
      expect(find.byType(Icon), findsNothing);
    });

    testWidgets('revoked access asks for it back', (tester) async {
      await pump(
        tester,
        lastFix: _fix(at: DateTime.now()),
        lost: LocationAccess.denied,
      );
      expect(find.text('Location access is off'), findsOneWidget);
      expect(find.textContaining('Your group sees your last position.'), findsOneWidget);
      expect(find.text('Open settings'), findsOneWidget);
    });

    testWidgets('location switched off points to the location settings', (tester) async {
      await pump(tester, lost: LocationAccess.serviceDisabled);
      expect(find.text('Location is turned off'), findsOneWidget);
      expect(find.text('Turn on location'), findsOneWidget);
    });

    testWidgets('a weak signal is a warning with no button', (tester) async {
      await pump(tester, lastFix: _fix(at: DateTime.now(), accuracy: 200));
      expect(find.text('Weak GPS signal'), findsOneWidget);
      expect(find.byType(TextButton), findsNothing);
    });
  });
}
