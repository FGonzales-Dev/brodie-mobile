import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/errors/app_failure.dart';
import '../domain/location_health.dart';
import '../domain/map_models.dart';

part 'location_repository.g.dart';

/// Device location and permissions. Only "while in use" access is ever
/// requested; group rides keep tracking in the background without "always"
/// (see [watchPosition]).
class LocationRepository {
  static const _fixTimeout = Duration(seconds: 15);

  Future<LocationAccess> checkAccess() async {
    if (!await Geolocator.isLocationServiceEnabled()) return LocationAccess.serviceDisabled;
    return _toAccess(await Geolocator.checkPermission());
  }

  Future<LocationAccess> requestAccess() async {
    final current = await checkAccess();
    if (current != LocationAccess.denied) return current;
    return _toAccess(await Geolocator.requestPermission());
  }

  /// One fresh fix, failing with [LocationFailure] rather than waiting forever.
  Future<GeoFix> currentFix() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: _fixTimeout),
      );
      return _toGeoFix(position);
    } catch (_) {
      throw const LocationFailure();
    }
  }

  Future<GeoPoint> currentPosition() async => (await currentFix()).position;

  /// The position the OS already has cached, if any. Instant: requests no new fix.
  Future<GeoPoint?> lastKnownPosition() async {
    try {
      final position = await Geolocator.getLastKnownPosition();
      return position == null ? null : _toGeoFix(position).position;
    } catch (_) {
      return null;
    }
  }

  /// Fixes while listened to, one per [distanceFilterMeters] of movement.
  ///
  /// With [keepRunningInBackground] (group rides), fixes keep coming while the
  /// phone is locked or another app is open, using only "while in use"
  /// access: the stream starts on screen, then Android keeps it alive with a
  /// foreground-service notification and iOS with its background location
  /// mode (the blue location indicator).
  Stream<GeoFix> watchPosition({int distanceFilterMeters = 10, bool keepRunningInBackground = false}) {
    return Geolocator.getPositionStream(
      locationSettings: _settings(distanceFilterMeters, keepRunningInBackground),
    ).map(_toGeoFix).handleError((Object error) => throw _accessLostFrom(error) ?? error);
  }

  /// The plugin's own errors for "no more locations", as [LocationAccessLost].
  static LocationAccessLost? _accessLostFrom(Object error) => switch (error) {
    LocationServiceDisabledException() => const LocationAccessLost(LocationAccess.serviceDisabled),
    PermissionDeniedException() => const LocationAccessLost(LocationAccess.denied),
    _ => null,
  };

  static LocationSettings _settings(int distanceFilterMeters, bool background) {
    if (!background) {
      return LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: distanceFilterMeters);
    }
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: distanceFilterMeters,
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'Group ride in progress',
          notificationText: 'Sharing your position with your group',
          notificationChannelName: 'Group ride',
          setOngoing: true,
        ),
      ),
      TargetPlatform.iOS => AppleSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: distanceFilterMeters,
        activityType: ActivityType.automotiveNavigation,
        pauseLocationUpdatesAutomatically: false,
        allowBackgroundLocationUpdates: true,
        showBackgroundLocationIndicator: true,
      ),
      _ => LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: distanceFilterMeters),
    };
  }

  Future<void> openAppSettings() => Geolocator.openAppSettings();

  Future<void> openLocationSettings() => Geolocator.openLocationSettings();

  static GeoFix _toGeoFix(Position position) => GeoFix(
    position: GeoPoint(latitude: position.latitude, longitude: position.longitude),
    accuracyMeters: position.accuracy,
    speedMps: position.speed,
    headingDegrees: position.heading,
    timestamp: position.timestamp,
  );

  static LocationAccess _toAccess(LocationPermission permission) => switch (permission) {
    LocationPermission.always => LocationAccess.always,
    LocationPermission.whileInUse => LocationAccess.whileInUse,
    LocationPermission.deniedForever => LocationAccess.deniedForever,
    LocationPermission.denied || LocationPermission.unableToDetermine => LocationAccess.denied,
  };
}

@Riverpod(keepAlive: true)
LocationRepository locationRepository(Ref ref) => LocationRepository();
