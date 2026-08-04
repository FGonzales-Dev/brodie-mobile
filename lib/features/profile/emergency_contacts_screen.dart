import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/emergency_contact.dart';
import 'application/emergency_contacts_controller.dart';

class EmergencyContactsScreen extends ConsumerWidget {
  const EmergencyContactsScreen({super.key});

  Future<void> _showContactForm(BuildContext context, WidgetRef ref, {EmergencyContact? contact}) async {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: contact?.name);
    final phoneController = TextEditingController(text: contact?.phone);
    final relationshipController = TextEditingController(text: contact?.relationship);

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(contact == null ? 'Add Emergency Contact' : 'Edit Emergency Contact'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameController,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Name'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return 'Enter a name';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Phone'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return 'Enter a phone number';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: relationshipController,
                decoration: const InputDecoration(labelText: 'Relationship (optional)'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.of(dialogContext).pop(true);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result != true) return;

    final controller = ref.read(emergencyContactsControllerProvider.notifier);
    final relationship = relationshipController.text.trim().isEmpty ? null : relationshipController.text.trim();
    if (contact == null) {
      await controller.addContact(
        name: nameController.text.trim(),
        phone: phoneController.text.trim(),
        relationship: relationship,
      );
    } else {
      await controller.updateContact(
        id: contact.id,
        name: nameController.text.trim(),
        phone: phoneController.text.trim(),
        relationship: relationship,
      );
    }
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, EmergencyContact contact) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete contact?'),
        content: Text('Remove "${contact.name}" from your emergency contacts.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(dialogContext).colorScheme.error),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(emergencyContactsControllerProvider.notifier).deleteContact(contact.id);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contactsAsync = ref.watch(emergencyContactsControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Emergency Contacts')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showContactForm(context, ref),
        child: const Icon(Icons.add),
      ),
      body: contactsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Could not load contacts: $error')),
        data: (contacts) {
          if (contacts.isEmpty) {
            return const Center(child: Text('No emergency contacts yet. Tap + to add one.'));
          }
          return ListView.builder(
            itemCount: contacts.length,
            itemBuilder: (context, index) {
              final contact = contacts[index];
              return ListTile(
                leading: const Icon(Icons.emergency_outlined),
                title: Text(contact.name),
                subtitle: Text([contact.phone, if (contact.relationship != null) contact.relationship!].join(' · ')),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () => _showContactForm(context, ref, contact: contact),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _confirmDelete(context, ref, contact),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
