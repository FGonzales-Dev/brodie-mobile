import 'dart:async';

import 'package:brodie/app/brodie_app.dart';
import 'package:brodie/app/router/app_router.dart';
import 'package:brodie/app/router/routes.dart';
import 'package:brodie/core/di/core_providers.dart';
import 'package:brodie/features/auth/data/auth_repository.dart';
import 'package:brodie/features/auth/domain/app_user.dart';
import 'package:brodie/features/auth/domain/sign_up_outcome.dart';
import 'package:brodie/features/groups/data/group_repository.dart';
import 'package:brodie/features/groups/domain/group_models.dart';
import 'package:brodie/features/map/data/location_repository.dart';
import 'package:brodie/features/map/domain/map_models.dart';
import 'package:brodie/features/profile/application/my_profile_provider.dart';
import 'package:brodie/features/profile/domain/profile.dart';
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

class _DeniedLocationRepository extends LocationRepository {
  @override
  Future<LocationAccess> checkAccess() async => LocationAccess.denied;
}

Future<void> _pumpApp(WidgetTester tester, {AppUser? user, Profile? profile}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final overrides = <Override>[
    sharedPreferencesProvider.overrideWithValue(prefs),
    mapboxAccessTokenProvider.overrideWithValue('test-token'),
    authRepositoryProvider.overrideWithValue(_FakeAuthRepository(user)),
    locationRepositoryProvider.overrideWithValue(_DeniedLocationRepository()),
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
    SharedPreferences.setMockInitialValues({});
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
}
