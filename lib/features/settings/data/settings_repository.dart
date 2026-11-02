import 'package:package_info_plus/package_info_plus.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/di/core_providers.dart';
import '../../../core/utils/units.dart';
import '../domain/app_settings.dart';

part 'settings_repository.g.dart';

/// Device-local preferences. Keys are unchanged from earlier builds so
/// existing installs keep their settings.
class SettingsRepository {
  SettingsRepository(this._prefs);

  final SharedPreferences _prefs;

  static const _themeKey = 'settings.theme_mode';
  static const _unitsKey = 'settings.units';
  static const _notificationsKey = 'settings.notifications_enabled';
  static const _broadcastIntervalKey = 'settings.broadcast_interval_seconds';
  static const _batterySaverKey = 'settings.battery_saver';

  AppSettings load() {
    const defaults = AppSettings();
    return AppSettings(
      theme: _enumByName(ThemePreference.values, _prefs.getString(_themeKey)) ?? defaults.theme,
      units: _enumByName(DistanceUnit.values, _prefs.getString(_unitsKey)) ?? defaults.units,
      notificationsEnabled: _prefs.getBool(_notificationsKey) ?? defaults.notificationsEnabled,
      broadcastIntervalSeconds: _prefs.getInt(_broadcastIntervalKey) ?? defaults.broadcastIntervalSeconds,
      batterySaver: _prefs.getBool(_batterySaverKey) ?? defaults.batterySaver,
    );
  }

  Future<void> save(AppSettings settings) async {
    await Future.wait([
      _prefs.setString(_themeKey, settings.theme.name),
      _prefs.setString(_unitsKey, settings.units.name),
      _prefs.setBool(_notificationsKey, settings.notificationsEnabled),
      _prefs.setInt(_broadcastIntervalKey, settings.broadcastIntervalSeconds),
      _prefs.setBool(_batterySaverKey, settings.batterySaver),
    ]);
  }

  static T? _enumByName<T extends Enum>(List<T> values, String? name) {
    for (final value in values) {
      if (value.name == name) return value;
    }
    return null;
  }
}

@Riverpod(keepAlive: true)
SettingsRepository settingsRepository(Ref ref) => SettingsRepository(ref.watch(sharedPreferencesProvider));

/// "1.0.0 (1)" for the About screen.
@riverpod
Future<String> appVersion(Ref ref) async {
  final info = await PackageInfo.fromPlatform();
  return '${info.version} (${info.buildNumber})';
}
