import 'dart:convert';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/di/core_providers.dart';
import '../domain/map_models.dart';

part 'recent_places_store.g.dart';

/// Places the user picked from search, newest first. Kept on this device
/// only, separately per account, so another rider signing in on the same
/// phone doesn't see them.
class RecentPlacesStore {
  RecentPlacesStore(this._prefs);

  final SharedPreferences _prefs;

  static String _key(String userId) => 'map.recent_places.$userId';

  List<Place> read(String userId) {
    final raw = _prefs.getString(_key(userId));
    if (raw == null) return const [];
    try {
      return (jsonDecode(raw) as List).cast<Map<String, dynamic>>().map(_fromJson).toList();
    } catch (_) {
      // Unreadable data (e.g. from an older format): start over rather than fail.
      return const [];
    }
  }

  Future<void> save(String userId, List<Place> places) async {
    if (places.isEmpty) {
      await _prefs.remove(_key(userId));
    } else {
      await _prefs.setString(_key(userId), jsonEncode(places.map(_toJson).toList()));
    }
  }

  static Map<String, Object?> _toJson(Place place) => {
    'name': place.name,
    'address': place.address,
    'lat': place.location.latitude,
    'lng': place.location.longitude,
  };

  static Place _fromJson(Map<String, dynamic> json) => Place(
    name: json['name'] as String,
    address: json['address'] as String?,
    location: GeoPoint(latitude: (json['lat'] as num).toDouble(), longitude: (json['lng'] as num).toDouble()),
  );
}

@Riverpod(keepAlive: true)
RecentPlacesStore recentPlacesStore(Ref ref) => RecentPlacesStore(ref.watch(sharedPreferencesProvider));
