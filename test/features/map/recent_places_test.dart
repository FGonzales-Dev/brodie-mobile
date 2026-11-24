import 'package:brodie/core/di/core_providers.dart';
import 'package:brodie/features/auth/application/session_providers.dart';
import 'package:brodie/features/auth/domain/app_user.dart';
import 'package:brodie/features/map/domain/map_models.dart';
import 'package:brodie/features/map/presentation/recent_places_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Place place(int n) => Place(
  name: 'Place $n',
  address: 'Street $n',
  location: GeoPoint(latitude: 14 + n / 100, longitude: 120 + n / 100),
);

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  /// A fresh app session for [userId] over the same device storage.
  RecentPlacesController controllerFor(String userId) {
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        currentUserProvider.overrideWithValue(AppUser(id: userId)),
      ],
    );
    addTearDown(container.dispose);
    container.listen(recentPlacesControllerProvider, (_, _) {});
    return container.read(recentPlacesControllerProvider.notifier);
  }

  List<String> names(RecentPlacesController controller) => [for (final p in controller.state) p.name];

  test('keeps newest first and moves a re-picked place to the top', () async {
    final recents = controllerFor('rider');
    await recents.add(place(1));
    await recents.add(place(2));
    await recents.add(place(1));

    expect(names(recents), ['Place 1', 'Place 2']);
  });

  test('keeps only the 10 most recent', () async {
    final recents = controllerFor('rider');
    for (var n = 1; n <= 12; n++) {
      await recents.add(place(n));
    }

    expect(recents.state, hasLength(RecentPlacesController.maxPlaces));
    expect(names(recents).first, 'Place 12');
    expect(names(recents).last, 'Place 3');
  });

  test('removes one place, or clears them all', () async {
    final recents = controllerFor('rider');
    for (var n = 1; n <= 3; n++) {
      await recents.add(place(n));
    }

    await recents.remove(place(2));
    expect(names(recents), ['Place 3', 'Place 1']);

    await recents.clear();
    expect(recents.state, isEmpty);
  });

  test('survives a restart and is separate per account', () async {
    await controllerFor('rider').add(place(1));

    expect(names(controllerFor('rider')), ['Place 1']);
    expect(controllerFor('someone-else').state, isEmpty);
  });

  test('a cleared list stays cleared after a restart', () async {
    final recents = controllerFor('rider');
    await recents.add(place(1));
    await recents.clear();

    expect(controllerFor('rider').state, isEmpty);
  });
}
