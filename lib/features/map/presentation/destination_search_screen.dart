import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design_system/design_system.dart';
import '../../../core/presentation/feedback.dart';
import '../domain/map_models.dart';
import 'destination_search_controller.dart';
import 'recent_places_controller.dart';

/// Pops the chosen [Place].
class DestinationSearchScreen extends ConsumerStatefulWidget {
  const DestinationSearchScreen({super.key});

  @override
  ConsumerState<DestinationSearchScreen> createState() => _DestinationSearchScreenState();
}

class _DestinationSearchScreenState extends ConsumerState<DestinationSearchScreen> {
  final _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _select(PlaceSuggestion suggestion) async {
    Place? place;
    final resolved = await context.runWithFeedback(() async {
      place = await ref.read(destinationSearchControllerProvider.notifier).resolve(suggestion);
    });
    if (resolved && mounted) _choose(place!);
  }

  /// Records [place] as a recent search and returns it to the map.
  void _choose(Place place) {
    ref.read(recentPlacesControllerProvider.notifier).add(place);
    context.pop(place);
  }

  @override
  Widget build(BuildContext context) {
    final results = ref.watch(destinationSearchControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _query,
          autofocus: true,
          textInputAction: TextInputAction.search,
          style: BrodieType.body.copyWith(fontSize: 17, color: context.colors.textPrimary),
          decoration: const InputDecoration(
            hintText: 'Where to?',
            filled: false,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
          ),
          onChanged: ref.read(destinationSearchControllerProvider.notifier).search,
        ),
      ),
      body: _query.text.trim().length < DestinationSearchController.minQueryLength
          ? _RecentPlaces(onSelect: _choose)
          : AsyncValueView(
              value: results,
              onRetry: () => ref.read(destinationSearchControllerProvider.notifier).search(_query.text),
              data: (suggestions) => suggestions.isEmpty
                  ? const EmptyState(icon: Icons.wrong_location_outlined, title: 'No results')
                  : ListView(
                      padding: const EdgeInsets.all(BrodieSpace.md),
                      children: [
                        BrodieListGroup(
                          children: [
                            for (final suggestion in suggestions)
                              BrodieListTile(
                                leading: const IconTile(icon: Icons.place_outlined),
                                title: suggestion.name,
                                subtitle: suggestion.address,
                                onTap: () => _select(suggestion),
                              ),
                          ],
                        ),
                      ],
                    ),
            ),
    );
  }
}

/// Shown until the user has typed enough to search: their recent
/// destinations, or a hint when there are none.
class _RecentPlaces extends ConsumerWidget {
  const _RecentPlaces({required this.onSelect});

  final ValueChanged<Place> onSelect;

  Future<void> _confirmClear(BuildContext context, WidgetRef ref) async {
    final confirmed = await showBrodieConfirmDialog(
      context,
      title: 'Clear recent searches?',
      message: 'This removes all recent destinations from this device.',
      confirmLabel: 'Clear',
    );
    if (confirmed) await ref.read(recentPlacesControllerProvider.notifier).clear();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recents = ref.watch(recentPlacesControllerProvider);
    if (recents.isEmpty) {
      return const EmptyState(
        icon: Icons.search,
        title: 'Where to?',
        message: 'Type at least ${DestinationSearchController.minQueryLength} letters of a place, address or landmark.',
      );
    }

    final controller = ref.read(recentPlacesControllerProvider.notifier);
    return ListView(
      padding: const EdgeInsets.fromLTRB(BrodieSpace.md, 0, BrodieSpace.md, BrodieSpace.lg),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const Expanded(child: SectionLabel('Recent')),
            TextButton(onPressed: () => _confirmClear(context, ref), child: const Text('Clear all')),
          ],
        ),
        BrodieListGroup(
          children: [
            for (final place in recents)
              BrodieListTile(
                leading: const IconTile(icon: Icons.history),
                title: place.name,
                subtitle: place.address,
                onTap: () => onSelect(place),
                trailing: IconButton(
                  tooltip: 'Remove',
                  icon: const Icon(Icons.close),
                  onPressed: () => controller.remove(place),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
