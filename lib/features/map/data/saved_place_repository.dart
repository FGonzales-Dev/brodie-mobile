import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/data/owned_rows_table.dart';
import '../../../core/di/core_providers.dart';
import '../domain/map_models.dart';
import '../domain/saved_place.dart';

part 'saved_place_repository.g.dart';

/// The rider's saved places (table `saved_places`, own rows only), oldest
/// first. Picking one costs no place search.
typedef SavedPlaceRepository = OwnedRowsTable<SavedPlace, Place>;

@Riverpod(keepAlive: true)
SavedPlaceRepository savedPlaceRepository(Ref ref) {
  return OwnedRowsTable(
    ref.watch(supabaseClientProvider),
    table: 'saved_places',
    fromRow: (row) => SavedPlace(
      id: row['id'] as String,
      place: Place(
        name: row['name'] as String,
        address: row['address'] as String?,
        location: GeoPoint(latitude: (row['lat'] as num).toDouble(), longitude: (row['lng'] as num).toDouble()),
      ),
    ),
    toRow: (place) => {
      'name': place.name,
      'address': place.address,
      'lat': place.location.latitude,
      'lng': place.location.longitude,
    },
  );
}
