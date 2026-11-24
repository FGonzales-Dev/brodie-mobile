import 'dart:async';

import 'package:brodie/app/brodie_app.dart';
import 'package:brodie/app/router/app_router.dart';
import 'package:brodie/app/router/routes.dart';
import 'package:brodie/core/data/owned_rows_table.dart';
import 'package:brodie/core/di/core_providers.dart';
import 'package:brodie/features/auth/data/auth_repository.dart';
import 'package:brodie/features/auth/domain/app_user.dart';
import 'package:brodie/features/auth/domain/sign_up_outcome.dart';
import 'package:brodie/features/emergency_contacts/data/emergency_contact_repository.dart';
import 'package:brodie/features/emergency_contacts/domain/emergency_contact.dart';
import 'package:brodie/features/groups/data/group_repository.dart';
import 'package:brodie/features/groups/domain/group_models.dart';
import 'package:brodie/features/map/data/location_repository.dart';
import 'package:brodie/features/map/domain/map_models.dart';
import 'package:brodie/features/profile/application/my_profile_provider.dart';
import 'package:brodie/features/profile/domain/profile.dart';
import 'package:brodie/features/vehicles/data/vehicle_repository.dart';
import 'package:brodie/features/vehicles/domain/vehicle.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository(this.currentUser);

  @override
  final AppUser? currentUser;

  @override
  Stream<AppUser?> userChanges() => Stream.value(currentUser);

  @override
  Future<void> signIn({required String email, required String password}) async {}

  @override
  Future<SignUpOutcome> signUp({required String email, required String password}) async => SignUpOutcome.signedIn;

  @override
  Future<void> sendPasswordReset(String email) async {}

  @override
  Future<void> signOut() async {}
}

/// Starts signed out; [signInAs] signs in, like the real auth stream.
class _SwitchableAuthRepository implements AuthRepository {
  final _changes = StreamController<AppUser?>.broadcast();

  @override
  AppUser? currentUser;

  void signInAs(AppUser user) {
    currentUser = user;
    _changes.add(user);
  }

  @override
  Stream<AppUser?> userChanges() => _changes.stream;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _InviteGroups implements GroupRepository {
  @override
  Future<GroupInvitePreview?> fetchInvitePreview(String code) async => code == '7A879D'
      ? const GroupInvitePreview(groupId: 'group-1', name: 'Sunday crew', leaderUsername: 'lea', memberCount: 3)
      : null;

  @override
  Future<List<GroupInvite>> fetchPendingInvites() async => const [];

  @override
  Future<List<RideGroup>> fetchMyGroups() async => const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// The rider's own rows (vehicles, emergency contacts), kept in memory.
class _MemoryRows<T, D> implements OwnedRowsTable<T, D> {
  _MemoryRows(this.make);

  final T Function(String id, D draft) make;
  final rows = <T>[];

  @override
  Future<List<T>> fetchMine() async => List.of(rows);

  @override
  Future<void> insert(D draft) async => rows.add(make('row-${rows.length + 1}', draft));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _DeniedLocationRepository extends LocationRepository {
  @override
  Future<LocationAccess> checkAccess() async => LocationAccess.denied;
}

late _MemoryRows<Vehicle, VehicleDraft> _vehicles;
late _MemoryRows<EmergencyContact, EmergencyContactDraft> _contacts;

/// [onboarded] says whether user-1 has already been through onboarding on
/// this phone.
Future<void> _pumpApp(WidgetTester tester, {AppUser? user, Profile? profile, bool onboarded = true}) async {
  SharedPreferences.setMockInitialValues({if (onboarded) 'onboarding.done.user-1': true});
  _vehicles = _MemoryRows((id, draft) => Vehicle(id: id, type: draft.type, name: draft.name));
  _contacts = _MemoryRows((id, draft) => EmergencyContact(id: id, name: draft.name, phone: draft.phone));
  final prefs = await SharedPreferences.getInstance();
  final overrides = <Override>[
    sharedPreferencesProvider.overrideWithValue(prefs),
    mapboxAccessTokenProvider.overrideWithValue('test-token'),
    authRepositoryProvider.overrideWithValue(_FakeAuthRepository(user)),
    locationRepositoryProvider.overrideWithValue(_DeniedLocationRepository()),
    vehicleRepositoryProvider.overrideWithValue(_vehicles),
    emergencyContactRepositoryProvider.overrideWithValue(_contacts),
    if (user != null) myProfileProvider.overrideWith((ref) async => profile),
  ];
  await tester.pumpWidget(ProviderScope(overrides: overrides, child: const BrodieApp()));
  await tester.pumpAndSettle();
}

void main() {
  const user = AppUser(id: 'user-1', email: 'alex@brodie.app');

  testWidgets('signed-out users land on sign in', (tester) async {
    await _pumpApp(tester);

    expect(find.text('RIDE TOGETHER.'), findsOneWidget);
    expect(find.text('SIGN IN'), findsOneWidget);
  });

  testWidgets('signed-in users without a username must pick one first', (tester) async {
    await _pumpApp(tester, user: user, profile: const Profile(id: 'user-1'));

    expect(find.text('PICK YOUR HANDLE.'), findsOneWidget);
  });

  testWidgets('users with a username reach the tabbed app', (tester) async {
    await _pumpApp(tester, user: user, profile: const Profile(id: 'user-1', username: 'alex_rides'));

    for (final tab in ['MAP', 'GROUPS', 'HISTORY', 'PROFILE']) {
      expect(find.text(tab), findsOneWidget);
    }
    // Location is denied in this test, so the map shows its permission gate.
    expect(find.text('LOCATION NEEDED'), findsOneWidget);
  });

  testWidgets('an invite link opened while signed out opens after signing in', (tester) async {
    SharedPreferences.setMockInitialValues({'onboarding.done.user-1': true});
    final prefs = await SharedPreferences.getInstance();
    final auth = _SwitchableAuthRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          mapboxAccessTokenProvider.overrideWithValue('test-token'),
          authRepositoryProvider.overrideWithValue(auth),
          locationRepositoryProvider.overrideWithValue(_DeniedLocationRepository()),
          groupRepositoryProvider.overrideWithValue(_InviteGroups()),
          myProfileProvider.overrideWith((ref) async => const Profile(id: 'user-1', username: 'alex_rides')),
        ],
        child: const BrodieApp(),
      ),
    );
    await tester.pumpAndSettle();
    final router = ProviderScope.containerOf(tester.element(find.byType(BrodieApp))).read(routerProvider);

    router.go(Routes.join('7A879D'));
    await tester.pumpAndSettle();
    expect(find.text('SIGN IN'), findsOneWidget);

    auth.signInAs(user);
    await tester.pumpAndSettle();

    expect(find.text('SUNDAY CREW'), findsOneWidget);
    expect(find.text('Led by @lea · 3 riders'), findsOneWidget);
    expect(find.text('JOIN GROUP'), findsOneWidget);
  });

