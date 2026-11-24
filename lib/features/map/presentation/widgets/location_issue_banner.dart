import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design_system/design_system.dart';
import '../../data/location_repository.dart';
import '../../domain/location_health.dart';
import '../../domain/map_models.dart';

/// Shown on the ride screens when the ride's location can't be trusted:
/// location switched off, access revoked, signal lost or weak. Re-checks
/// every few seconds on its own, since a lost signal is noticed by the
/// absence of new positions. Shows nothing while all is well.
class LocationIssueBanner extends ConsumerStatefulWidget {
  const LocationIssueBanner({
    super.key,
    required this.lastFix,
    required this.accessLost,
    required this.startedAt,
    this.inGroupRide = false,
  });

  final GeoFix? lastFix;
  final LocationAccess? accessLost;
  final DateTime startedAt;

  /// Mentions that the group can't see the rider move.
  final bool inGroupRide;

  @override
  ConsumerState<LocationIssueBanner> createState() => _LocationIssueBannerState();
}

class _LocationIssueBannerState extends ConsumerState<LocationIssueBanner> {
  late final Timer _recheck;

  @override
  void initState() {
    super.initState();
    _recheck = Timer.periodic(const Duration(seconds: 5), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _recheck.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final repository = ref.read(locationRepositoryProvider);
    final issue = LocationIssue.at(
      lastFix: widget.lastFix,
      accessLost: widget.accessLost,
      startedAt: widget.startedAt,
      now: DateTime.now(),
    );
    final group = widget.inGroupRide ? ' Your group sees your last position.' : '';

    final (IconData icon, Color color, String title, String message, (String, VoidCallback)? action) = switch (issue) {
      LocationIssue.none => (Icons.check, colors.success, '', '', null),
      LocationIssue.serviceDisabled => (
          Icons.location_disabled,
          colors.danger,
          'Location is turned off',
          "Your phone's location is off, so Brodie can't follow your ride.$group",
          ('Turn on location', repository.openLocationSettings),
        ),
      LocationIssue.permissionDenied => (
          Icons.location_off,
          colors.danger,
          'Location access is off',
          "Brodie isn't allowed to use your location, so it can't follow your ride.$group",
          ('Open settings', repository.openAppSettings),
        ),
      LocationIssue.signalLost => (
          Icons.gps_off,
          colors.warning,
          'GPS signal lost',
          widget.lastFix == null
              ? 'Still looking for your position. Open sky helps.'
              : 'Your position is out of date until the signal is back.$group',
          null,
        ),
      LocationIssue.weakSignal => (
          Icons.gps_not_fixed,
          colors.warning,
          'Weak GPS signal',
          'Your position may jump around for a while.',
          null,
        ),
    };
    if (issue == LocationIssue.none) return const SizedBox.shrink();

    return BrodieAlert(icon: icon, color: color, title: title, message: message, action: action);
  }
}
