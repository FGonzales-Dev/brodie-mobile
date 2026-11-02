import 'package:freezed_annotation/freezed_annotation.dart';

part 'app_user.freezed.dart';

/// The signed-in account, independent of the auth provider's user type.
@freezed
abstract class AppUser with _$AppUser {
  const factory AppUser({required String id, String? email}) = _AppUser;
}
