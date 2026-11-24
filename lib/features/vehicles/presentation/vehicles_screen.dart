import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design_system/design_system.dart';
import '../../../core/photos/photo_picker.dart';
import '../../../core/photos/photo_storage.dart';
import '../../../core/presentation/feedback.dart';
import '../../../core/presentation/owned_rows_screen.dart';
import '../../../core/utils/validators.dart';
import '../application/vehicle_providers.dart';
import '../data/vehicle_repository.dart';
import '../domain/vehicle.dart';
import 'widgets/vehicle_icon.dart';

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
      subtitleOf: (vehicle) =>
          vehicle.photoPath == null ? '${vehicle.type.label} · tap the picture to add a photo' : vehicle.type.label,
      leadingOf: (vehicle) => _VehiclePhoto(vehicle: vehicle),
      formBuilder: (existing) => _VehicleFormSheet(existing: existing),
      afterDelete: (ref, vehicle) => ref.read(vehiclePhotoRepositoryProvider).deleteFileOf(vehicle),
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

/// A vehicle's photo (or its type icon) in the list. Tapping it adds,
/// replaces or removes the photo straight away.
class _VehiclePhoto extends ConsumerStatefulWidget {
  const _VehiclePhoto({required this.vehicle});

  final Vehicle vehicle;

  @override
  ConsumerState<_VehiclePhoto> createState() => _VehiclePhotoState();
}

class _VehiclePhotoState extends ConsumerState<_VehiclePhoto> {
  static const _size = 44.0;
  var _busy = false;

  Future<void> _change() async {
    final vehicle = widget.vehicle;
    final choice = await pickPhoto(
      context,
      title: vehicle.name,
      bucket: PhotoBucket.vehicles,
      canRemove: vehicle.photoPath != null,
    );
    if (choice == null || !mounted) return;
    setState(() => _busy = true);
    final photos = ref.read(vehiclePhotoRepositoryProvider);
    await context.runWithFeedback(() async {
      switch (choice) {
        case PhotoPicked(:final jpeg):
          await photos.setPhoto(vehicle, jpeg);
        case PhotoRemoved():
          await photos.removePhoto(vehicle);
      }
      ref.invalidate(vehiclesControllerProvider);
    });
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final url = ref.watch(photoUrlsProvider).vehicle(widget.vehicle.photoPath);
    final icon = IconTile(icon: vehicleIcon(widget.vehicle.type));
    return Semantics(
      button: true,
      label: url == null ? 'Add a photo of ${widget.vehicle.name}' : 'Change the photo of ${widget.vehicle.name}',
      child: InkWell(
        onTap: _busy ? null : _change,
        borderRadius: BrodieSize.borderRadius,
        child: SizedBox.square(
          dimension: _size,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (url == null)
                Center(child: icon)
              else
                ClipRRect(
                  borderRadius: BrodieSize.borderRadius,
                  child: Image.network(
                    url,
                    fit: BoxFit.cover,
                    cacheWidth: (_size * MediaQuery.devicePixelRatioOf(context)).round(),
                    errorBuilder: (_, _, _) => Center(child: icon),
                  ),
                ),
              if (_busy)
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: colors.background.withValues(alpha: .6),
                    borderRadius: BrodieSize.borderRadius,
                  ),
                  child: const Center(
                    child: SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                  ),
                )
              else if (url == null)
                Align(
                  alignment: Alignment.bottomRight,
                  child: Icon(Icons.add_a_photo, size: 14, color: colors.accent),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
