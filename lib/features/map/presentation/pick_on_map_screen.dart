import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import '../../../core/design_system/design_system.dart';
import '../application/my_location_providers.dart';
import '../domain/map_models.dart';
import 'widgets/route_layers.dart';

/// A destination picked by moving the map under a crosshair. Needs no place
/// search, so it costs nothing against the daily search limit.
Place pinnedPlace(GeoPoint point) => Place(
  name: 'Pinned spot',
  address: '${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}',
  location: point,
);

/// Pops the chosen [Place], or nothing if the rider backs out.
class PickOnMapScreen extends ConsumerStatefulWidget {
  const PickOnMapScreen({super.key});

  @override
  ConsumerState<PickOnMapScreen> createState() => _PickOnMapScreenState();
}

class _PickOnMapScreenState extends ConsumerState<PickOnMapScreen> {
  static const _zoom = 15.0;
  MapboxMap? _map;

  /// Set once: a new viewport would move the camera while the rider drags.
  ViewportState? _startView;

  Future<void> _useThisSpot() async {
    final map = _map;
    if (map == null) return;
    final center = (await map.getCameraState()).center.coordinates;
    if (!mounted) return;
    context.pop(pinnedPlace(GeoPoint(latitude: center.lat.toDouble(), longitude: center.lng.toDouble())));
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final initialCenter = ref.watch(initialMapCenterProvider);
    if (_startView == null && initialCenter.isLoading) {
      return const Scaffold(
        appBar: BrodieAppBar(title: 'Choose on map'),
        body: LoadingState(),
      );
    }
    final start = ref.read(myLocationControllerProvider).value?.position ?? initialCenter.value;
    _startView ??= start == null
        ? CameraViewportState(center: Point(coordinates: Position(0, 20)), zoom: 1.2)
        : CameraViewportState(
            center: Point(coordinates: positionOf(start)),
            zoom: _zoom,
          );
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: const BrodieAppBar(title: 'Choose on map'),
      body: Stack(
        children: [
          MapWidget(
            key: const ValueKey('pick-on-map'),
            styleUri: isDark ? MapboxStyles.DARK : MapboxStyles.LIGHT,
            viewport: _startView,
            onMapCreated: (map) async {
              _map = map;
              await map.location.updateSettings(LocationComponentSettings(enabled: false));
            },
          ),
          // The spot is the map's center; the pin's tip sits on it.
          IgnorePointer(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 44),
                child: Icon(Icons.location_on, size: 48, color: colors.accent, shadows: const [Shadow(blurRadius: 6)]),
              ),
            ),
          ),
          Positioned(
            left: BrodieSpace.md,
            right: BrodieSpace.md,
            top: BrodieSpace.md,
            child: BrodieAlert(
              icon: Icons.pan_tool_alt_outlined,
              color: colors.accent,
              message: 'Move the map until the pin is on your destination.',
              margin: EdgeInsets.zero,
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(BrodieSpace.md),
          child: BrodieButton(label: 'Use this spot', icon: Icons.check, onPressed: _useThisSpot),
        ),
      ),
    );
  }
}
