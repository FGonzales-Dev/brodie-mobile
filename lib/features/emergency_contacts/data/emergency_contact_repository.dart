import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/data/owned_rows_table.dart';
import '../../../core/di/core_providers.dart';
import '../domain/emergency_contact.dart';

part 'emergency_contact_repository.g.dart';

typedef EmergencyContactRepository = OwnedRowsTable<EmergencyContact, EmergencyContactDraft>;

@Riverpod(keepAlive: true)
EmergencyContactRepository emergencyContactRepository(Ref ref) {
  return OwnedRowsTable(
    ref.watch(supabaseClientProvider),
    table: 'emergency_contacts',
    fromRow: (row) => EmergencyContact(
      id: row['id'] as String,
      name: row['name'] as String,
      phone: row['phone'] as String,
      relationship: row['relationship'] as String?,
    ),
    toRow: (draft) => {'name': draft.name, 'phone': draft.phone, 'relationship': draft.relationship},
  );
}
