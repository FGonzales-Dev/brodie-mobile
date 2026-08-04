import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:permission_handler/permission_handler.dart';

import 'application/location_controller.dart';

class MapScreen extends ConsumerWidget {
  const MapScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final permissionAsync = ref.watch(locationPermissionControllerProvider);

    return Scaffold(
      body: permissionAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Could not check location permission: $error')),
        data: (permission) {
          switch (permission) {
            case LocationPermission.always:
            case LocationPermission.whileInUse:
              return const _MapView();
            case LocationPermission.deniedForever:
              return _PermissionRationale(
                message: 'Location access is permanently denied. Enable it in system settings to navigate.',
                buttonLabel: 'Open Settings',
                onPressed: openAppSettings,
              );
            case LocationPermission.denied:
            case LocationPermission.unableToDetermine:
              return _PermissionRationale(
                message:
                    'Brodie uses your location while the app is open to show your position and route you to your destination.',
                buttonLabel: 'Allow Location Access',
                onPressed: () => ref.read(locationPermissionControllerProvider.notifier).request(),
              );
          }
        },
      ),
    );
  }
}

class _MapView extends StatelessWidget {
  const _MapView();

  void _onMapCreated(MapboxMap mapboxMap) {
    mapboxMap.location.updateSettings(LocationComponentSettings(enabled: true, pulsingEnabled: true));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return MapWidget(
      key: const ValueKey('brodie-map'),
      styleUri: isDark ? MapboxStyles.DARK : MapboxStyles.MAPBOX_STREETS,
      viewport: const FollowPuckViewportState(),
      onMapCreated: _onMapCreated,
    );
  }
}

class _PermissionRationale extends StatelessWidget {
  const _PermissionRationale({required this.message, required this.buttonLabel, required this.onPressed});

  final String message;
  final String buttonLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.location_on_outlined, size: 48),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 24),
            FilledButton(onPressed: onPressed, child: Text(buttonLabel)),
          ],
        ),
      ),
    );
  }
}
