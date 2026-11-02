import 'package:flutter/material.dart';

import '../../../core/design_system/design_system.dart';
import '../../../core/presentation/owned_rows_controller.dart';
import '../../../core/presentation/owned_rows_screen.dart';
import '../../../core/utils/validators.dart';
import '../data/vehicle_repository.dart';
import '../domain/vehicle.dart';

final vehiclesControllerProvider = ownedRowsControllerProvider(vehicleRepositoryProvider);

IconData vehicleIcon(VehicleType type) => switch (type) {
      VehicleType.motorcycle => Icons.two_wheeler,
      VehicleType.bike => Icons.pedal_bike,
    };

class VehiclesScreen extends StatelessWidget {
  const VehiclesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return OwnedRowsScreen<Vehicle, VehicleDraft>(
      provider: vehiclesControllerProvider,
      title: 'Vehicles',
      noun: 'vehicle',
      empty: const EmptyState(
        icon: Icons.two_wheeler,
        title: 'No vehicles yet',
        message: 'Add what you ride so your crew knows what to look for.',
      ),
      idOf: (vehicle) => vehicle.id,
      titleOf: (vehicle) => vehicle.name,
      subtitleOf: (vehicle) => vehicle.type.label,
      leadingOf: (vehicle) => IconTile(icon: vehicleIcon(vehicle.type)),
      formBuilder: (existing) => _VehicleFormSheet(existing: existing),
    );
  }
}

class _VehicleFormSheet extends StatefulWidget {
  const _VehicleFormSheet({this.existing});

  final Vehicle? existing;

  @override
  State<_VehicleFormSheet> createState() => _VehicleFormSheetState();
}

class _VehicleFormSheetState extends State<_VehicleFormSheet> {
  late VehicleType _type = widget.existing?.type ?? VehicleType.motorcycle;
  late final _name = TextEditingController(text: widget.existing?.name);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BrodieFormSheet<VehicleDraft>(
      title: widget.existing == null ? 'Add vehicle' : 'Edit vehicle',
      fields: [
        BrodieSegmentedControl<VehicleType>(
          options: [for (final type in VehicleType.values) (type, type.label)],
          selected: _type,
          onChanged: (type) => setState(() => _type = type),
        ),
        BrodieTextField(
          controller: _name,
          label: 'Name',
          hint: 'e.g. Honda ADV 160',
          textInputAction: TextInputAction.done,
          validator: Validators.required('Enter a name'),
        ),
      ],
      onSave: () => (type: _type, name: _name.text.trim()),
    );
  }
}
