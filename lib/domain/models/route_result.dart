class RouteResult {
  const RouteResult({
    required this.coordinates,
    required this.distanceMeters,
    required this.durationSeconds,
  });

  /// [longitude, latitude] pairs describing the route geometry, in order.
  final List<(double, double)> coordinates;
  final double distanceMeters;
  final double durationSeconds;

  factory RouteResult.fromJson(Map<String, dynamic> json) {
    final route = (json['routes'] as List).first as Map<String, dynamic>;
    final geometry = route['geometry'] as Map<String, dynamic>;
    final rawCoordinates = geometry['coordinates'] as List;
    return RouteResult(
      coordinates: rawCoordinates
          .map((point) => ((point[0] as num).toDouble(), (point[1] as num).toDouble()))
          .toList(),
      distanceMeters: (route['distance'] as num).toDouble(),
      durationSeconds: (route['duration'] as num).toDouble(),
    );
  }
}
