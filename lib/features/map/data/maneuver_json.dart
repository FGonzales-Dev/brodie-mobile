import '../domain/map_models.dart';

/// Turn instructions as `mapbox-directions` returns them and group trips
/// store them: `{instruction, type, modifier, lng, lat}`.
abstract final class ManeuverJson {
  static List<RouteManeuver> decodeAll(Object? json) => [
    for (final item in (json as List? ?? const []).cast<Map<String, dynamic>>()) decode(item),
  ];

  static RouteManeuver decode(Map<String, dynamic> json) => RouteManeuver(
    instruction: json['instruction'] as String,
    type: json['type'] as String,
    modifier: json['modifier'] as String?,
    location: GeoPoint(latitude: (json['lat'] as num).toDouble(), longitude: (json['lng'] as num).toDouble()),
  );

  static List<Map<String, Object?>> encodeAll(List<RouteManeuver> maneuvers) => [
    for (final maneuver in maneuvers)
      {
        'instruction': maneuver.instruction,
        'type': maneuver.type,
        'modifier': maneuver.modifier,
        'lng': maneuver.location.longitude,
        'lat': maneuver.location.latitude,
      },
  ];
}
