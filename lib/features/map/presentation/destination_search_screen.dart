import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../../../core/design_system/design_system.dart';
import '../../../core/presentation/feedback.dart';
import '../data/place_search_repository.dart';
import '../application/saved_places_providers.dart';
import '../domain/map_models.dart';
import '../domain/saved_place.dart';
import 'destination_search_controller.dart';
import 'recent_places_controller.dart';

/// Pops the chosen [Place].
class DestinationSearchScreen extends ConsumerStatefulWidget {
  const DestinationSearchScreen({super.key, this.purpose = SearchPurpose.rideDestination});

  final SearchPurpose purpose;

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
      place = await ref.read(destinationSearchControllerProvider(widget.purpose).notifier).resolve(suggestion);
    });
    if (resolved && mounted) _choose(place!);
  }

  /// A spot picked on the map instead of searched for.
  Future<void> _pickOnMap() async {
    final place = await context.push<Place>(Routes.pickOnMap);
    if (place != null && mounted) _choose(place);
  }

  /// Records [place] as a recent search and returns it to the map.
  void _choose(Place place) {
    ref.read(recentPlacesControllerProvider.notifier).add(place);
    context.pop(place);
  }

  @override
  Widget build(BuildContext context) {
    final results = ref.watch(destinationSearchControllerProvider(widget.purpose));

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
          onChanged: ref.read(destinationSearchControllerProvider(widget.purpose).notifier).search,
        ),
      ),
      body: _query.text.trim().length < DestinationSearchController.minQueryLength
          ? _QuickPicks(onSelect: _choose, onPickOnMap: _pickOnMap)
          : AsyncValueView(
              value: results,
              onRetry: () => ref.read(destinationSearchControllerProvider(widget.purpose).notifier).retry(_query.text),
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

/// Shown until the user has typed enough to search: saved places, then
/// recent destinations. Both cost no place search to pick.
class _QuickPicks extends ConsumerWidget {
  const _QuickPicks({required this.onSelect, required this.onPickOnMap});

  final ValueChanged<Place> onSelect;
  final VoidCallback onPickOnMap;

  Future<void> _confirmClear(BuildContext context, WidgetRef ref) async {
    final confirmed = await showBrodieConfirmDialog(
      context,
      title: 'Clear recent searches?',
      message: 'This removes all recent destinations from this device. Saved places stay.',
      confirmLabel: 'Clear',
    );
    if (confirmed) await ref.read(recentPlacesControllerProvider.notifier).clear();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recents = ref.watch(recentPlacesControllerProvider);
    final saved = ref.watch(savedPlacesControllerProvider).value ?? const <SavedPlace>[];
    if (recents.isEmpty && saved.isEmpty) {
      return EmptyState(
        icon: Icons.search,
        title: 'Where to?',
        message:
            'Type at least ${DestinationSearchController.minQueryLength} letters of a place, address or '
            'landmark. Star places you go often to find them here without searching.',
        action: BrodieButton.secondary(label: 'Choose on map', icon: Icons.pin_drop_outlined, onPressed: onPickOnMap),
      );
    }

    final recentController = ref.read(recentPlacesControllerProvider.notifier);
    final savedController = ref.read(savedPlacesControllerProvider.notifier);
    SavedPlace? savedMatch(Place place) => saved.where((entry) => entry.place.isSameAs(place)).firstOrNull;

    Future<void> toggleSaved(Place place) async {
      final match = savedMatch(place);
      await context.runWithFeedback(
        () => match == null ? savedController.add(place) : savedController.remove(match.id),
        successMessage: match == null ? 'Saved ${place.name}' : 'Removed from saved places',
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(BrodieSpace.md, BrodieSpace.sm, BrodieSpace.md, BrodieSpace.lg),
      children: [
        BrodieListGroup(
          children: [
            BrodieListTile(
              leading: const IconTile(icon: Icons.pin_drop_outlined),
              title: 'Choose on map',
              subtitle: 'Move the map to the spot',
              onTap: onPickOnMap,
            ),
          ],
        ),
        if (saved.isNotEmpty) ...[
          const SectionLabel('Saved'),
          BrodieListGroup(
            children: [
              for (final entry in saved)
                BrodieListTile(
                  leading: const IconTile(icon: Icons.star),
                  title: entry.place.name,
                  subtitle: entry.place.address,
                  onTap: () => onSelect(entry.place),
                  trailing: IconButton(
                    tooltip: 'Remove from saved',
                    icon: const Icon(Icons.close),
                    onPressed: () => toggleSaved(entry.place),
                  ),
                ),
            ],
          ),
        ],
        if (recents.isNotEmpty) ...[
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
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: savedMatch(place) == null ? 'Save place' : 'Remove from saved',
                        icon: Icon(
                          savedMatch(place) == null ? Icons.star_border : Icons.star,
                          color: savedMatch(place) == null ? null : context.colors.accent,
                        ),
                        onPressed: () => toggleSaved(place),
                      ),
                      IconButton(
                        tooltip: 'Remove from recent',
                        icon: const Icon(Icons.close),
                        onPressed: () => recentController.remove(place),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}
