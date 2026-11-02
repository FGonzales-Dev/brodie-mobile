import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/data/owned_rows_table.dart';
import '../../../core/di/core_providers.dart';
import '../domain/vehicle.dart';

part 'vehicle_repository.g.dart';

typedef VehicleRepository = OwnedRowsTable<Vehicle, VehicleDraft>;

@Riverpod(keepAlive: true)
VehicleRepository vehicleRepository(Ref ref) {
  return OwnedRowsTable(
    ref.watch(supabaseClientProvider),
    table: 'vehicles',
    fromRow: (row) => Vehicle(
      id: row['id'] as String,
      type: VehicleType.values.byName(row['type'] as String),
      name: row['name'] as String,
    ),
    toRow: (draft) => {'type': draft.type.name, 'name': draft.name},
  );
}
