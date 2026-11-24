import 'package:brodie/features/history/data/ride_repository.dart';
import 'package:brodie/features/history/domain/ride.dart';
import 'package:brodie/features/history/domain/ride_filter.dart';
import 'package:flutter_test/flutter_test.dart';

Ride _ride(String id, DateTime startedAt, {double km = 5, int movingMin = 10, String? trip, String? vehicle}) => Ride(
      id: id,
      arrived: true,
      distanceMeters: km * 1000,
      duration: Duration(minutes: movingMin + 2),
      movingTime: Duration(minutes: movingMin),
      maxSpeedMps: 20,
      startedAt: startedAt,
      endedAt: startedAt.add(Duration(minutes: movingMin + 2)),
      groupTripId: trip,
      vehicleId: vehicle,
    );

void main() {
  final now = DateTime(2026, 11, 26, 15, 30);

  test('periods are calendar ranges in local time', () {
    expect(RidePeriod.allTime.rangeAt(now), (from: null, to: null));
    expect(RidePeriod.thisMonth.rangeAt(now), (from: DateTime(2026, 11), to: DateTime(2026, 12)));
    expect(RidePeriod.thisYear.rangeAt(now), (from: DateTime(2026), to: DateTime(2027)));
    // Today plus the 29 days before it, from midnight.
    expect(RidePeriod.last30Days.rangeAt(now), (from: DateTime(2026, 10, 28), to: null));
    // December rolls over into the next year.
    expect(RidePeriod.thisMonth.rangeAt(DateTime(2026, 12, 5)), (from: DateTime(2026, 12), to: DateTime(2027)));
  });

  test('rides waiting to upload are filtered by the same rules', () {
    final solo = _ride('solo', DateTime(2026, 11, 2), vehicle: 'adv');
    final group = _ride('group', DateTime(2026, 10, 30), trip: 'trip-1');
    final old = _ride('old', DateTime(2025, 6, 1));

    bool shows(RideFilter filter, Ride ride) => filter.matches(ride, now);

    expect([solo, group, old].where((r) => shows(const RideFilter(), r)), hasLength(3));
    expect(shows(const RideFilter(kind: RideKind.solo), group), isFalse);
    expect(shows(const RideFilter(kind: RideKind.group), group), isTrue);
    expect(shows(const RideFilter(period: RidePeriod.thisMonth), solo), isTrue);
    expect(shows(const RideFilter(period: RidePeriod.thisMonth), group), isFalse);
    expect(shows(const RideFilter(period: RidePeriod.thisYear), old), isFalse);
    expect(shows(const RideFilter(vehicleId: 'adv'), solo), isTrue);
    expect(shows(const RideFilter(vehicleId: 'adv'), group), isFalse);
  });

  test('sorts the same way as the server', () {
    final short = _ride('short', DateTime(2026, 11, 3), km: 5, movingMin: 50);
    final long = _ride('long', DateTime(2026, 11, 1), km: 80, movingMin: 20);
    List<String> order(RideSort sort) =>
        ([short, long]..sort(RideFilter(sort: sort).compare)).map((r) => r.id).toList();

    expect(order(RideSort.newest), ['short', 'long']);
    expect(order(RideSort.oldest), ['long', 'short']);
    expect(order(RideSort.distance), ['long', 'short']);
    expect(order(RideSort.movingTime), ['short', 'long']);
  });

  test('counts the filters that narrow the list', () {
    expect(const RideFilter().activeCount, 0);
    expect(const RideFilter().isDefault, isTrue);
    expect(const RideFilter(sort: RideSort.distance).activeCount, 0, reason: 'sorting hides nothing');
    expect(const RideFilter(sort: RideSort.distance).isDefault, isFalse);
    expect(const RideFilter(kind: RideKind.group, vehicleId: 'adv').activeCount, 2);
  });

  test('sends the filter to get_ride_history', () {
    final params = RideRepository.filterParams(
      const RideFilter(kind: RideKind.group, period: RidePeriod.thisMonth, vehicleId: 'adv'),
      now,
    );
    expect(params['p_kind'], 'group');
    expect(params['p_vehicle_id'], 'adv');
    expect(DateTime.parse(params['p_from']! as String).isAtSameMomentAs(DateTime(2026, 11)), isTrue);
    expect((params['p_from']! as String).endsWith('Z'), isTrue, reason: 'sent in UTC');
    expect(RideRepository.filterParams(const RideFilter(), now)['p_from'], isNull);
    expect(RideSort.movingTime.wire, 'moving_time');
  });

  test('reads the totals row', () {
    final totals = RideRepository.totalsFromRow({'ride_count': 4, 'distance_m': 170000, 'moving_s': 19100});
    expect(totals.count, 4);
    expect(totals.distanceMeters, 170000);
    expect(totals.movingTime, const Duration(seconds: 19100));
  });
}
