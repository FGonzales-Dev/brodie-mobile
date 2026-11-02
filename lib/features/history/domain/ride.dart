import 'package:freezed_annotation/freezed_annotation.dart';

import '../../map/domain/map_models.dart';

part 'ride.freezed.dart';

/// A finished ride. [id] is generated on the phone, so a ride saved while
/// offline keeps the same id once it reaches the server.
@freezed
abstract class Ride with _$Ride {
  const factory Ride({
    required String id,
    String? destinationName,

    /// Whether the rider reached the destination, rather than ending early.
    required bool arrived,
    String? vehicleId,
    required double distanceMeters,

    /// Start to finish, stops included.
    required Duration duration,
    required Duration movingTime,
    required double maxSpeedMps,
    required DateTime startedAt,
    required DateTime endedAt,

    /// The route ridden. Empty in history lists; loaded for the ride detail.
    @Default(<GeoPoint>[]) List<GeoPoint> path,
  }) = _Ride;

  const Ride._();

  double get averageSpeedMps => movingTime.inSeconds == 0 ? 0 : distanceMeters / movingTime.inSeconds;
}
