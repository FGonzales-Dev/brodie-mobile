import 'package:brodie/core/di/core_providers.dart';
import 'package:brodie/core/utils/units.dart';
import 'package:brodie/features/settings/application/settings_controller.dart';
import 'package:brodie/features/settings/domain/app_settings.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<ProviderContainer> _container(Map<String, Object> stored) async {
  SharedPreferences.setMockInitialValues(stored);
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(overrides: [sharedPreferencesProvider.overrideWithValue(prefs)]);
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('loads defaults when nothing is stored', () async {
    final container = await _container({});

    expect(container.read(settingsControllerProvider), const AppSettings());
  });

  test('reads values stored under the existing keys', () async {
    final container = await _container({'settings.theme_mode': 'dark', 'settings.units': 'mi'});

    final settings = container.read(settingsControllerProvider);
    expect(settings.theme, ThemePreference.dark);
    expect(settings.units, DistanceUnit.mi);
  });

  test('update changes state and persists it', () async {
    final container = await _container({});

    await container.read(settingsControllerProvider.notifier).update((s) => s.copyWith(batterySaver: true));

    expect(container.read(settingsControllerProvider).batterySaver, isTrue);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('settings.battery_saver'), isTrue);
  });
}
