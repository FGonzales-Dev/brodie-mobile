import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/design_system/design_system.dart';
import '../features/history/presentation/pending_ride_uploader.dart';

/// Bottom-nav scaffold for the four root tabs (tech spec section 7).
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const _tabs = [
    BrodieNavItem(icon: Icons.map_outlined, label: 'Map'),
    BrodieNavItem(icon: Icons.groups_outlined, label: 'Groups'),
    BrodieNavItem(icon: Icons.history, label: 'History'),
    BrodieNavItem(icon: Icons.person_outline, label: 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PendingRideUploader(child: navigationShell),
      bottomNavigationBar: BrodieBottomNav(
        items: _tabs,
        currentIndex: navigationShell.currentIndex,
        // Re-tapping the current tab returns it to its root.
        onSelected: (index) => navigationShell.goBranch(index, initialLocation: index == navigationShell.currentIndex),
      ),
    );
  }
}
