import 'package:uuid/uuid.dart';

import '../../map/domain/track_recorder.dart';
import 'ride.dart';

/// Rides shorter than this are false starts and aren't saved.
const minSavedRideDistanceMeters = 200.0;
const minSavedRideDuration = Duration(minutes: 1);

/// The ride to save from what [track] recorded between [startedAt] and
/// [endedAt], or null when it was too short to keep. Used by solo and group
/// rides alike, so both follow the same rules.
Ride? rideFromTrack(
  TrackRecorder track, {
  required DateTime startedAt,
  required DateTime endedAt,
  required bool arrived,
  String? destinationName,
  String? groupTripId,
}) {
  final duration = endedAt.difference(startedAt);
  final path = track.path;
  if (path.length < 2 || track.distanceMeters < minSavedRideDistanceMeters || duration < minSavedRideDuration) {
    return null;
  }
  return Ride(
    id: const Uuid().v4(),
    destinationName: destinationName,
    arrived: arrived,
    distanceMeters: track.distanceMeters,
    duration: duration,
    movingTime: track.movingTime,
    maxSpeedMps: track.maxSpeedMps,
    startedAt: startedAt,
    endedAt: endedAt,
    path: path,
    groupTripId: groupTripId,
  );
}
