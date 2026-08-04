import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'settings_repository.g.dart';

enum DistanceUnit { km, mi }

class SettingsRepository {
  SettingsRepository(this._prefs);

  final SharedPreferences _prefs;

  static const _themeModeKey = 'settings.theme_mode';
  static const _unitsKey = 'settings.units';
  static const _notificationsEnabledKey = 'settings.notifications_enabled';
  static const _broadcastIntervalKey = 'settings.broadcast_interval_seconds';
  static const _batterySaverKey = 'settings.battery_saver';

  ThemeMode getThemeMode() {
    final value = _prefs.getString(_themeModeKey);
    return ThemeMode.values.firstWhere((mode) => mode.name == value, orElse: () => ThemeMode.system);
  }

  Future<void> setThemeMode(ThemeMode mode) => _prefs.setString(_themeModeKey, mode.name);

  DistanceUnit getUnits() {
    final value = _prefs.getString(_unitsKey);
    return DistanceUnit.values.firstWhere((unit) => unit.name == value, orElse: () => DistanceUnit.km);
  }

  Future<void> setUnits(DistanceUnit unit) => _prefs.setString(_unitsKey, unit.name);

  bool getNotificationsEnabled() => _prefs.getBool(_notificationsEnabledKey) ?? true;

  Future<void> setNotificationsEnabled(bool enabled) => _prefs.setBool(_notificationsEnabledKey, enabled);

  int getBroadcastIntervalSeconds() => _prefs.getInt(_broadcastIntervalKey) ?? 5;

  Future<void> setBroadcastIntervalSeconds(int seconds) => _prefs.setInt(_broadcastIntervalKey, seconds);

  bool getBatterySaver() => _prefs.getBool(_batterySaverKey) ?? false;

  Future<void> setBatterySaver(bool enabled) => _prefs.setBool(_batterySaverKey, enabled);
}

@Riverpod(keepAlive: true)
SharedPreferences sharedPreferences(Ref ref) {
  throw UnimplementedError('sharedPreferencesProvider must be overridden in main() with a loaded instance');
}

@riverpod
SettingsRepository settingsRepository(Ref ref) {
  return SettingsRepository(ref.watch(sharedPreferencesProvider));
}
