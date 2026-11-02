import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/location_repository.dart';
import '../domain/map_models.dart';

part 'location_access_controller.g.dart';

/// Location permission state, shared by the map (to gate it) and settings
/// (to display it). Screens refresh it when the app resumes, since the user
/// may have changed it in system settings.
@Riverpod(keepAlive: true)
class LocationAccessController extends _$LocationAccessController {
  @override
  Future<LocationAccess> build() => ref.watch(locationRepositoryProvider).checkAccess();

  Future<void> request() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => ref.read(locationRepositoryProvider).requestAccess());
  }

  /// Opens the system screen that can fix the current state.
  Future<void> openSystemSettings() {
    final repository = ref.read(locationRepositoryProvider);
    return state.value == LocationAccess.serviceDisabled
        ? repository.openLocationSettings()
        : repository.openAppSettings();
  }

  /// The device's location settings, e.g. to turn on Wi-Fi-assisted
  /// positioning when GPS can't get a fix.
  Future<void> openLocationSettings() => ref.read(locationRepositoryProvider).openLocationSettings();

  void refresh() => ref.invalidateSelf();
}
