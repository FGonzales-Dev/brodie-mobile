import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import '../../../app/router/routes.dart';
import '../../../core/design_system/design_system.dart';
import '../../../core/di/core_providers.dart';
import '../../../core/presentation/refresh_on_resume.dart';
import '../../profile/application/my_profile_provider.dart';
import '../application/location_access_controller.dart';
import '../application/my_location_providers.dart';
import '../domain/map_models.dart';
import 'ride_planning_controller.dart';
import 'widgets/location_status_chip.dart';
import 'widgets/map_ornaments.dart';
import 'widgets/map_search_bar.dart';
import 'widgets/my_position_marker.dart';
import 'widgets/route_layers.dart';
import 'widgets/route_preview_sheet.dart';

class MapScreen extends ConsumerWidget {
  const MapScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(mapboxAccessTokenProvider).isEmpty) {
      return const Scaffold(
        body: SafeArea(
          child: EmptyState(
            icon: Icons.map_outlined,
            title: 'Map not configured',
            message: 'Add MAPBOX_ACCESS_TOKEN to .env, rerun build_runner, then rebuild the app.',
          ),
        ),
      );
    }
    final controller = ref.read(locationAccessControllerProvider.notifier);
    return Scaffold(
      body: RefreshOnResume(
        onResume: controller.refresh,
        child: AsyncValueView(
          value: ref.watch(locationAccessControllerProvider),
          onRetry: controller.refresh,
          data: (access) => access.isGranted ? const _MapView() : _LocationGate(access: access),
        ),
      ),
    );
  }
}

/// Explains why location is needed and offers the action that unblocks it.
class _LocationGate extends ConsumerWidget {
  const _LocationGate({required this.access});

  final LocationAccess access;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(locationAccessControllerProvider.notifier);
    final (title, message, actionLabel, onPressed) = switch (access) {
      LocationAccess.deniedForever => (
          'Location blocked',
          'Allow location for Brodie in system settings so we can show where you are and plan routes.',
          'Open settings',
          controller.openSystemSettings,
        ),
      LocationAccess.serviceDisabled => (
          'Location is off',
          'Turn on location services to see where you are and plan routes.',
          'Turn on location',
          controller.openSystemSettings,
        ),
      _ => (
          'Location needed',
          'Brodie uses your location while the app is open to show where you are and route you to your destination.',
          'Allow location',
          controller.request,
        ),
    };
    return SafeArea(
      child: EmptyState(
        icon: Icons.location_on_outlined,
        title: title,
        message: message,
        action: BrodieButton(label: actionLabel, icon: Icons.my_location, onPressed: onPressed),
      ),
    );
  }
}

class _MapView extends ConsumerStatefulWidget {
  const _MapView();

  @override
  ConsumerState<_MapView> createState() => _MapViewState();
}

/// What the camera shows: the rider's last fetched position, the planned
/// route, or wherever the rider panned or zoomed it.
enum _CameraMode { myPosition, routeOverview, free }

class _MapViewState extends ConsumerState<_MapView> {
  static const _zoom = 15.0;
  static const _routePadding = EdgeInsets.fromLTRB(48, 140, 48, 340);

  final _layers = RouteLayers();
  final _me = MyPositionMarker();
  final _ornaments = MapOrnaments();
  final _topPanel = GlobalKey();
  final _bottomPanel = GlobalKey();
  var _cameraMode = _CameraMode.myPosition;

  // Viewport objects are only recreated when what they show changes: the map
  // restarts its camera animation whenever it receives a different one.
  CameraViewportState? _startingView; // before the first fix
  CameraViewportState? _myPositionView; // at the last fetched fix
  GeoFix? _myPositionFix;
  OverviewViewportState? _routeOverview;

  ViewportState get _viewport => switch (_cameraMode) {
        _CameraMode.myPosition => _myPositionView ?? _startingView!,
        _CameraMode.routeOverview => _routeOverview ?? _myPositionView ?? _startingView!,
        _CameraMode.free => const IdleViewportState(),
      };

  void _onPlanChanged(RidePlanState plan) {
    _render(plan);
    switch (plan) {
      case RidePlanPreview(:final route):
        setState(() {
          _routeOverview = OverviewViewportState(geometry: lineOf(route.path), geometryPadding: _routePadding);
          _cameraMode = _CameraMode.routeOverview;
        });
      case RidePlanIdle():
        setState(() {
          _routeOverview = null;
          _cameraMode = _CameraMode.myPosition;
        });
      case RidePlanLoading() || RidePlanError():
        break;
    }
  }

