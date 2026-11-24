import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../features/auth/application/session_providers.dart';
import '../../features/auth/presentation/choose_username_screen.dart';
import '../../features/auth/presentation/sign_in_screen.dart';
import '../../features/auth/presentation/sign_up_screen.dart';
import '../../features/emergency_contacts/presentation/emergency_contacts_screen.dart';
import '../../features/group_ride/presentation/group_ride_screen.dart';
import '../../features/groups/presentation/create_group_screen.dart';
import '../../features/groups/presentation/group_ride_summary_screen.dart';
import '../../features/groups/presentation/group_screen.dart';
import '../../features/groups/presentation/groups_screen.dart';
import '../../features/groups/presentation/invite_screen.dart';
import '../../features/groups/presentation/join_group_screen.dart';
import '../../features/groups/presentation/pending_invites_screen.dart';
import '../../features/history/presentation/history_screen.dart';
import '../../features/history/presentation/ride_detail_screen.dart';
import '../../features/map/presentation/destination_search_screen.dart';
import '../../features/map/presentation/map_screen.dart';
import '../../features/map/presentation/solo_ride/solo_ride_screen.dart';
import '../../features/onboarding/data/onboarding_store.dart';
import '../../features/onboarding/presentation/onboarding_screen.dart';
import '../../features/profile/application/my_profile_provider.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/map/domain/map_models.dart';
import '../../features/settings/domain/legal_documents.dart';
import '../../features/settings/presentation/info_screens.dart';
import '../../features/sos/presentation/sos_screen.dart';
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
  final pending = _PendingLink();
  ref
    ..listen(currentUserProvider, (_, _) => refresh.value++)
    ..listen(myProfileProvider, (_, _) => refresh.value++)
    ..listen(onboardingDoneProvider, (_, _) => refresh.value++);

  final router = GoRouter(
    initialLocation: Routes.splash,
    refreshListenable: refresh,
    redirect: (_, state) => _redirect(ref, state.matchedLocation, pending),
    routes: [
      GoRoute(path: Routes.splash, builder: (_, _) => const SplashScreen()),
      GoRoute(path: Routes.signIn, builder: (_, _) => const SignInScreen()),
      GoRoute(path: Routes.signUp, builder: (_, _) => const SignUpScreen()),
      GoRoute(path: Routes.chooseUsername, builder: (_, _) => const ChooseUsernameScreen()),
      GoRoute(path: Routes.welcome, builder: (_, _) => const OnboardingScreen()),
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
      GoRoute(path: Routes.joinWithCode, builder: (_, _) => const JoinWithCodeScreen()),
      GoRoute(
        path: Routes.joinPattern,
        builder: (_, state) => JoinGroupScreen(code: state.pathParameters['code']!),
      ),
      // After the fixed /groups/... paths above, which this pattern would also match.
      GoRoute(
        path: Routes.groupPattern,
        builder: (_, state) => GroupScreen(groupId: state.pathParameters['groupId']!),
      ),
      GoRoute(
        path: Routes.groupInvitePattern,
        builder: (_, state) => InviteScreen(groupId: state.pathParameters['groupId']!),
      ),
      GoRoute(
        path: Routes.groupRidePattern,
        builder: (_, state) => GroupRideScreen(groupId: state.pathParameters['groupId']!),
      ),
      GoRoute(
        path: Routes.groupRideSummaryPattern,
        builder: (_, state) => GroupRideSummaryScreen(tripId: state.pathParameters['tripId']!),
      ),
      GoRoute(
        path: Routes.sos,
        builder: (_, state) => SosScreen(
          groupId: state.uri.queryParameters['group'],
          lastFix: state.extra is GeoFix ? state.extra! as GeoFix : null,
        ),
      ),
      GoRoute(path: Routes.vehicles, builder: (_, _) => const VehiclesScreen()),
      GoRoute(path: Routes.emergencyContacts, builder: (_, _) => const EmergencyContactsScreen()),
      GoRoute(path: Routes.settings, builder: (_, _) => const SettingsScreen()),
      GoRoute(
        path: Routes.privacy,
        builder: (_, _) => const LegalScreen(document: privacyPolicy),
      ),
      GoRoute(
        path: Routes.terms,
        builder: (_, _) => const LegalScreen(document: termsOfUse),
      ),
      GoRoute(path: Routes.about, builder: (_, _) => const AboutScreen()),
      GoRoute(path: Routes.usage, builder: (_, _) => const UsageScreen()),
      StatefulShellRoute.indexedStack(
        builder: (_, _, navigationShell) => AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [GoRoute(path: Routes.map, builder: (_, _) => const MapScreen())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: Routes.groups, builder: (_, _) => const GroupsScreen())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: Routes.history, builder: (_, _) => const HistoryScreen())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: Routes.profile, builder: (_, _) => const ProfileScreen())],
          ),
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

/// An invite link opened before the app could show it (signed out, profile
/// still loading, or no username yet), kept until the gates pass.
class _PendingLink {
  String? location;

  String? take() {
    final taken = location;
    location = null;
    return taken;
  }
}

/// Gates, in order: signed in → profile loaded → username chosen →
/// onboarding seen (once per account on this phone) → app.
String? _redirect(Ref ref, String location, _PendingLink pending) {
  String? gate(String to, {required bool alreadyThere}) {
    if (Routes.isJoinLink(location)) pending.location = location;
    return alreadyThere ? null : to;
  }

  if (ref.read(currentUserProvider) == null) {
    return gate(Routes.signIn, alreadyThere: Routes.signedOut.contains(location));
  }

  // Splash covers the first load and load failures (it offers a retry).
  final profile = ref.read(myProfileProvider);
  if (!profile.hasValue) return gate(Routes.splash, alreadyThere: location == Routes.splash);

  if (!(profile.value?.hasUsername ?? false)) {
    return gate(Routes.chooseUsername, alreadyThere: location == Routes.chooseUsername);
  }

  if (!ref.read(onboardingDoneProvider)) {
    return gate(Routes.welcome, alreadyThere: location == Routes.welcome);
  }

  const gateRoutes = {Routes.splash, Routes.chooseUsername, Routes.welcome, ...Routes.signedOut};
  return gateRoutes.contains(location) ? (pending.take() ?? Routes.map) : null;
}
