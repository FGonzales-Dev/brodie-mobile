import 'package:brodie/features/map/data/directions_repository.dart';
import 'package:brodie/features/map/domain/map_models.dart';
import 'package:brodie/features/map/domain/polyline_codec.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Reference example from Google's encoded polyline documentation.
  const googleExample = '_p~iF~ps|U_ulLnnqC_mqNvxq`@';
  const googlePoints = [
    GeoPoint(latitude: 38.5, longitude: -120.2),
    GeoPoint(latitude: 40.7, longitude: -120.95),
    GeoPoint(latitude: 43.252, longitude: -126.453),
  ];

  test('decodes and encodes the reference example at precision 5', () {
    expect(PolylineCodec.decode(googleExample, precision: 5), googlePoints);
    expect(PolylineCodec.encode(googlePoints, precision: 5), googleExample);
  });

  test('round-trips at precision 6 (Mapbox polyline6)', () {
    const points = [
      GeoPoint(latitude: 14.599512, longitude: 120.984219),
      GeoPoint(latitude: 14.115286, longitude: 120.962031),
      GeoPoint(latitude: -33.868820, longitude: 151.209296),
    ];

    expect(PolylineCodec.decode(PolylineCodec.encode(points)), points);
  });

  test('decodes an empty polyline to no points', () {
    expect(PolylineCodec.decode(''), isEmpty);
  });

  test('DirectionsRepository reads the Edge Function response', () {
    const path = [GeoPoint(latitude: 14.5995, longitude: 120.9842), GeoPoint(latitude: 14.1153, longitude: 120.962)];
    final encoded = PolylineCodec.encode(path);

    final route = DirectionsRepository.routeFromResponse({
      'polyline6': encoded,
      'distance_m': 66184.664,
      'duration_s': 5728.228,
      'maneuvers': [
        {'instruction': 'Turn right onto Romulo Highway', 'type': 'turn', 'modifier': 'right', 'lng': 120.97, 'lat': 14.3},
        {'instruction': 'You have arrived', 'type': 'arrive', 'modifier': null, 'lng': 120.962, 'lat': 14.1153},
      ],
    });

    expect(route.maneuvers.first.modifier, 'right');
    expect(route.maneuvers.last.location, const GeoPoint(latitude: 14.1153, longitude: 120.962));

    expect(route.path, path);
    expect(route.distanceMeters, 66184.664);
    expect(route.duration, const Duration(seconds: 5728));
    expect(route.encodedPolyline, encoded);
  });
}
