import 'package:geolocator/geolocator.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/errors/app_failure.dart';
import '../domain/map_models.dart';

part 'location_repository.g.dart';

/// Device location and permissions. Only "while in use" access is requested
/// here; background access comes later, when a group ride starts.
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
  Stream<GeoFix> watchPosition({int distanceFilterMeters = 10}) {
    return Geolocator.getPositionStream(
      locationSettings: LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: distanceFilterMeters),
    ).map(_toGeoFix);
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
