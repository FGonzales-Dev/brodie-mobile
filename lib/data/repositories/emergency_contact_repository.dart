import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/models/emergency_contact.dart';

part 'emergency_contact_repository.g.dart';

class EmergencyContactRepository {
  EmergencyContactRepository(this._client);

  final SupabaseClient _client;

  Future<List<EmergencyContact>> getContacts(String userId) async {
    final response = await _client.from('emergency_contacts').select().eq('user_id', userId).order('created_at');
    return response.map(EmergencyContact.fromJson).toList();
  }

  Future<EmergencyContact> addContact({
    required String userId,
    required String name,
    required String phone,
    String? relationship,
  }) async {
    final response = await _client
        .from('emergency_contacts')
        .insert({'user_id': userId, 'name': name, 'phone': phone, 'relationship': relationship})
        .select()
        .single();
    return EmergencyContact.fromJson(response);
  }

  Future<EmergencyContact> updateContact({
    required String id,
    required String name,
    required String phone,
    String? relationship,
  }) async {
    final response = await _client
        .from('emergency_contacts')
        .update({'name': name, 'phone': phone, 'relationship': relationship})
        .eq('id', id)
        .select()
        .single();
    return EmergencyContact.fromJson(response);
  }

  Future<void> deleteContact(String id) {
    return _client.from('emergency_contacts').delete().eq('id', id);
  }
}

@riverpod
EmergencyContactRepository emergencyContactRepository(Ref ref) {
  return EmergencyContactRepository(Supabase.instance.client);
}
