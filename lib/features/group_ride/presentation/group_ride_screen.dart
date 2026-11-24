import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import '../../../app/router/routes.dart';
import '../../../core/design_system/design_system.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/presentation/feedback.dart';
import '../../../core/presentation/keep_screen_on.dart';
import '../../history/application/ride_providers.dart';
import '../../map/domain/map_models.dart';
import '../../map/presentation/widgets/map_ornaments.dart';
import '../../map/presentation/widgets/ride_map_buttons.dart';
import '../../map/presentation/widgets/ride_route_line.dart';
import '../../map/presentation/widgets/route_layers.dart';
import '../../sos/presentation/widgets/sos_button.dart';
import '../application/group_ride_controller.dart';
import 'group_ride_panels.dart';
import 'rider_markers.dart';

/// Full-screen group ride: the shared route, every rider live on the map,
/// who's online and who fell behind. Like a solo ride, the map follows the
/// rider heading-up and the screen stays awake.
class GroupRideScreen extends ConsumerStatefulWidget {
  const GroupRideScreen({super.key, required this.groupId});

  final String groupId;

  @override
  ConsumerState<GroupRideScreen> createState() => _GroupRideScreenState();
}

class _GroupRideScreenState extends ConsumerState<GroupRideScreen> {
  static const _followRider = FollowPuckViewportState(
    zoom: 15.5,
    bearing: FollowPuckViewportStateBearingCourse(),
    pitch: 45,
  );

  final _routeLine = RideRouteLine();
  final _riders = RiderMarkers();
  final _ornaments = MapOrnaments();
  final _topPanel = GlobalKey();
  final _bottomPanel = GlobalKey();
  MapboxMap? _map;
  var _following = true;
  var _busy = false;

