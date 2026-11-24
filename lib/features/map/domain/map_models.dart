import 'package:freezed_annotation/freezed_annotation.dart';

part 'map_models.freezed.dart';

@freezed
abstract class GeoPoint with _$GeoPoint {
  const factory GeoPoint({required double latitude, required double longitude}) = _GeoPoint;
}

/// One reading from the device's GPS.
@freezed
abstract class GeoFix with _$GeoFix {
  const factory GeoFix({
    required GeoPoint position,
    required double accuracyMeters,
    required double speedMps,
    required double headingDegrees,
    required DateTime timestamp,
  }) = _GeoFix;
}

/// A search-as-you-type result; resolve it to a [Place] to get coordinates.
@freezed
abstract class PlaceSuggestion with _$PlaceSuggestion {
  const factory PlaceSuggestion({required String id, required String name, String? address}) = _PlaceSuggestion;
}

@freezed
abstract class Place with _$Place {
  const factory Place({required String name, String? address, required GeoPoint location}) = _Place;

  const Place._();

  /// Same name within about a meter: search can return the same place with
  /// slightly different coordinates.
  bool isSameAs(Place other) {
    const tolerance = 1e-5;
    return name == other.name &&
        (location.latitude - other.location.latitude).abs() < tolerance &&
        (location.longitude - other.location.longitude).abs() < tolerance;
  }
}

@freezed
abstract class RouteResult with _$RouteResult {
  const factory RouteResult({
    required List<GeoPoint> path,
    required double distanceMeters,
    required Duration duration,

    /// [path] in polyline6 form, for storing on a trip or sharing.
    required String encodedPolyline,

    /// Turn-by-turn instructions in route order, starting with "depart".
    @Default(<RouteManeuver>[]) List<RouteManeuver> maneuvers,
  }) = _RouteResult;
}

/// One instruction along a route, e.g. "Turn right onto Romulo Highway".
/// [type] and [modifier] are Mapbox maneuver values ("turn" + "right").
@freezed
abstract class RouteManeuver with _$RouteManeuver {
  const factory RouteManeuver({
    required String instruction,
    required String type,
    String? modifier,
    required GeoPoint location,
  }) = _RouteManeuver;
}

enum LocationAccess {
  always,
  whileInUse,
  denied,
  deniedForever,
  serviceDisabled;

  bool get isGranted => this == always || this == whileInUse;
}
