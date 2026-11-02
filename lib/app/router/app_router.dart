import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../features/auth/application/session_providers.dart';
import '../../features/auth/presentation/choose_username_screen.dart';
import '../../features/auth/presentation/sign_in_screen.dart';
import '../../features/auth/presentation/sign_up_screen.dart';
import '../../features/emergency_contacts/presentation/emergency_contacts_screen.dart';
import '../../features/groups/presentation/create_group_screen.dart';
import '../../features/groups/presentation/groups_screen.dart';
import '../../features/groups/presentation/invite_screen.dart';
import '../../features/groups/presentation/pending_invites_screen.dart';
import '../../features/history/presentation/history_screen.dart';
import '../../features/history/presentation/ride_detail_screen.dart';
import '../../features/map/presentation/destination_search_screen.dart';
import '../../features/map/presentation/map_screen.dart';
import '../../features/map/presentation/solo_ride/solo_ride_screen.dart';
import '../../features/profile/application/my_profile_provider.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/settings/presentation/info_screens.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/usage/presentation/usage_screen.dart';
import '../../features/vehicles/presentation/vehicles_screen.dart';
import '../app_shell.dart';
import '../splash_screen.dart';
import 'routes.dart';

part 'app_router.g.dart';

@Riverpod(keepAlive: true)
GoRouter router(Ref ref) {
  // Re-run redirects whenever the session or profile changes.
  final refresh = ValueNotifier(0);
  ref
    ..listen(currentUserProvider, (_, _) => refresh.value++)
    ..listen(myProfileProvider, (_, _) => refresh.value++);

  final router = GoRouter(
    initialLocation: Routes.splash,
    refreshListenable: refresh,
    redirect: (_, state) => _redirect(ref, state.matchedLocation),
    routes: [
      GoRoute(path: Routes.splash, builder: (_, _) => const SplashScreen()),
      GoRoute(path: Routes.signIn, builder: (_, _) => const SignInScreen()),
      GoRoute(path: Routes.signUp, builder: (_, _) => const SignUpScreen()),
      GoRoute(path: Routes.chooseUsername, builder: (_, _) => const ChooseUsernameScreen()),
      GoRoute(path: Routes.destinationSearch, builder: (_, _) => const DestinationSearchScreen()),
      GoRoute(path: Routes.soloRide, builder: (_, _) => const SoloRideScreen()),
      GoRoute(
        path: Routes.rideSummaryPattern,
        builder: (_, state) => RideDetailScreen(rideId: state.pathParameters['rideId']!, justFinished: true),
      ),
      GoRoute(
        path: Routes.rideDetailPattern,
        builder: (_, state) => RideDetailScreen(rideId: state.pathParameters['rideId']!),
      ),
      GoRoute(path: Routes.createGroup, builder: (_, _) => const CreateGroupScreen()),
      GoRoute(path: Routes.pendingInvites, builder: (_, _) => const PendingInvitesScreen()),
      GoRoute(
        path: Routes.groupInvitePattern,
        builder: (_, state) => InviteScreen(groupId: state.pathParameters['groupId']!),
      ),
      GoRoute(path: Routes.vehicles, builder: (_, _) => const VehiclesScreen()),
      GoRoute(path: Routes.emergencyContacts, builder: (_, _) => const EmergencyContactsScreen()),
      GoRoute(path: Routes.settings, builder: (_, _) => const SettingsScreen()),
      GoRoute(
        path: Routes.privacy,
        builder: (_, _) => const LegalScreen(title: 'Privacy policy', body: privacyPolicyPlaceholder),
      ),
      GoRoute(path: Routes.terms, builder: (_, _) => const LegalScreen(title: 'Terms', body: termsPlaceholder)),
      GoRoute(path: Routes.about, builder: (_, _) => const AboutScreen()),
      GoRoute(path: Routes.usage, builder: (_, _) => const UsageScreen()),
      StatefulShellRoute.indexedStack(
        builder: (_, _, navigationShell) => AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(routes: [GoRoute(path: Routes.map, builder: (_, _) => const MapScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: Routes.groups, builder: (_, _) => const GroupsScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: Routes.history, builder: (_, _) => const HistoryScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: Routes.profile, builder: (_, _) => const ProfileScreen())]),
        ],
      ),
    ],
  );

  ref.onDispose(() {
    refresh.dispose();
    router.dispose();
  });
  return router;
}

/// Gates, in order: signed in → profile loaded → username chosen → app.
String? _redirect(Ref ref, String location) {
  if (ref.read(currentUserProvider) == null) {
    return Routes.signedOut.contains(location) ? null : Routes.signIn;
  }

  // Splash covers the first load and load failures (it offers a retry).
  final profile = ref.read(myProfileProvider);
  if (!profile.hasValue) return location == Routes.splash ? null : Routes.splash;

  if (!(profile.value?.hasUsername ?? false)) {
    return location == Routes.chooseUsername ? null : Routes.chooseUsername;
  }

  const gateRoutes = {Routes.splash, Routes.chooseUsername, ...Routes.signedOut};
  return gateRoutes.contains(location) ? Routes.map : null;
}