  /// The rider may have turned location back on in system settings.
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: () => ref.read(_provider.notifier).recheckLocation());
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  GroupRideControllerProvider get _provider => groupRideControllerProvider(widget.groupId);

  GroupRideState? get _ride => ref.read(_provider).value;

  Future<void> _onMapCreated(MapboxMap map) async {
    _map = map;
    final ride = _ride;
    if (ride != null) {
      await map.setCamera(
        CameraOptions(
          center: Point(coordinates: positionOf(ride.lastFix?.position ?? ride.trip.route.path.first)),
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
    if (await map.style.isStyleLoaded()) await _attachLayers();
  }

  /// Also runs on every later style switch (light/dark).
  void _onStyleLoaded(StyleLoadedEventData _) => _attachLayers();

  Future<void> _attachLayers() async {
    final map = _map;
    if (map == null || !mounted) return;
    final colors = context.colors;
    await _routeLine.attach(map, colors: colors);
    await _riders.attach(map);
    final ride = _ride;
    if (ride == null || !mounted) return;
    await _routeLine.show(path: ride.trip.route.path, destination: ride.trip.destination);
    await _routeLine.trimTo(ride.progress?.fractionRidden ?? 0);
    await _riders.show(ride.others, colors: colors);
  }

  void _syncOrnaments() {
    if (mounted) _ornaments.keepClear(top: heightOf(_topPanel), bottom: heightOf(_bottomPanel));
  }

  void _stopFollowing() {
    if (_following) setState(() => _following = false);
  }

  Future<void> _showRider(LiveRider rider) async {
    final fix = rider.fix;
    final map = _map;
    if (fix == null || map == null) return;
    setState(() => _following = false);
    await map.flyTo(
      CameraOptions(
        center: Point(
          coordinates: positionOf(GeoPoint(latitude: fix.latitude, longitude: fix.longitude)),
        ),
        zoom: 15,
        bearing: 0,
        pitch: 0,
      ),
      MapAnimationOptions(duration: 600),
    );
  }

  Future<void> _confirmEndOrLeave() async {
    final ride = _ride;
    if (ride == null || ride.ended) return;
    final controller = ref.read(_provider.notifier);
    final confirmed = ride.isLeader
        ? await showBrodieConfirmDialog(
            context,
            title: 'End ride for everyone?',
            message: "Everyone's ride stops and positions are no longer shared.",
            confirmLabel: 'End ride',
          )
        : await showBrodieConfirmDialog(
            context,
            title: 'Leave ride?',
            message: 'Your group stops seeing where you are. You can join again from the group while the ride is on.',
            confirmLabel: 'Leave',
          );
    if (!confirmed || !mounted) return;
    setState(() => _busy = true);
    await context.runWithFeedback(ride.isLeader ? controller.endForEveryone : controller.leave);
    if (mounted) setState(() => _busy = false);
  }

  /// Saves this rider's part of the ride and shows its summary. Saving
  /// carries on in the background; the summary shows whether it uploaded.
  void _done() {
    final ride = ref.read(_provider.notifier).rideToSave();
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
    // A new route (the leader rerouted): redraw it, and tell riders why.
    ref.listen(_provider.select((ride) => ride.value?.trip.route.version), (before, after) {
      final ride = _ride;
      if (before == null || after == null || after <= before || ride == null) return;
      _routeLine.show(path: ride.trip.route.path, destination: ride.trip.destination);
      if (!ride.isLeader) {
        HapticFeedback.heavyImpact();
        context.showMessage('Your leader changed the route');
      }
    });
    ref.listen(_provider.select((ride) => ride.value?.progress?.fractionRidden), (_, ridden) {
      if (ridden != null) _routeLine.trimTo(ridden);
    });
    ref.listen(_provider.select((ride) => ride.value?.others), (_, others) {
      if (others != null) _riders.show(others, colors: context.colors);
    });
    // A buzz when someone newly falls behind or sends an SOS, or the ride ends.
    ref.listen(_provider.select((ride) => ride.value?.behind.length ?? 0), (before, after) {
      if (after > (before ?? 0)) HapticFeedback.heavyImpact();
    });
    ref.listen(_provider.select((ride) => ride.value?.sos.length ?? 0), (before, after) {
      if (after > (before ?? 0)) HapticFeedback.vibrate();
    });
    ref.listen(_provider.select((ride) => ride.value?.ended ?? false), (wasEnded, ended) {
      if (ended && wasEnded == false) HapticFeedback.heavyImpact();
    });

    final value = ref.watch(_provider);
    if (value.hasValue) {
      final ride = value.value;
      return ride == null ? _noRide(context) : _riding(context, ride);
    }
    return Scaffold(
      appBar: const BrodieAppBar(title: 'Group ride'),
      body: AsyncValueView(value: value, onRetry: () => ref.invalidate(_provider), data: (_) => const SizedBox()),
    );
  }

  Widget _noRide(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: EmptyState(
          icon: Icons.groups_outlined,
          title: 'No ride to join',
          message: "This group's ride has ended, or you haven't joined it.",
          action: BrodieButton(label: 'Back to group', onPressed: () => context.pop()),
        ),
      ),
    );
  }

  Widget _riding(BuildContext context, GroupRideState ride) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncOrnaments());
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        ride.ended ? _done() : _confirmEndOrLeave();
      },
      child: KeepScreenOn(
        child: Scaffold(
          body: Stack(
            children: [
              MapWidget(
                key: const ValueKey('group-ride-map'),
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
                    child: GroupRideBanner(
                      ride: ride,
                      onShowRider: _showRider,
                      onImSafe: () => context.runWithFeedback(
                        ref.read(_provider.notifier).cancelSos,
                        successMessage: 'Your group knows you are safe',
                      ),
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
                      leading: ride.ended
                          ? null
                          : SosButton(
                              onPressed: () => context.push(Routes.sosFor(widget.groupId), extra: ride.lastFix),
                            ),
                      following: _following,
                      onFollow: () => setState(() => _following = true),
                    ),
                    if (ride.ended)
                      GroupRideEndedPanel(ride: ride, onDone: _done)
                    else
                      GroupRideHud(
                        ride: ride,
                        busy: _busy,
                        onRiderTap: _showRider,
                        onEndOrLeave: _confirmEndOrLeave,
                        onRerouteGroup: () => context.runWithFeedback(
                          ref.read(_provider.notifier).rerouteGroup,
                          successMessage: 'New route sent to your group',
                        ),
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
