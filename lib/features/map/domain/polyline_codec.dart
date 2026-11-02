import 'map_models.dart';

/// Google's encoded-polyline format, as returned by Mapbox Directions with
/// `geometries=polyline6` (precision 6). Far smaller than GeoJSON, so routes
/// are cheap to download, store on a trip, and share with the group.
abstract final class PolylineCodec {
  static List<GeoPoint> decode(String encoded, {int precision = 6}) {
    final factor = _factor(precision);
    final points = <GeoPoint>[];
    var index = 0;
    var lat = 0;
    var lng = 0;

    int nextValue() {
      var result = 0;
      var shift = 0;
      int byte;
      do {
        byte = encoded.codeUnitAt(index++) - 63;
        result |= (byte & 0x1f) << shift;
        shift += 5;
      } while (byte >= 0x20);
      return (result & 1) != 0 ? ~(result >> 1) : result >> 1;
    }

    while (index < encoded.length) {
      lat += nextValue();
      lng += nextValue();
      points.add(GeoPoint(latitude: lat / factor, longitude: lng / factor));
    }
    return points;
  }

  static String encode(List<GeoPoint> points, {int precision = 6}) {
    final factor = _factor(precision);
    final buffer = StringBuffer();
    var previousLat = 0;
    var previousLng = 0;

    void writeValue(int value) {
      var remaining = value < 0 ? ~(value << 1) : value << 1;
      while (remaining >= 0x20) {
        buffer.writeCharCode((0x20 | (remaining & 0x1f)) + 63);
        remaining >>= 5;
      }
      buffer.writeCharCode(remaining + 63);
    }

    for (final point in points) {
      final lat = (point.latitude * factor).round();
      final lng = (point.longitude * factor).round();
      writeValue(lat - previousLat);
      writeValue(lng - previousLng);
      previousLat = lat;
      previousLng = lng;
    }
    return buffer.toString();
  }

  static int _factor(int precision) {
    var factor = 1;
    for (var i = 0; i < precision; i++) {
      factor *= 10;
    }
    return factor;
  }
}
