import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/vehicle.dart';
import 'application/vehicles_controller.dart';

class VehiclesScreen extends ConsumerWidget {
  const VehiclesScreen({super.key});

  Future<void> _showVehicleForm(BuildContext context, WidgetRef ref, {Vehicle? vehicle}) async {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: vehicle?.name);
    var type = vehicle?.type ?? VehicleType.motorcycle;

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setState) => AlertDialog(
          title: Text(vehicle == null ? 'Add Vehicle' : 'Edit Vehicle'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<VehicleType>(
                  initialValue: type,
                  decoration: const InputDecoration(labelText: 'Type'),
                  items: VehicleType.values
                      .map((value) => DropdownMenuItem(value: value, child: Text(value.name)))
                      .toList(),
                  onChanged: (value) => setState(() => type = value ?? type),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: nameController,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: 'Name'),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) return 'Enter a name';
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.of(dialogContext).pop(true);
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (result != true) return;

    final controller = ref.read(vehiclesControllerProvider.notifier);
    if (vehicle == null) {
      await controller.addVehicle(type: type, name: nameController.text.trim());
    } else {
      await controller.updateVehicle(id: vehicle.id, type: type, name: nameController.text.trim());
    }
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, Vehicle vehicle) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete vehicle?'),
        content: Text('Remove "${vehicle.name}" from your vehicles.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(dialogContext).colorScheme.error),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(vehiclesControllerProvider.notifier).deleteVehicle(vehicle.id);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vehiclesAsync = ref.watch(vehiclesControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Vehicles')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showVehicleForm(context, ref),
        child: const Icon(Icons.add),
      ),
      body: vehiclesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Could not load vehicles: $error')),
        data: (vehicles) {
          if (vehicles.isEmpty) {
            return const Center(child: Text('No vehicles yet. Tap + to add one.'));
          }
          return ListView.builder(
            itemCount: vehicles.length,
            itemBuilder: (context, index) {
              final vehicle = vehicles[index];
              return ListTile(
                leading: Icon(vehicle.type == VehicleType.motorcycle ? Icons.motorcycle : Icons.pedal_bike),
                title: Text(vehicle.name),
                subtitle: Text(vehicle.type.name),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () => _showVehicleForm(context, ref, vehicle: vehicle),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _confirmDelete(context, ref, vehicle),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
