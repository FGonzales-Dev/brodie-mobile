import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design_system/design_system.dart';
import '../../../../core/utils/units.dart';
import '../../../settings/application/settings_controller.dart';
import '../../domain/map_models.dart';
import '../../domain/route_rejoin.dart';
import '../../domain/route_tracker.dart';

/// "Off route: the route is 240 m to your right." Shown on the ride screens
/// while the rider is away from the route; worked out on the phone, so it
/// costs no Directions request. [advice] is the screen's next step.
class RejoinRouteAlert extends ConsumerWidget {
  const RejoinRouteAlert({super.key, required this.progress, required this.lastFix, required this.advice});

  final RideProgress? progress;
  final GeoFix? lastFix;
  final String advice;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = this.progress;
    if (progress == null || !RouteRejoin.isOffRoute(progress)) return const SizedBox.shrink();
    final units = ref.watch(settingsControllerProvider.select((settings) => settings.units));
    final distance = formatShortDistance(progress.distanceFromRouteMeters, units).text;
    return BrodieAlert(
      icon: Icons.alt_route,
      color: context.colors.warning,
      title: 'Off route',
      message: 'The route is $distance ${rejoinDirection(progress, lastFix)}. $advice',
    );
  }
}
