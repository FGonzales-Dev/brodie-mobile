import 'package:brodie/core/data/owned_rows_table.dart';
import 'package:brodie/core/design_system/design_system.dart';
import 'package:brodie/core/di/core_providers.dart';
import 'package:brodie/features/auth/application/session_providers.dart';
import 'package:brodie/features/auth/domain/app_user.dart';
import 'package:brodie/features/map/data/place_search_repository.dart';
import 'package:brodie/features/map/data/saved_place_repository.dart';
import 'package:brodie/features/map/domain/map_models.dart';
import 'package:brodie/features/map/domain/saved_place.dart';
import 'package:brodie/features/map/presentation/destination_search_screen.dart';
import 'package:brodie/features/map/presentation/pick_on_map_screen.dart';
import 'package:brodie/features/map/presentation/recent_places_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _home = Place(name: 'Home', location: GeoPoint(latitude: 14.5, longitude: 121.0));
const _cafe = Place(name: 'Café Racer', address: 'Tagaytay', location: GeoPoint(latitude: 14.1, longitude: 120.9));

class _SavedRows implements SavedPlaceRepository {
  final rows = <SavedPlace>[const SavedPlace(id: 's1', place: _home)];

  @override
  Future<List<SavedPlace>> fetchMine() async => List.of(rows);

  @override
  Future<void> insert(Place draft) async => rows.add(SavedPlace(id: 's${rows.length + 1}', place: draft));

  @override
  Future<void> delete(String id) async => rows.removeWhere((row) => row.id == id);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Fails the test if the screen searches at all.
class _NoSearch implements PlaceSearchRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => fail('searched: ${invocation.memberName}');
}

void main() {
  test('places match by name within about a meter', () {
    expect(_cafe.isSameAs(_cafe.copyWith(location: const GeoPoint(latitude: 14.100003, longitude: 120.9))), isTrue);
    expect(_cafe.isSameAs(_cafe.copyWith(location: const GeoPoint(latitude: 14.1002, longitude: 120.9))), isFalse);
    expect(_cafe.isSameAs(_cafe.copyWith(name: 'Café')), isFalse);
  });

  late _SavedRows saved;
  Place? picked;

  Future<void> openSearch(WidgetTester tester, {List<String> recents = const []}) async {
    SharedPreferences.setMockInitialValues({
      if (recents.isNotEmpty)
        'map.recent_places.user-1': '[{"name":"Café Racer","address":"Tagaytay","lat":14.1,"lng":120.9}]',
    });
    final prefs = await SharedPreferences.getInstance();
    saved = _SavedRows();
    picked = null;
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, _) => TextButton(
            onPressed: () async => picked = await context.push<Place>('/search'),
            child: const Text('open'),
          ),
        ),
        GoRoute(path: '/search', builder: (_, _) => const DestinationSearchScreen()),
        // Stands in for the map: "uses" a fixed spot straight away.
        GoRoute(
          path: '/map/pick',
          builder: (context, _) => TextButton(
            onPressed: () => context.pop(pinnedPlace(const GeoPoint(latitude: 14.123456, longitude: 120.987654))),
            child: const Text('use spot'),
          ),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          currentUserProvider.overrideWithValue(const AppUser(id: 'user-1')),
          savedPlaceRepositoryProvider.overrideWithValue(saved as OwnedRowsTable<SavedPlace, Place>),
          placeSearchRepositoryProvider.overrideWithValue(_NoSearch()),
        ],
        child: MaterialApp.router(theme: AppTheme.dark, routerConfig: router),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('saved places come first, and picking one needs no search', (tester) async {
    await openSearch(tester, recents: ['cafe']);
    expect(find.text('SAVED'), findsOneWidget);
    expect(find.text('RECENT'), findsOneWidget);

    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    expect(picked, _home);
  });

  testWidgets('starring a recent place saves it to the account', (tester) async {
    await openSearch(tester, recents: ['cafe']);
    await tester.tap(find.byTooltip('Save place'));
    await tester.pumpAndSettle();

    expect(saved.rows.map((row) => row.place.name), ['Home', 'Café Racer']);
    expect(find.byTooltip('Remove from saved'), findsNWidgets(3), reason: 'both saved rows, and the starred recent');
  });

  testWidgets('with nothing saved or recent, it explains how to start', (tester) async {
    await openSearch(tester);
    await tester.tap(find.byTooltip('Remove from saved'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Star places you go often'), findsOneWidget);
  });

  test('a pinned spot is named and labelled with its coordinates', () {
    final place = pinnedPlace(const GeoPoint(latitude: 14.123456, longitude: 120.987654));
    expect(place.name, 'Pinned spot');
    expect(place.address, '14.12346, 120.98765');
    expect(place.location, const GeoPoint(latitude: 14.123456, longitude: 120.987654));
  });

  testWidgets('a spot chosen on the map is returned without searching, and kept as recent', (tester) async {
    await openSearch(tester);
    await tester.tap(find.text('Choose on map'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('use spot'));
    await tester.pumpAndSettle();

    expect(picked?.name, 'Pinned spot');
    final container = ProviderScope.containerOf(tester.element(find.text('open')));
    expect(container.read(recentPlacesControllerProvider).single.name, 'Pinned spot');
  });
}
