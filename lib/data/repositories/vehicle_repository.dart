import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/models/vehicle.dart';

part 'vehicle_repository.g.dart';

class VehicleRepository {
  VehicleRepository(this._client);

  final SupabaseClient _client;

  Future<List<Vehicle>> getVehicles(String userId) async {
    final response = await _client.from('vehicles').select().eq('user_id', userId).order('created_at');
    return response.map(Vehicle.fromJson).toList();
  }

  Future<Vehicle> addVehicle({required String userId, required VehicleType type, required String name}) async {
    final response = await _client
        .from('vehicles')
        .insert({'user_id': userId, 'type': type.name, 'name': name})
        .select()
        .single();
    return Vehicle.fromJson(response);
  }

  Future<Vehicle> updateVehicle({required String id, required VehicleType type, required String name}) async {
    final response =
        await _client.from('vehicles').update({'type': type.name, 'name': name}).eq('id', id).select().single();
    return Vehicle.fromJson(response);
  }

  Future<void> deleteVehicle(String id) {
    return _client.from('vehicles').delete().eq('id', id);
  }
}

@riverpod
VehicleRepository vehicleRepository(Ref ref) {
  return VehicleRepository(Supabase.instance.client);
}
