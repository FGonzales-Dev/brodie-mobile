import 'package:freezed_annotation/freezed_annotation.dart';

part 'vehicle.freezed.dart';

enum VehicleType {
  motorcycle('Motorcycle'),
  bike('Bicycle');

  const VehicleType(this.label);

  final String label;
}

@freezed
abstract class Vehicle with _$Vehicle {
  const factory Vehicle({
    required String id,
    required VehicleType type,
    required String name,

    /// The photo's file in the vehicle-photos bucket; see `PhotoUrls`.
    String? photoPath,
  }) = _Vehicle;
}

/// The fields a user edits; id and owner are assigned by the backend.
typedef VehicleDraft = ({VehicleType type, String name});
