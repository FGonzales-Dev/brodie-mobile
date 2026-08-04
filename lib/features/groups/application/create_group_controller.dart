import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../data/repositories/group_ride_repository.dart';
import '../../../domain/models/ride_group.dart';

part 'create_group_controller.g.dart';

@riverpod
class CreateGroupController extends _$CreateGroupController {
  @override
  FutureOr<RideGroup?> build() => null;

  Future<RideGroup?> createGroup({required String name}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() {
      return ref.read(groupRideRepositoryProvider).createGroup(name: name);
    });
    return state.value;
  }
}
