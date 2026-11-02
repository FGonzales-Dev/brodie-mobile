import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/di/core_providers.dart';
import '../domain/map_models.dart';
import '../domain/route_geometry.dart';

part 'last_location_store.g.dart';

/// Remembers roughly where the user last was, on this device only, so the
/// map can open there while waiting for a fresh GPS fix.
class LastLocationStore {
  LastLocationStore(this._prefs);

  final SharedPreferences _prefs;

  /// Saves are skipped until the user has moved this far, to avoid writing
  /// to disk on every fix.
  static const minMoveMeters = 250.0;
  static const _latitudeKey = 'map.last_latitude';
  static const _longitudeKey = 'map.last_longitude';

  GeoPoint? read() {
    final latitude = _prefs.getDouble(_latitudeKey);
    final longitude = _prefs.getDouble(_longitudeKey);
    if (latitude == null || longitude == null) return null;
    return GeoPoint(latitude: latitude, longitude: longitude);
  }

  Future<void> save(GeoPoint point) async {
    final saved = read();
    if (saved != null && distanceBetween(saved, point) < minMoveMeters) return;
    await Future.wait([
      _prefs.setDouble(_latitudeKey, point.latitude),
      _prefs.setDouble(_longitudeKey, point.longitude),
    ]);
  }
}

@Riverpod(keepAlive: true)
LastLocationStore lastLocationStore(Ref ref) => LastLocationStore(ref.watch(sharedPreferencesProvider));
