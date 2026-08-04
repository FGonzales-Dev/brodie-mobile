enum VehicleType { motorcycle, bike }

class Vehicle {
  const Vehicle({
    required this.id,
    required this.userId,
    required this.type,
    required this.name,
  });

  final String id;
  final String userId;
  final VehicleType type;
  final String name;

  factory Vehicle.fromJson(Map<String, dynamic> json) => Vehicle(
        id: json['id'] as String,
        userId: json['user_id'] as String,
        type: VehicleType.values.byName(json['type'] as String),
        name: json['name'] as String,
      );
}
