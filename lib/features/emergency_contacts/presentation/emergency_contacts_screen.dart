import 'package:flutter/material.dart';

import '../../../core/design_system/design_system.dart';
import '../../../core/presentation/owned_rows_controller.dart';
import '../../../core/presentation/owned_rows_screen.dart';
import '../../../core/utils/validators.dart';
import '../data/emergency_contact_repository.dart';
import '../domain/emergency_contact.dart';

final emergencyContactsControllerProvider = ownedRowsControllerProvider(emergencyContactRepositoryProvider);

class EmergencyContactsScreen extends StatelessWidget {
  const EmergencyContactsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return OwnedRowsScreen<EmergencyContact, EmergencyContactDraft>(
      provider: emergencyContactsControllerProvider,
      title: 'Emergency contacts',
      noun: 'contact',
      empty: const EmptyState(
        icon: Icons.health_and_safety_outlined,
        title: 'No contacts yet',
        message: 'Add someone we can alert if you trigger an SOS during a ride.',
      ),
      idOf: (contact) => contact.id,
      titleOf: (contact) => contact.name,
      subtitleOf: (contact) => [contact.phone, ?contact.relationship].join(' · '),
      leadingOf: (contact) => BrodieAvatar(name: contact.name),
      formBuilder: (existing) => _ContactFormSheet(existing: existing),
    );
  }
}

class _ContactFormSheet extends StatefulWidget {
  const _ContactFormSheet({this.existing});

  final EmergencyContact? existing;

  @override
  State<_ContactFormSheet> createState() => _ContactFormSheetState();
}

class _ContactFormSheetState extends State<_ContactFormSheet> {
  late final _name = TextEditingController(text: widget.existing?.name);
  late final _phone = TextEditingController(text: widget.existing?.phone);
  late final _relationship = TextEditingController(text: widget.existing?.relationship);

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _relationship.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BrodieFormSheet<EmergencyContactDraft>(
      title: widget.existing == null ? 'Add contact' : 'Edit contact',
      fields: [
        BrodieTextField(
          controller: _name,
          label: 'Name',
          icon: Icons.person_outline,
          textInputAction: TextInputAction.next,
          validator: Validators.required('Enter a name'),
        ),
        BrodieTextField(
          controller: _phone,
          label: 'Phone',
          icon: Icons.phone_outlined,
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.next,
          validator: Validators.required('Enter a phone number'),
        ),
        BrodieTextField(
          controller: _relationship,
          label: 'Relationship (optional)',
          icon: Icons.favorite_border,
          textInputAction: TextInputAction.done,
        ),
      ],
      onSave: () {
        final relationship = _relationship.text.trim();
        return (
          name: _name.text.trim(),
          phone: _phone.text.trim(),
          relationship: relationship.isEmpty ? null : relationship,
        );
      },
    );
  }
}
