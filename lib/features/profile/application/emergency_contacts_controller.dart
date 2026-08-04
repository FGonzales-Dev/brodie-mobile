import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../data/repositories/emergency_contact_repository.dart';
import '../../../domain/models/emergency_contact.dart';

part 'emergency_contacts_controller.g.dart';

@riverpod
class EmergencyContactsController extends _$EmergencyContactsController {
  @override
  FutureOr<List<EmergencyContact>> build() {
    final userId = Supabase.instance.client.auth.currentUser!.id;
    return ref.read(emergencyContactRepositoryProvider).getContacts(userId);
  }

  Future<void> addContact({required String name, required String phone, String? relationship}) async {
    final userId = Supabase.instance.client.auth.currentUser!.id;
    await ref.read(emergencyContactRepositoryProvider).addContact(
          userId: userId,
          name: name,
          phone: phone,
          relationship: relationship,
        );
    await _refresh();
  }

  Future<void> updateContact({
    required String id,
    required String name,
    required String phone,
    String? relationship,
  }) async {
    await ref.read(emergencyContactRepositoryProvider).updateContact(
          id: id,
          name: name,
          phone: phone,
          relationship: relationship,
        );
    await _refresh();
  }

  Future<void> deleteContact(String id) async {
    await ref.read(emergencyContactRepositoryProvider).deleteContact(id);
    await _refresh();
  }

  Future<void> _refresh() async {
    final userId = Supabase.instance.client.auth.currentUser!.id;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => ref.read(emergencyContactRepositoryProvider).getContacts(userId));
  }
}
