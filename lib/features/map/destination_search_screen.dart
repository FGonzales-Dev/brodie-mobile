import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/search_suggestion.dart';
import 'application/destination_search_controller.dart';

class DestinationSearchScreen extends ConsumerStatefulWidget {
  const DestinationSearchScreen({super.key});

  @override
  ConsumerState<DestinationSearchScreen> createState() => _DestinationSearchScreenState();
}

class _DestinationSearchScreenState extends ConsumerState<DestinationSearchScreen> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _selectSuggestion(SearchSuggestion suggestion) async {
    try {
      final place = await ref.read(destinationSearchControllerProvider.notifier).retrieve(suggestion);
      if (mounted) Navigator.of(context).pop(place);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not get location details: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final suggestionsAsync = ref.watch(destinationSearchControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: true,
          textInputAction: TextInputAction.search,
          decoration: const InputDecoration(
            hintText: 'Search destination',
            border: InputBorder.none,
          ),
          onChanged: (value) => ref.read(destinationSearchControllerProvider.notifier).updateQuery(value),
        ),
      ),
      body: suggestionsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Search failed: $error')),
        data: (suggestions) {
          if (_controller.text.trim().isEmpty) {
            return const Center(child: Text('Start typing to search for a destination'));
          }
          if (suggestions.isEmpty) {
            return const Center(child: Text('No results'));
          }
          return ListView.builder(
            itemCount: suggestions.length,
            itemBuilder: (context, index) {
              final suggestion = suggestions[index];
              return ListTile(
                leading: const Icon(Icons.place_outlined),
                title: Text(suggestion.name),
                subtitle: suggestion.fullAddress != null ? Text(suggestion.fullAddress!) : null,
                onTap: () => _selectSuggestion(suggestion),
              );
            },
          );
        },
      ),
    );
  }
}
