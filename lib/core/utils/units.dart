enum DistanceUnit { km, mi }

/// A number and its unit, displayed separately (e.g. in a stat tile).
typedef Measurement = ({String value, String unit});

const _metersPerMile = 1609.344;

Measurement formatDistance(double meters, DistanceUnit unit) {
  final value = switch (unit) {
    DistanceUnit.km => meters / 1000,
    DistanceUnit.mi => meters / _metersPerMile,
  };
  return (value: value.toStringAsFixed(value < 100 ? 1 : 0), unit: unit.name);
}

/// Distance to the next turn: meters (rounded to 10) or feet (rounded to 50)
/// when close, otherwise the same as [formatDistance].
Measurement formatShortDistance(double meters, DistanceUnit unit) {
  const metersPerFoot = 0.3048;
  return switch (unit) {
    DistanceUnit.km when meters < 1000 => (value: '${(meters / 10).round() * 10}', unit: 'm'),
    DistanceUnit.mi when meters < _metersPerMile / 10 => (value: '${(meters / metersPerFoot / 50).round() * 50}', unit: 'ft'),
    _ => formatDistance(meters, unit),
  };
}

Measurement formatSpeed(double metersPerSecond, DistanceUnit unit) {
  final speed = metersPerSecond.isFinite && metersPerSecond > 0 ? metersPerSecond : 0.0;
  return switch (unit) {
    DistanceUnit.km => (value: '${(speed * 3.6).round()}', unit: 'km/h'),
    DistanceUnit.mi => (value: '${(speed * 3600 / _metersPerMile).round()}', unit: 'mph'),
  };
}

/// "45 min" under an hour, "1:28 hrs" from an hour up.
Measurement formatDuration(Duration duration) {
  final minutes = duration.inMinutes;
  if (minutes < 60) return (value: '$minutes', unit: 'min');
  final remainder = (minutes % 60).toString().padLeft(2, '0');
  return (value: '${duration.inHours}:$remainder', unit: 'hrs');
}

extension MeasurementText on Measurement {
  /// "4.0 km", "45 min": the value and unit as one piece of text.
  String get text => '$value $unit';
}
