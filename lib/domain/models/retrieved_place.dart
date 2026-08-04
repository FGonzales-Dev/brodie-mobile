class RetrievedPlace {
  const RetrievedPlace({
    required this.name,
    this.fullAddress,
    required this.longitude,
    required this.latitude,
  });

  final String name;
  final String? fullAddress;
  final double longitude;
  final double latitude;

  factory RetrievedPlace.fromJson(Map<String, dynamic> json) {
    final feature = (json['features'] as List).first as Map<String, dynamic>;
    final geometry = feature['geometry'] as Map<String, dynamic>;
    final coordinates = geometry['coordinates'] as List;
    final properties = feature['properties'] as Map<String, dynamic>;
    return RetrievedPlace(
      name: properties['name'] as String,
      fullAddress: properties['full_address'] as String? ?? properties['place_formatted'] as String?,
      longitude: (coordinates[0] as num).toDouble(),
      latitude: (coordinates[1] as num).toDouble(),
    );
  }
}
