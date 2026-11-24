import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import '../../../../app/router/routes.dart';
import '../../../../core/design_system/design_system.dart';
import '../../../../core/errors/app_failure.dart';
import '../../../../core/presentation/feedback.dart';
import '../../../../core/presentation/keep_screen_on.dart';
import '../../../history/application/ride_providers.dart';
import '../../../sos/presentation/widgets/sos_button.dart';
import '../ride_planning_controller.dart';
import '../widgets/location_issue_banner.dart';
import '../widgets/map_ornaments.dart';
import '../widgets/ride_map_buttons.dart';
import '../widgets/ride_route_line.dart';
import '../widgets/route_layers.dart';
import 'ride_panels.dart';
import 'solo_ride_controller.dart';

/// Full-screen riding view (no tab bar, per the spec's "ride mode"): the map
/// follows the rider heading-up, with the next turn on top and speed, distance
/// and arrival time below. The screen stays awake for the whole ride.
class SoloRideScreen extends ConsumerStatefulWidget {
  const SoloRideScreen({super.key});

  @override
  ConsumerState<SoloRideScreen> createState() => _SoloRideScreenState();
}

class _SoloRideScreenState extends ConsumerState<SoloRideScreen> {
  // Heading-up and tilted, like a dashboard display.
  static const _followRider = FollowPuckViewportState(
    zoom: 16.5,
    bearing: FollowPuckViewportStateBearingCourse(),
    pitch: 45,
  );

  final _routeLine = RideRouteLine();
  MapboxMap? _map;
  final _ornaments = MapOrnaments();
  final _topPanel = GlobalKey();
  final _bottomPanel = GlobalKey();
  var _following = true;

  /// The rider may have turned location back on in system settings.
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onResume: () => ref.read(soloRideControllerProvider.notifier).recheckLocation(),
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  Future<void> _onMapCreated(MapboxMap map) async {
    _map = map;
    // Place the camera on the rider now: until the map's own location puck
    // has a position, following it would leave the camera on the style's
    // default view (New York). Follow mode takes over once the puck moves.
    final ride = ref.read(soloRideControllerProvider);
    if (ride != null) {
      await map.setCamera(
        CameraOptions(
          center: Point(coordinates: positionOf(ride.lastFix?.position ?? ride.route.path.first)),
          zoom: _followRider.zoom,
          pitch: _followRider.pitch,
        ),
      );
    }
    await map.location.updateSettings(
      LocationComponentSettings(enabled: true, puckBearingEnabled: true, puckBearing: PuckBearing.COURSE),
    );
    await _ornaments.attach(map);
    if (!mounted) return;
    _syncOrnaments();
    // The style may have finished loading while the camera was being set.
    if (await map.style.isStyleLoaded()) await _attachRoute();
  }

  /// Also runs on every later style switch (light/dark), which drops the
  /// route layers.
  void _onStyleLoaded(StyleLoadedEventData _) => _attachRoute();

  Future<void> _attachRoute() async {
    final map = _map;
    if (map == null || !mounted) return;
    await _routeLine.attach(map, colors: context.colors);
    await _drawRoute();
  }

  Future<void> _drawRoute() async {
    final ride = ref.read(soloRideControllerProvider);
    if (ride == null) return;
    await _routeLine.show(path: ride.route.path, destination: ride.destination.location);
    await _routeLine.trimTo(ride.progress?.fractionRidden ?? 0);
  }

  /// Moves Mapbox's logo, attribution and compass clear of the panels.
  void _syncOrnaments() {
    if (mounted) _ornaments.keepClear(top: heightOf(_topPanel), bottom: heightOf(_bottomPanel));
  }

  void _stopFollowing() {
    if (_following) setState(() => _following = false);
  }

  Future<void> _confirmEnd() async {
    final confirmed = await showBrodieConfirmDialog(
      context,
      title: 'End ride?',
      message: "You haven't reached your destination yet.",
      confirmLabel: 'End ride',
    );
    if (confirmed && mounted) _endRide();
  }

  /// Saves the ride and shows its summary in place of this screen. Saving
  /// carries on in the background; the summary shows whether it uploaded.
  void _endRide() {
    final arrived = ref.read(soloRideControllerProvider)?.arrived ?? false;
    final ride = ref.read(soloRideControllerProvider.notifier).finish();
    // An early end keeps the plan, so the rider can start the same route again.
    if (arrived) ref.read(ridePlanningControllerProvider.notifier).clear();

    if (ride == null) {
      context
        ..pop()
        ..showMessage('Ride too short to save.');
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    unawaited(
      ref.read(rideSyncProvider.notifier).save(ride).catchError((Object error) {
        messenger.showSnackBar(SnackBar(content: Text(AppFailure.messageFor(error))));
        return false;
      }),
    );
    context.pushReplacement(Routes.rideSummary(ride.id));
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(soloRideControllerProvider.select((ride) => ride?.route), (previous, next) {
      if (previous != null && next != previous) _drawRoute();
    });
    ref.listen(soloRideControllerProvider.select((ride) => ride?.progress?.fractionRidden), (_, ridden) {
      if (ridden != null) _routeLine.trimTo(ridden);
    });
    ref.listen(soloRideControllerProvider.select((ride) => ride?.arrived ?? false), (wasArrived, arrived) {
      if (arrived && wasArrived == false) HapticFeedback.heavyImpact();
    });

    final ride = ref.watch(soloRideControllerProvider);
    if (ride == null) {
      return Scaffold(
        body: SafeArea(
          child: EmptyState(
            icon: Icons.route_outlined,
            title: 'No route to ride',
            message: 'Pick a destination on the map first.',
            action: BrodieButton(label: 'Back to map', onPressed: () => context.pop()),
          ),
        ),
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Panels change height (notices, arrival); re-place the overlays.
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncOrnaments());
    return PopScope(
      // Back ends the ride, so it's saved either way.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        ride.arrived ? _endRide() : _confirmEnd();
      },
      child: KeepScreenOn(
        child: Scaffold(
          body: Stack(
            children: [
              MapWidget(
                key: const ValueKey('ride-map'),
                styleUri: isDark ? MapboxStyles.DARK : MapboxStyles.LIGHT,
                viewport: _following ? _followRider : const IdleViewportState(),
                onMapCreated: _onMapCreated,
                onStyleLoadedListener: _onStyleLoaded,
                onScrollListener: (_) => _stopFollowing(),
                onZoomListener: (_) => _stopFollowing(),
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
                        ManeuverBanner(ride: ride),
                        LocationIssueBanner(
                          lastFix: ride.lastFix,
                          accessLost: ride.locationLost,
                          startedAt: ride.startedAt,
                        ),
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
                    RideMapButtons(
                      leading: SosButton(onPressed: () => context.push(Routes.sos, extra: ride.lastFix)),
                      following: _following,
                      onFollow: () => setState(() => _following = true),
                    ),
                    if (ride.arrived)
                      ArrivalPanel(ride: ride, onDone: _endRide)
                    else
                      RideHud(
                        ride: ride,
                        onEnd: _confirmEnd,
                        onReroute: ref.read(soloRideControllerProvider.notifier).reroute,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
