import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart' hide Position;
import 'package:go_router/go_router.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/theme/app_colors.dart';
import '../../domain/models/retrieved_place.dart';
import '../../domain/models/route_result.dart';
import 'application/location_controller.dart';
import 'application/ride_planning_controller.dart';

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

class _MapView extends ConsumerStatefulWidget {
  const _MapView();

  @override
  ConsumerState<_MapView> createState() => _MapViewState();
}

class _MapViewState extends ConsumerState<_MapView> {
  CircleAnnotationManager? _circleAnnotationManager;
  PolylineAnnotationManager? _polylineAnnotationManager;

  Future<void> _onMapCreated(MapboxMap mapboxMap) async {
    mapboxMap.location.updateSettings(LocationComponentSettings(enabled: true, pulsingEnabled: true));
    _circleAnnotationManager = await mapboxMap.annotations.createCircleAnnotationManager();
    _polylineAnnotationManager = await mapboxMap.annotations.createPolylineAnnotationManager();
  }

  Future<void> _showDestinationPin(RetrievedPlace place) async {
    final manager = _circleAnnotationManager;
    if (manager == null) return;
    await manager.deleteAll();
    await manager.create(
      CircleAnnotationOptions(
        geometry: Point(coordinates: Position(place.longitude, place.latitude)),
        circleRadius: 9,
        circleColor: AppColors.primaryAccent.toARGB32(),
        circleStrokeColor: Colors.white.toARGB32(),
        circleStrokeWidth: 2,
      ),
    );
  }

  Future<void> _clearDestinationPin() async {
    await _circleAnnotationManager?.deleteAll();
  }

  Future<void> _showRoute(RouteResult route) async {
    final manager = _polylineAnnotationManager;
    if (manager == null) return;
    await manager.deleteAll();
    await manager.create(
      PolylineAnnotationOptions(
        geometry: LineString(coordinates: route.coordinates.map((c) => Position(c.$1, c.$2)).toList()),
        lineColor: AppColors.primaryAccent.toARGB32(),
        lineWidth: 5,
      ),
    );
  }

  Future<void> _clearRoute() async {
    await _polylineAnnotationManager?.deleteAll();
  }

  Future<void> _openSearch() async {
    final place = await context.push<RetrievedPlace>('/map/search');
    if (place != null) {
      ref.read(ridePlanningControllerProvider.notifier).selectDestination(place);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    ref.listen(ridePlanningControllerProvider, (previous, next) {
      switch (next) {
        case RidePlanIdle():
          _clearDestinationPin();
          _clearRoute();
        case RidePlanPendingConfirm(:final destination):
          _showDestinationPin(destination);
          _clearRoute();
        case RidePlanFetchingRoute():
          break;
        case RidePlanRoutePreview(:final route):
          _showRoute(route);
        case RidePlanError():
          break;
      }
    });

    final planState = ref.watch(ridePlanningControllerProvider);

    return Stack(
      children: [
        MapWidget(
          key: const ValueKey('brodie-map'),
          styleUri: isDark ? MapboxStyles.DARK : MapboxStyles.MAPBOX_STREETS,
          viewport: const FollowPuckViewportState(),
          onMapCreated: _onMapCreated,
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _SearchBar(onTap: _openSearch),
            ),
          ),
        ),
        if (planState is! RidePlanIdle)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(top: false, child: _RidePlanCard(state: planState)),
          ),
      ],
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      elevation: 2,
      borderRadius: BorderRadius.circular(28),
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(Icons.search, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
              const SizedBox(width: 12),
              Text(
                'Search destination',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RidePlanCard extends ConsumerWidget {
  const _RidePlanCard({required this.state});

  final RidePlanState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final controller = ref.read(ridePlanningControllerProvider.notifier);

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: switch (state) {
          RidePlanPendingConfirm(:final destination) => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(destination.name, style: theme.textTheme.titleMedium),
                if (destination.fullAddress != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    destination.fullAddress!,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(onPressed: controller.cancel, child: const Text('Cancel')),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(onPressed: controller.confirm, child: const Text('Confirm')),
                    ),
                  ],
                ),
              ],
            ),
          RidePlanFetchingRoute(:final destination) => Row(
              children: [
                const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                const SizedBox(width: 16),
                Expanded(child: Text('Getting route to ${destination.name}…')),
              ],
            ),
          RidePlanRoutePreview(:final destination, :final route) => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(destination.name, style: theme.textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  '${(route.distanceMeters / 1000).toStringAsFixed(1)} km · '
                  '${(route.durationSeconds / 60).round()} min',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.7)),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(onPressed: controller.cancel, child: const Text('Cancel')),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Ride tracking is coming in a later phase.')),
                          );
                        },
                        child: const Text('Start Ride'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          RidePlanError(:final message) => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Could not get route', style: theme.textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(message, style: theme.textTheme.bodySmall),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(onPressed: controller.cancel, child: const Text('Dismiss')),
                ),
              ],
            ),
          RidePlanIdle() => const SizedBox.shrink(),
        },
      ),
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
