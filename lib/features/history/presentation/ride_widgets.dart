import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import '../../../core/design_system/design_system.dart';
import '../../../core/utils/units.dart';
import '../../map/domain/map_models.dart';
import '../../map/presentation/widgets/route_layers.dart';
import '../../settings/application/settings_controller.dart';
import '../domain/ride.dart';

String rideTitle(Ride ride) => ride.destinationName ?? 'Ride';

/// Date and start time, e.g. "Sat, Nov 2 · 8:04 AM".
String rideStartLabel(BuildContext context, Ride ride) {
  final localizations = MaterialLocalizations.of(context);
  final time = localizations.formatTimeOfDay(TimeOfDay.fromDateTime(ride.startedAt));
  return '${localizations.formatMediumDate(ride.startedAt)} · $time';
}

/// The route ridden, framed to fit. Not interactive, so it can sit inside a
/// scrolling page.
class RideRouteMap extends StatefulWidget {
  const RideRouteMap({super.key, required this.path});

  final List<GeoPoint> path;

  @override
  State<RideRouteMap> createState() => _RideRouteMapState();
}

class _RideRouteMapState extends State<RideRouteMap> {
  final _layers = RouteLayers();

  Future<void> _onMapCreated(MapboxMap map) async {
    await map.location.updateSettings(LocationComponentSettings(enabled: false));
    await map.scaleBar.updateSettings(ScaleBarSettings(enabled: false));
    await _layers.attach(map);
    if (!mounted) return;
    await _layers.show(colors: context.colors, path: widget.path, pin: widget.path.last);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return IgnorePointer(
      child: MapWidget(
        styleUri: isDark ? MapboxStyles.DARK : MapboxStyles.LIGHT,
        viewport: OverviewViewportState(
          geometry: lineOf(widget.path),
          geometryPadding: const EdgeInsets.all(BrodieSpace.xl),
        ),
        onMapCreated: _onMapCreated,
      ),
    );
  }
}

/// Distance and moving time, then average and top speed.
class RideStats extends ConsumerWidget {
  const RideStats({super.key, required this.ride});

  final Ride ride;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final units = ref.watch(settingsControllerProvider.select((settings) => settings.units));
    final distance = formatDistance(ride.distanceMeters, units);
    final moving = formatDuration(ride.movingTime);
    final average = formatSpeed(ride.averageSpeedMps, units);
    final top = formatSpeed(ride.maxSpeedMps, units);

    return Column(
      children: [
        Row(
          children: [
            Expanded(child: StatTile(value: distance.value, unit: distance.unit)),
            const SizedBox(width: BrodieSpace.xs),
            Expanded(child: StatTile(value: moving.value, unit: '${moving.unit} moving')),
          ],
        ),
        const SizedBox(height: BrodieSpace.xs),
        Row(
          children: [
            Expanded(child: StatTile(value: average.value, unit: 'avg ${average.unit}')),
            const SizedBox(width: BrodieSpace.xs),
            Expanded(child: StatTile(value: top.value, unit: 'top ${top.unit}')),
          ],
        ),
      ],
    );
  }
}
