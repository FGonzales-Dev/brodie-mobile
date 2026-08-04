import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../data/repositories/settings_repository.dart';

part 'settings_controller.g.dart';

@riverpod
class ThemeModeController extends _$ThemeModeController {
  @override
  ThemeMode build() => ref.watch(settingsRepositoryProvider).getThemeMode();

  Future<void> setThemeMode(ThemeMode mode) async {
    await ref.read(settingsRepositoryProvider).setThemeMode(mode);
    state = mode;
  }
}

@riverpod
class UnitsController extends _$UnitsController {
  @override
  DistanceUnit build() => ref.watch(settingsRepositoryProvider).getUnits();

  Future<void> setUnits(DistanceUnit unit) async {
    await ref.read(settingsRepositoryProvider).setUnits(unit);
    state = unit;
  }
}

@riverpod
class NotificationsEnabledController extends _$NotificationsEnabledController {
  @override
  bool build() => ref.watch(settingsRepositoryProvider).getNotificationsEnabled();

  Future<void> setEnabled(bool enabled) async {
    await ref.read(settingsRepositoryProvider).setNotificationsEnabled(enabled);
    state = enabled;
  }
}

@riverpod
class BroadcastIntervalController extends _$BroadcastIntervalController {
  @override
  int build() => ref.watch(settingsRepositoryProvider).getBroadcastIntervalSeconds();

  Future<void> setInterval(int seconds) async {
    await ref.read(settingsRepositoryProvider).setBroadcastIntervalSeconds(seconds);
    state = seconds;
  }
}

@riverpod
class BatterySaverController extends _$BatterySaverController {
  @override
  bool build() => ref.watch(settingsRepositoryProvider).getBatterySaver();

  Future<void> setEnabled(bool enabled) async {
    await ref.read(settingsRepositoryProvider).setBatterySaver(enabled);
    state = enabled;
  }
}
