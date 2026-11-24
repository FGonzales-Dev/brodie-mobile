import 'package:brodie/core/di/core_providers.dart';
import 'package:brodie/features/map/application/my_location_providers.dart';
import 'package:brodie/features/map/data/last_location_store.dart';
import 'package:brodie/features/map/data/location_repository.dart';
import 'package:brodie/features/map/domain/map_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/geo.dart';

class _CachedLocationRepository extends LocationRepository {
  _CachedLocationRepository(this.cached);

  final GeoPoint? cached;

  @override
  Future<GeoPoint?> lastKnownPosition() async => cached;
}

void main() {
  const manila = GeoPoint(latitude: 14.5995, longitude: 120.9842);
  const tagaytay = GeoPoint(latitude: 14.1153, longitude: 120.962);

  Future<ProviderContainer> containerWith({GeoPoint? cached, GeoPoint? saved}) async {
    SharedPreferences.setMockInitialValues({
      if (saved != null) ...{'map.last_latitude': saved.latitude, 'map.last_longitude': saved.longitude},
    });
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        locationRepositoryProvider.overrideWithValue(_CachedLocationRepository(cached)),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('initialMapCenter', () {
    test("prefers the OS's cached position", () async {
      final container = await containerWith(cached: manila, saved: tagaytay);

      expect(await container.read(initialMapCenterProvider.future), manila);
    });

    test('falls back to where the user was last time', () async {
      final container = await containerWith(saved: tagaytay);

      expect(await container.read(initialMapCenterProvider.future), tagaytay);
    });

    test('is null when nothing is known, so the map shows the whole world', () async {
      final container = await containerWith();

      expect(await container.read(initialMapCenterProvider.future), isNull);
    });
  });

  test('LastLocationStore only rewrites after moving 250 m', () async {
    final container = await containerWith();
    final store = container.read(lastLocationStoreProvider);

    await store.save(manila);
    await store.save(north(manila, 100));
    expect(store.read(), manila, reason: 'a 100 m move is not saved');

    await store.save(north(manila, 300));
    expect(store.read()!.latitude, closeTo(north(manila, 300).latitude, 1e-9));
  });
}
