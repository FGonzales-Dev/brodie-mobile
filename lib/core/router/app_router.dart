import 'package:go_router/go_router.dart';

import '../../features/groups/groups_screen.dart';
import '../../features/history/history_screen.dart';
import '../../features/map/map_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../shared/widgets/app_shell.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/map',
  routes: [
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
