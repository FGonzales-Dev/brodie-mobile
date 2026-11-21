import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../../../core/design_system/design_system.dart';
import '../../../core/presentation/feedback.dart';
import '../../../core/utils/text.dart';
import '../../auth/application/session_providers.dart';
import '../../map/domain/map_models.dart';
import '../application/group_providers.dart';
import '../data/group_repository.dart';
import '../domain/group_models.dart';

/// Plans [route] to [destination] as the ride of a group the rider leads,
/// picked in a sheet. Reuses the route already fetched for the preview, so
/// it costs no extra Directions request. Returns the group's id once
/// planned, or null if the rider backed out or planning failed.
Future<String?> planGroupRide(
  BuildContext context,
  WidgetRef ref, {
  required Place destination,
  required RouteResult route,
}) async {
  final groupId = await showBrodieSheet<String>(context, builder: (_) => const _LedGroupsSheet());
  if (groupId == null || !context.mounted) return null;

  final planned = await context.runWithFeedback(
    () => ref.read(groupRepositoryProvider).planTrip(groupId: groupId, destination: destination, route: route),
    successMessage: 'Ride planned. Your group can join now.',
  );
  if (!planned) return null;
  ref.invalidate(myGroupsProvider);
  return groupId;
}

/// Groups the rider leads; pops the chosen group's id.
class _LedGroupsSheet extends ConsumerWidget {
  const _LedGroupsSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final me = ref.watch(currentUserProvider)?.id;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(BrodieSpace.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('RIDE WITH WHICH GROUP?', style: BrodieType.title.copyWith(color: colors.textPrimary)),
            const SizedBox(height: BrodieSpace.md),
            AsyncValueView(
              value: ref.watch(myGroupsProvider),
              onRetry: () => ref.invalidate(myGroupsProvider),
              data: (groups) {
                final led = [for (final group in groups) if (group.leaderId == me) group];
                if (led.isEmpty) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Only a group leader can plan its ride. Create a group to lead one.',
                        style: BrodieType.body.copyWith(color: colors.textSecondary),
                      ),
                      const SizedBox(height: BrodieSpace.md),
                      BrodieButton(
                        label: 'Create a group',
                        icon: Icons.add,
                        onPressed: () {
                          Navigator.of(context).pop();
                          context.push(Routes.createGroup);
                        },
                      ),
                    ],
                  );
                }
                return BrodieListGroup(
                  children: [
                    for (final group in led)
                      BrodieListTile(
                        leading: BrodieAvatar(name: group.name),
                        title: group.name,
                        // One open ride per group: the leader cancels the current one first.
                        subtitle: group.openTripStatus == null
                            ? countLabel(group.memberCount, 'rider')
                            : group.openTripStatus == TripStatus.active
                                ? 'Riding now'
                                : 'Already has a ride planned',
                        onTap: group.openTripStatus == null ? () => Navigator.of(context).pop(group.id) : null,
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