  void _onUserMovedMap() {
    if (_cameraMode != _CameraMode.free) setState(() => _cameraMode = _CameraMode.free);
  }

  /// Fetches a fresh fix and moves the camera to it. Failures show in the
  /// status chip under the search bar.
  Future<void> _refreshMyLocation() async {
    setState(() => _cameraMode = _CameraMode.myPosition);
    try {
      await ref.read(myLocationControllerProvider.notifier).refresh();
    } catch (_) {
      // Shown by LocationStatusChip.
    }
  }

  /// The best position known before a fresh fix, or the whole world.
  static CameraViewportState _viewAt(GeoPoint? center) => center == null
      ? CameraViewportState(center: Point(coordinates: Position(0, 20)), zoom: 1.2)
      : CameraViewportState(center: Point(coordinates: positionOf(center)), zoom: _zoom);

  Future<void> _onMapCreated(MapboxMap map) async {
    // The live location puck stays off on the home map; the rider's position
    // is the dot drawn from the last fetched fix (see MyLocationController).
    await map.location.updateSettings(LocationComponentSettings(enabled: false));
    await _layers.attach(map);
    await _me.attach(map);
    await _ornaments.attach(map);
    if (!mounted) return;
    _syncOrnaments();
    await _render(ref.read(ridePlanningControllerProvider));
    await _me.show(ref.read(myLocationControllerProvider).value?.position);
  }

  /// Draws the destination pin and, once fetched, the route line for [state].
  Future<void> _render(RidePlanState state) {
    final (destination, route) = switch (state) {
      RidePlanLoading(:final destination) || RidePlanError(:final destination) => (destination, null),
      RidePlanPreview(:final destination, :final route) => (destination, route),
      RidePlanIdle() => (null, null),
    };
    return _layers.show(colors: context.colors, path: route?.path, pin: destination?.location);
  }

  /// Moves Mapbox's logo, attribution and compass clear of the panels.
  void _syncOrnaments() {
    if (mounted) _ornaments.keepClear(top: heightOf(_topPanel), bottom: heightOf(_bottomPanel));
  }

  Future<void> _openSearch() async {
    final place = await context.push<Place>(Routes.destinationSearch);
    if (place != null) ref.read(ridePlanningControllerProvider.notifier).selectDestination(place);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(ridePlanningControllerProvider, (_, next) => _onPlanChanged(next));
    ref.listen(myLocationControllerProvider.select((location) => location.value), (_, fix) => _me.show(fix?.position));

    final initialCenter = ref.watch(initialMapCenterProvider);
    if (_startingView == null && initialCenter.isLoading) return const LoadingState();
    _startingView ??= _viewAt(initialCenter.value);

    final myLocation = ref.watch(myLocationControllerProvider);
    final fix = myLocation.value;
    if (fix != null && fix != _myPositionFix) {
      _myPositionFix = fix;
      _myPositionView = _viewAt(fix.position);
    }

    final plan = ref.watch(ridePlanningControllerProvider);
    final username = ref.watch(myProfileProvider).value?.username ?? '';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Panels change height (route sheet, status chip); re-place the overlays.
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncOrnaments());
    return Stack(
      children: [
        MapWidget(
          key: const ValueKey('brodie-map'),
          styleUri: isDark ? MapboxStyles.DARK : MapboxStyles.LIGHT,
          viewport: _viewport,
          onMapCreated: _onMapCreated,
          onScrollListener: (_) => _onUserMovedMap(),
          onZoomListener: (_) => _onUserMovedMap(),
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            key: _topPanel,
            child: Padding(
              padding: const EdgeInsets.all(BrodieSpace.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  MapSearchBar(onTap: _openSearch, avatarName: username),
                  const SizedBox(height: BrodieSpace.xs),
                  const LocationStatusChip(),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Column(
            key: _bottomPanel,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.all(BrodieSpace.md),
                  child: BrodieIconButton(
                    icon: Icons.my_location,
                    tooltip: 'Refresh my location',
                    isLoading: myLocation.isLoading,
                    onPressed: _refreshMyLocation,
                  ),
                ),
              ),
              if (plan is! RidePlanIdle) RoutePreviewSheet(state: plan),
            ],
          ),
        ),
      ],
    );
  }
}
