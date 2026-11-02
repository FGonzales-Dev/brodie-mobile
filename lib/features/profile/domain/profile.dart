import 'package:freezed_annotation/freezed_annotation.dart';

part 'profile.freezed.dart';

@freezed
abstract class Profile with _$Profile {
  const factory Profile({required String id, String? username, String? avatarUrl}) = _Profile;

  const Profile._();

  /// Users must pick a username before they can use the app.
  bool get hasUsername => username?.isNotEmpty ?? false;
}
