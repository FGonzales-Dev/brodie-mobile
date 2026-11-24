import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/data/owned_rows_table.dart';
import '../../../core/di/core_providers.dart';
import '../../../core/errors/guard_remote.dart';
import '../../../core/photos/photo_storage.dart';
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
      photoPath: row['photo_path'] as String?,
    ),
    toRow: (draft) => {'type': draft.type.name, 'name': draft.name},
  );
}

/// A vehicle's photo. Separate from the vehicle form: the photo is saved as
/// soon as it's picked, so a vehicle never points at a deleted file.
class VehiclePhotoRepository {
  VehiclePhotoRepository(this._client, this._photos);

  final SupabaseClient _client;
  final PhotoStorage _photos;

  /// Uploads [jpeg] as [vehicle]'s photo, then removes the old one.
  Future<void> setPhoto(Vehicle vehicle, Uint8List jpeg) async {
    final path = await _photos.upload(PhotoBucket.vehicles, jpeg);
    try {
      await _setPath(vehicle.id, path);
    } catch (_) {
      await _photos.delete(PhotoBucket.vehicles, path);
      rethrow;
    }
    final old = vehicle.photoPath;
    if (old != null) await _photos.delete(PhotoBucket.vehicles, old);
  }

  Future<void> removePhoto(Vehicle vehicle) async {
    final old = vehicle.photoPath;
    await _setPath(vehicle.id, null);
    if (old != null) await _photos.delete(PhotoBucket.vehicles, old);
  }

  /// Also removes the photo file, which deleting the row leaves behind.
  Future<void> deleteFileOf(Vehicle vehicle) async {
    final old = vehicle.photoPath;
    if (old != null) await _photos.delete(PhotoBucket.vehicles, old);
  }

  Future<void> _setPath(String vehicleId, String? path) =>
      guardRemote(() => _client.from('vehicles').update({'photo_path': path}).eq('id', vehicleId));
}

@Riverpod(keepAlive: true)
VehiclePhotoRepository vehiclePhotoRepository(Ref ref) =>
    VehiclePhotoRepository(ref.watch(supabaseClientProvider), ref.watch(photoStorageProvider));
