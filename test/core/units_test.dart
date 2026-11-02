import 'package:brodie/core/utils/units.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('formatDistance converts to the chosen unit', () {
    expect(formatDistance(64200, DistanceUnit.km), (value: '64.2', unit: 'km'));
    expect(formatDistance(16093.44, DistanceUnit.mi), (value: '10.0', unit: 'mi'));
    expect(formatDistance(250000, DistanceUnit.km), (value: '250', unit: 'km'));
  });

  test('formatDuration uses minutes under an hour, h:mm above', () {
    expect(formatDuration(const Duration(minutes: 45)), (value: '45', unit: 'min'));
    expect(formatDuration(const Duration(minutes: 88)), (value: '1:28', unit: 'hrs'));
    expect(formatDuration(const Duration(hours: 2, minutes: 5)), (value: '2:05', unit: 'hrs'));
  });

  test('formatShortDistance rounds near distances for the turn banner', () {
    expect(formatShortDistance(347, DistanceUnit.km), (value: '350', unit: 'm'));
    expect(formatShortDistance(1450, DistanceUnit.km), (value: '1.4', unit: 'km'));
    expect(formatShortDistance(100, DistanceUnit.mi), (value: '350', unit: 'ft'));
    expect(formatShortDistance(800, DistanceUnit.mi), (value: '0.5', unit: 'mi'));
  });

  test('formatSpeed converts GPS m/s and treats unknown speed as 0', () {
    expect(formatSpeed(22.2, DistanceUnit.km), (value: '80', unit: 'km/h'));
    expect(formatSpeed(22.2, DistanceUnit.mi), (value: '50', unit: 'mph'));
    expect(formatSpeed(-1, DistanceUnit.km), (value: '0', unit: 'km/h'));
  });
}
