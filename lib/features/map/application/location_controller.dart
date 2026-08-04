import 'package:geolocator/geolocator.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../data/repositories/location_repository.dart';

part 'location_controller.g.dart';

@riverpod
class LocationPermissionController extends _$LocationPermissionController {
  @override
  FutureOr<LocationPermission> build() {
    return ref.read(locationRepositoryProvider).checkPermission();
  }

  Future<void> request() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => ref.read(locationRepositoryProvider).requestWhileInUsePermission());
  }
}

@riverpod
Stream<Position> currentPositionStream(Ref ref) {
  final permission = ref.watch(locationPermissionControllerProvider).value;
  final hasAccess = permission == LocationPermission.always || permission == LocationPermission.whileInUse;
  if (!hasAccess) return const Stream.empty();
  return ref.read(locationRepositoryProvider).positionStream();
}
