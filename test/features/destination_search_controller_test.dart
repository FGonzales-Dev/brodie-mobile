import 'package:brodie/core/di/core_providers.dart';
import 'package:brodie/features/map/application/my_location_providers.dart';
import 'package:brodie/features/map/data/place_search_repository.dart';
import 'package:brodie/features/map/domain/map_models.dart';
import 'package:brodie/features/map/presentation/destination_search_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/geo.dart';

/// Records every query that would have been sent to Mapbox.
class _CountingSearchRepository implements PlaceSearchRepository {
  final queries = <String>[];
  final nearPoints = <GeoPoint?>[];

  @override
  Future<List<PlaceSuggestion>> suggest(String query, {required String sessionToken, GeoPoint? near}) async {
    queries.add(query);
    nearPoints.add(near);
    return const [];
  }

  @override
  Future<Place> retrieve(PlaceSuggestion suggestion, {required String sessionToken}) => throw UnimplementedError();
}

/// The home map's last fetched position, fixed for the test.
class _FixedLocationController extends MyLocationController {
  _FixedLocationController(this.fix);

  final GeoFix fix;

  @override
  Future<GeoFix> build() async => fix;
}

void main() {
  late _CountingSearchRepository repository;
  late DestinationSearchController controller;

  // Longer than the controller's 300 ms debounce.
  Future<void> pause() => Future<void>.delayed(const Duration(milliseconds: 400));

  const riderPosition = GeoPoint(latitude: 14.5995, longitude: 120.9842);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    repository = _CountingSearchRepository();
    final container = ProviderContainer(
      overrides: [
        placeSearchRepositoryProvider.overrideWithValue(repository),
        sharedPreferencesProvider.overrideWithValue(prefs),
        myLocationControllerProvider.overrideWith(
          () => _FixedLocationController(fixAt(riderPosition, DateTime(2026, 10, 29))),
        ),
      ],
    );
    addTearDown(container.dispose);
    // The home map keeps its fetched position alive underneath the search screen.
    container.listen(myLocationControllerProvider, (_, _) {});
    // Keep the auto-disposed controller alive for the whole test.
    final subscription = container.listen(destinationSearchControllerProvider, (_, _) {});
    addTearDown(subscription.close);
    controller = container.read(destinationSearchControllerProvider.notifier);
  });

  test('does not call Mapbox for fewer than 3 characters', () async {
    controller
      ..search('t')
      ..search('ta')
      ..search('  ta  ');
    await pause();

    expect(repository.queries, isEmpty);
  });

  test('sends one trimmed request after the user stops typing', () async {
    for (final query in ['tag', 'taga', 'tagay', 'tagaytay ']) {
      controller.search(query);
    }
    await pause();

    expect(repository.queries, ['tagaytay']);
  });

  test('cancels a pending request when the query drops below 3 characters', () async {
    controller
      ..search('tag')
      ..search('ta');
    await pause();

    expect(repository.queries, isEmpty);
  });

  test("biases results toward the rider's position", () async {
    await Future<void>.delayed(Duration.zero); // let the position resolve
    controller.search('jollibee');
    await pause();

    expect(repository.nearPoints, [riderPosition]);
  });
}