  group('onboarding', () {
    const named = Profile(id: 'user-1', username: 'alex_rides');

    testWidgets('new riders see it after picking a username, and can skip every step', (tester) async {
      await _pumpApp(tester, user: user, profile: named, onboarded: false);
      expect(find.text('RIDE AS A CREW.'), findsOneWidget);

      await tester.tap(find.text('NEXT'));
      await tester.pumpAndSettle();
      expect(find.text('SEE YOUR CREW LIVE.'), findsOneWidget);

      await tester.tap(find.text('Skip intro'));
      await tester.pumpAndSettle();
      expect(find.text('YOUR LOCATION'), findsOneWidget);
      expect(find.text('ALLOW LOCATION'), findsOneWidget);

      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();
      expect(find.text('WHAT DO YOU RIDE?'), findsOneWidget);

      await tester.tap(find.text('Skip for now'));
      await tester.pumpAndSettle();
      expect(find.text('WHO SHOULD WE TEXT?'), findsOneWidget);

      await tester.tap(find.text('Skip and finish'));
      await tester.pumpAndSettle();
      expect(find.text('MAP'), findsOneWidget);
      expect(_vehicles.rows, isEmpty);
      expect(_contacts.rows, isEmpty);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('onboarding.done.user-1'), isTrue, reason: 'not shown again');
    });

    testWidgets('riders can add their bike and an emergency contact on the way', (tester) async {
      await _pumpApp(tester, user: user, profile: named, onboarded: false);
      await tester.tap(find.text('Skip intro'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();

      // Saving with no name asks for one instead.
      await tester.tap(find.text('SAVE'));
      await tester.pumpAndSettle();
      expect(find.text('Enter a name, or skip this step'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField), 'Honda ADV 160');
      await tester.tap(find.text('SAVE'));
      await tester.pumpAndSettle();
      expect(_vehicles.rows.single.name, 'Honda ADV 160');

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'Mom');
      await tester.enterText(fields.at(1), '+63 917 123 4567');
      await tester.tap(find.text('SAVE AND FINISH'));
      await tester.pumpAndSettle();

      expect(_contacts.rows.single.phone, '+63 917 123 4567');
      expect(find.text('MAP'), findsOneWidget);
    });

    testWidgets('riders who finished it go straight to the app', (tester) async {
      await _pumpApp(tester, user: user, profile: named);
      expect(find.text('RIDE AS A CREW.'), findsNothing);
      expect(find.text('MAP'), findsOneWidget);
    });
  });
}
