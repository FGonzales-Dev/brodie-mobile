import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/last_location_store.dart';
import '../data/location_repository.dart';
import '../domain/map_models.dart';

part 'my_location_providers.g.dart';

/// The rider's position on the home map. Fetched once when the map opens and
/// again only when the rider taps "Refresh my location": GPS stays off on
/// this screen otherwise, to save battery. (The ride screen tracks live.)
/// Each fix is also remembered for the next app launch.
@riverpod
class MyLocationController extends _$MyLocationController {
  @override
  Future<GeoFix> build() async {
    final fix = await ref.read(locationRepositoryProvider).currentFix();
    await ref.read(lastLocationStoreProvider).save(fix.position);
    return fix;
  }

  /// Gets a fresh fix; the previous one stays available while it loads.
  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }
}

/// Where the map should open before a fresh fix arrives: the OS's cached
/// position, else where the user was last time, else null (whole world).
@riverpod
Future<GeoPoint?> initialMapCenter(Ref ref) async {
  final cached = await ref.read(locationRepositoryProvider).lastKnownPosition();
  return cached ?? ref.read(lastLocationStoreProvider).read();
}
