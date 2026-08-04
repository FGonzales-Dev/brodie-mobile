import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../data/repositories/vehicle_repository.dart';
import '../../../domain/models/vehicle.dart';

part 'vehicles_controller.g.dart';

@riverpod
class VehiclesController extends _$VehiclesController {
  @override
  FutureOr<List<Vehicle>> build() {
    final userId = Supabase.instance.client.auth.currentUser!.id;
    return ref.read(vehicleRepositoryProvider).getVehicles(userId);
  }

  Future<void> addVehicle({required VehicleType type, required String name}) async {
    final userId = Supabase.instance.client.auth.currentUser!.id;
    await ref.read(vehicleRepositoryProvider).addVehicle(userId: userId, type: type, name: name);
    await _refresh();
  }

  Future<void> updateVehicle({required String id, required VehicleType type, required String name}) async {
    await ref.read(vehicleRepositoryProvider).updateVehicle(id: id, type: type, name: name);
    await _refresh();
  }

  Future<void> deleteVehicle(String id) async {
    await ref.read(vehicleRepositoryProvider).deleteVehicle(id);
    await _refresh();
  }

  Future<void> _refresh() async {
    final userId = Supabase.instance.client.auth.currentUser!.id;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => ref.read(vehicleRepositoryProvider).getVehicles(userId));
  }
}
