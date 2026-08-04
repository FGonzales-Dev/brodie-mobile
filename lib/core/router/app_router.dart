import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/auth/choose_username_screen.dart';
import '../../features/auth/sign_in_screen.dart';
import '../../features/auth/sign_up_screen.dart';
import '../../features/groups/create_group_screen.dart';
import '../../features/groups/groups_screen.dart';
import '../../features/groups/invite_screen.dart';
import '../../features/groups/pending_invites_screen.dart';
import '../../features/history/history_screen.dart';
import '../../features/map/destination_search_screen.dart';
import '../../features/map/map_screen.dart';
import '../../features/profile/about_screen.dart';
import '../../features/profile/emergency_contacts_screen.dart';
import '../../features/profile/legal_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/profile/settings_screen.dart';
import '../../features/profile/vehicles_screen.dart';
import '../../shared/widgets/app_shell.dart';
import 'go_router_refresh_stream.dart';
import 'profile_gate.dart';

const _authRoutes = {'/sign-in', '/sign-up'};
const _usernameRoute = '/choose-username';

final GoRouter appRouter = GoRouter(
  initialLocation: '/sign-in',
  refreshListenable: Listenable.merge([
    GoRouterRefreshStream(Supabase.instance.client.auth.onAuthStateChange),
    ProfileGate.instance,
  ]),
  redirect: (context, state) {
    final isSignedIn = Supabase.instance.client.auth.currentSession != null;
    final isOnAuthRoute = _authRoutes.contains(state.matchedLocation);

    if (!isSignedIn) {
      return isOnAuthRoute ? null : '/sign-in';
    }

    // Signed in from here on — default-deny app access until a username is
    // confirmed set (treats "still checking" the same as "not set yet").
    if (ProfileGate.instance.hasUsername != true) {
      return state.matchedLocation == _usernameRoute ? null : _usernameRoute;
    }

    if (isOnAuthRoute || state.matchedLocation == _usernameRoute) return '/map';
    return null;
  },
  routes: [
    GoRoute(path: '/sign-in', builder: (context, state) => const SignInScreen()),
    GoRoute(path: '/sign-up', builder: (context, state) => const SignUpScreen()),
    GoRoute(path: _usernameRoute, builder: (context, state) => const ChooseUsernameScreen()),
    GoRoute(path: '/map/search', builder: (context, state) => const DestinationSearchScreen()),
    GoRoute(path: '/groups/create', builder: (context, state) => const CreateGroupScreen()),
    GoRoute(path: '/groups/invites', builder: (context, state) => const PendingInvitesScreen()),
    GoRoute(
      path: '/groups/:groupId/invite',
      builder: (context, state) => InviteScreen(
        groupId: state.pathParameters['groupId']!,
        inviteCode: state.extra as String,
      ),
    ),
    GoRoute(path: '/profile/vehicles', builder: (context, state) => const VehiclesScreen()),
    GoRoute(
      path: '/profile/emergency-contacts',
      builder: (context, state) => const EmergencyContactsScreen(),
    ),
    GoRoute(path: '/profile/settings', builder: (context, state) => const SettingsScreen()),
    GoRoute(
      path: '/profile/privacy',
      builder: (context, state) => const LegalScreen(title: 'Privacy Policy', body: privacyPolicyPlaceholder),
    ),
    GoRoute(
      path: '/profile/terms',
      builder: (context, state) => const LegalScreen(title: 'Terms', body: termsPlaceholder),
    ),
    GoRoute(path: '/profile/about', builder: (context, state) => const AboutScreen()),
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) => AppShell(navigationShell: navigationShell),
      branches: [
        StatefulShellBranch(
          routes: [GoRoute(path: '/map', builder: (context, state) => const MapScreen())],
        ),
        StatefulShellBranch(
          routes: [GoRoute(path: '/groups', builder: (context, state) => const GroupsScreen())],
        ),
        StatefulShellBranch(
          routes: [GoRoute(path: '/history', builder: (context, state) => const HistoryScreen())],
        ),
        StatefulShellBranch(
          routes: [GoRoute(path: '/profile', builder: (context, state) => const ProfileScreen())],
        ),
      ],
    ),
  ],
);
