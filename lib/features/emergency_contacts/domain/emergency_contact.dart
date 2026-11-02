import 'package:freezed_annotation/freezed_annotation.dart';

part 'emergency_contact.freezed.dart';

@freezed
abstract class EmergencyContact with _$EmergencyContact {
  const factory EmergencyContact({
    required String id,
    required String name,
    required String phone,
    String? relationship,
  }) = _EmergencyContact;
}

/// The fields a user edits; id and owner are assigned by the backend.
typedef EmergencyContactDraft = ({String name, String phone, String? relationship});
