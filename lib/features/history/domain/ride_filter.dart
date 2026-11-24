import 'package:freezed_annotation/freezed_annotation.dart';

import 'ride.dart';

part 'ride_filter.freezed.dart';

enum RideKind {
  all('All'),
  solo('Solo'),
  group('Group');

  const RideKind(this.label);

  final String label;
}

/// Calendar periods, in the rider's own time zone.
enum RidePeriod {
  allTime('All time'),
  last30Days('Last 30 days'),
  thisMonth('This month'),
  thisYear('This year');

  const RidePeriod(this.label);

  final String label;

  /// Start (inclusive) and end (exclusive) as of [now]; null for no limit.
  ({DateTime? from, DateTime? to}) rangeAt(DateTime now) => switch (this) {
        allTime => (from: null, to: null),
        last30Days => (from: DateTime(now.year, now.month, now.day - 29), to: null),
        thisMonth => (from: DateTime(now.year, now.month), to: DateTime(now.year, now.month + 1)),
        thisYear => (from: DateTime(now.year), to: DateTime(now.year + 1)),
      };
}

enum RideSort {
  newest('Newest first', 'newest'),
  oldest('Oldest first', 'oldest'),
  distance('Longest distance', 'distance'),
  movingTime('Most time riding', 'moving_time');

  const RideSort(this.label, this.wire);

  final String label;

  /// The value `get_ride_history` expects.
  final String wire;
}

/// How the history list is narrowed and ordered. The server applies it to
/// saved rides; [matches] and [compare] apply the same rules to rides still
/// waiting to upload.
@freezed
abstract class RideFilter with _$RideFilter {
  const factory RideFilter({
    @Default(RideKind.all) RideKind kind,
    @Default(RidePeriod.allTime) RidePeriod period,

    /// Only rides on this vehicle; null for any.
    String? vehicleId,
    @Default(RideSort.newest) RideSort sort,
  }) = _RideFilter;

  const RideFilter._();

  /// Filters that narrow the list (the sort doesn't count).
  int get activeCount => [kind != RideKind.all, period != RidePeriod.allTime, vehicleId != null].where((on) => on).length;

  bool get isDefault => activeCount == 0 && sort == RideSort.newest;

  bool matches(Ride ride, DateTime now) {
    final (:from, :to) = period.rangeAt(now);
    return switch (kind) {
          RideKind.all => true,
          RideKind.solo => ride.groupTripId == null,
          RideKind.group => ride.groupTripId != null,
        } &&
        (from == null || !ride.startedAt.isBefore(from)) &&
        (to == null || ride.startedAt.isBefore(to)) &&
        (vehicleId == null || ride.vehicleId == vehicleId);
  }

  int compare(Ride a, Ride b) => switch (sort) {
        RideSort.newest => b.startedAt.compareTo(a.startedAt),
        RideSort.oldest => a.startedAt.compareTo(b.startedAt),
        RideSort.distance => b.distanceMeters.compareTo(a.distanceMeters),
        RideSort.movingTime => b.movingTime.compareTo(a.movingTime),
      };
}

/// What the filtered history adds up to.
typedef RideTotals = ({int count, double distanceMeters, Duration movingTime});
