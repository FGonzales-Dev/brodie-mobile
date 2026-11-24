import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/di/core_providers.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/errors/guard_remote.dart';
import '../../map/domain/polyline_codec.dart';
import '../domain/ride.dart';
import '../domain/ride_filter.dart';

part 'ride_repository.g.dart';

/// Saved rides. Every call is a stored procedure in brodie-supabase, scoped to
/// the signed-in rider; routes travel as polyline6 in both directions.
class RideRepository {
  RideRepository(this._client);

  final SupabaseClient _client;

  /// Safe to retry: saving a ride id that is already saved changes nothing.
  Future<void> save(Ride ride) => guardRemote(() => _client.rpc('save_completed_ride', params: saveParams(ride)));

  /// Saved rides matching [filter], in its order. [now] fixes what "this
  /// month" etc. mean for the whole list.
  Future<List<Ride>> fetchHistory({
    required int limit,
    required int offset,
    RideFilter filter = const RideFilter(),
    DateTime? now,
  }) {
    return guardRemote(() async {
      final rows = await _client.rpc(
        'get_ride_history',
        params: {
          'p_limit': limit,
          'p_offset': offset,
          ...filterParams(filter, now ?? DateTime.now()),
          'p_sort': filter.sort.wire,
        },
      );
      return (rows as List).cast<Map<String, dynamic>>().map(rideFromRow).toList();
    });
  }

  Future<RideTotals> fetchTotals({RideFilter filter = const RideFilter(), DateTime? now}) {
    return guardRemote(() async {
      final rows = await _client.rpc('get_ride_history_totals', params: filterParams(filter, now ?? DateTime.now()));
      return totalsFromRow((rows as List).first as Map<String, dynamic>);
    });
  }

  @visibleForTesting
  static Map<String, Object?> filterParams(RideFilter filter, DateTime now) {
    final (:from, :to) = filter.period.rangeAt(now);
    return {
      'p_kind': filter.kind.name,
      'p_from': from?.toUtc().toIso8601String(),
      'p_to': to?.toUtc().toIso8601String(),
      'p_vehicle_id': filter.vehicleId,
    };
  }

  @visibleForTesting
  static RideTotals totalsFromRow(Map<String, dynamic> row) => (
    count: (row['ride_count'] as num).toInt(),
    distanceMeters: (row['distance_m'] as num).toDouble(),
    movingTime: Duration(seconds: (row['moving_s'] as num).toInt()),
  );

  /// One ride with its route.
  Future<Ride> fetchRide(String id) {
    return guardRemote(() async {
      final rows = (await _client.rpc('get_ride', params: {'p_id': id})) as List;
      if (rows.isEmpty) throw const NotFoundFailure("This ride isn't in your history anymore.");
      return rideFromRow(rows.first as Map<String, dynamic>);
    });
  }

  /// Null clears the vehicle.
  Future<void> setVehicle(String rideId, String? vehicleId) {
    return guardRemote(() => _client.rpc('set_ride_vehicle', params: {'p_id': rideId, 'p_vehicle_id': vehicleId}));
  }

  /// Succeeds for a ride that never reached the server.
  Future<void> delete(String rideId) => guardRemote(() => _client.rpc('delete_ride', params: {'p_id': rideId}));

  @visibleForTesting
  static Map<String, Object?> saveParams(Ride ride) => {
    'p_id': ride.id,
    'p_route_polyline6': PolylineCodec.encode(ride.path),
    'p_distance_m': ride.distanceMeters,
    'p_duration_s': ride.duration.inSeconds,
    'p_moving_s': ride.movingTime.inSeconds,
    'p_max_speed_mps': ride.maxSpeedMps,
    'p_started_at': ride.startedAt.toUtc().toIso8601String(),
    'p_ended_at': ride.endedAt.toUtc().toIso8601String(),
    'p_arrived': ride.arrived,
    'p_destination_name': ride.destinationName,
    'p_vehicle_id': ride.vehicleId,
    'p_group_trip_id': ride.groupTripId,
  };

  @visibleForTesting
  static Ride rideFromRow(Map<String, dynamic> row) {
    final polyline = row['route_polyline6'] as String?;
    final duration = Duration(seconds: (row['duration_s'] as num?)?.toInt() ?? 0);
    final startedAt = DateTime.parse(row['started_at'] as String).toLocal();
    final endedAt = row['ended_at'] as String?;
    return Ride(
      id: row['id'] as String,
      destinationName: row['destination_name'] as String?,
      arrived: row['arrived'] as bool? ?? false,
      vehicleId: row['vehicle_id'] as String?,
      distanceMeters: (row['distance_m'] as num?)?.toDouble() ?? 0,
      duration: duration,
      // Older rows have no moving time; all of the ride is the best guess.
      movingTime: Duration(seconds: (row['moving_s'] as num?)?.toInt() ?? duration.inSeconds),
      maxSpeedMps: (row['max_speed_mps'] as num?)?.toDouble() ?? 0,
      startedAt: startedAt,
      endedAt: endedAt == null ? startedAt.add(duration) : DateTime.parse(endedAt).toLocal(),
      path: polyline == null ? const [] : PolylineCodec.decode(polyline),
      groupTripId: row['group_trip_id'] as String?,
      groupName: row['group_name'] as String?,
    );
  }
}

@Riverpod(keepAlive: true)
RideRepository rideRepository(Ref ref) => RideRepository(ref.watch(supabaseClientProvider));
