import 'dart:convert';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/di/core_providers.dart';
import '../../map/domain/polyline_codec.dart';
import '../domain/ride.dart';

part 'ride_device_store.g.dart';

/// Ride data kept on this device, separately per account: finished rides
/// still waiting to upload, and the vehicle the rider last picked.
class RideDeviceStore {
  RideDeviceStore(this._prefs);

  final SharedPreferences _prefs;

  static String _pendingKey(String userId) => 'rides.pending.$userId';
  static String _vehicleKey(String userId) => 'rides.last_vehicle.$userId';

  List<Ride> readPending(String userId) {
    final raw = _prefs.getString(_pendingKey(userId));
    if (raw == null) return const [];
    try {
      return (jsonDecode(raw) as List).cast<Map<String, dynamic>>().map(_fromJson).toList();
    } catch (_) {
      // Unreadable data (e.g. from an older format): start over rather than fail.
      return const [];
    }
  }

  Future<void> savePending(String userId, List<Ride> rides) async {
    if (rides.isEmpty) {
      await _prefs.remove(_pendingKey(userId));
    } else {
      await _prefs.setString(_pendingKey(userId), jsonEncode(rides.map(_toJson).toList()));
    }
  }

  String? readLastVehicle(String userId) => _prefs.getString(_vehicleKey(userId));

  Future<void> saveLastVehicle(String userId, String? vehicleId) async {
    if (vehicleId == null) {
      await _prefs.remove(_vehicleKey(userId));
    } else {
      await _prefs.setString(_vehicleKey(userId), vehicleId);
    }
  }

  static Map<String, Object?> _toJson(Ride ride) => {
        'id': ride.id,
        'destination': ride.destinationName,
        'arrived': ride.arrived,
        'vehicle': ride.vehicleId,
        'distance_m': ride.distanceMeters,
        'duration_s': ride.duration.inSeconds,
        'moving_s': ride.movingTime.inSeconds,
        'max_speed_mps': ride.maxSpeedMps,
        'started_at': ride.startedAt.toUtc().toIso8601String(),
        'ended_at': ride.endedAt.toUtc().toIso8601String(),
        'polyline6': PolylineCodec.encode(ride.path),
      };

  static Ride _fromJson(Map<String, dynamic> json) => Ride(
        id: json['id'] as String,
        destinationName: json['destination'] as String?,
        arrived: json['arrived'] as bool,
        vehicleId: json['vehicle'] as String?,
        distanceMeters: (json['distance_m'] as num).toDouble(),
        duration: Duration(seconds: json['duration_s'] as int),
        movingTime: Duration(seconds: json['moving_s'] as int),
        maxSpeedMps: (json['max_speed_mps'] as num).toDouble(),
        startedAt: DateTime.parse(json['started_at'] as String).toLocal(),
        endedAt: DateTime.parse(json['ended_at'] as String).toLocal(),
        path: PolylineCodec.decode(json['polyline6'] as String),
      );
}

@Riverpod(keepAlive: true)
RideDeviceStore rideDeviceStore(Ref ref) => RideDeviceStore(ref.watch(sharedPreferencesProvider));
