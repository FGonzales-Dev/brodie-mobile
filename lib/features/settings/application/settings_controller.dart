import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/settings_repository.dart';
import '../domain/app_settings.dart';

part 'settings_controller.g.dart';

/// App-wide preferences. One controller with one update method instead of a
/// controller per setting; read with `.select` to watch a single field.
@Riverpod(keepAlive: true)
class SettingsController extends _$SettingsController {
  @override
  AppSettings build() => ref.watch(settingsRepositoryProvider).load();

  Future<void> update(AppSettings Function(AppSettings current) change) async {
    state = change(state);
    await ref.read(settingsRepositoryProvider).save(state);
  }
}
