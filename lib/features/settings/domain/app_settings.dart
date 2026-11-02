import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../core/utils/units.dart';

part 'app_settings.freezed.dart';

enum ThemePreference { system, light, dark }

@freezed
abstract class AppSettings with _$AppSettings {
  const factory AppSettings({
    @Default(ThemePreference.system) ThemePreference theme,
    @Default(DistanceUnit.km) DistanceUnit units,
    @Default(true) bool notificationsEnabled,
    @Default(5) int broadcastIntervalSeconds,
    @Default(false) bool batterySaver,
  }) = _AppSettings;
}
