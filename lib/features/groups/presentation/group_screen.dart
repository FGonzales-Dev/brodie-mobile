import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../../../core/design_system/design_system.dart';
import '../../../core/presentation/feedback.dart';
import '../../../core/utils/units.dart';
import '../../auth/application/session_providers.dart';
import '../../map/domain/map_models.dart';
import '../../map/presentation/widgets/route_overview_map.dart';
import '../../settings/application/settings_controller.dart';
import '../application/group_lobby_controller.dart';
import '../application/group_providers.dart';
import '../domain/group_models.dart';
import 'group_controllers.dart';

/// A group and its ride lobby: the trip the leader planned, who has joined,
/// and the actions for the rider's role (plan, start or cancel for the
/// leader; join or leave for everyone else).
class GroupScreen extends ConsumerStatefulWidget {
  const GroupScreen({super.key, required this.groupId});

  final String groupId;

  @override
  ConsumerState<GroupScreen> createState() => _GroupScreenState();
}

class _GroupScreenState extends ConsumerState<GroupScreen> {
  /// An action is running; its button shows a spinner and the others wait.
  var _busy = false;

  GroupLobbyController get _lobby => ref.read(groupLobbyControllerProvider(widget.groupId).notifier);

  Future<void> _run(Future<void> Function() action, {String? successMessage}) async {
    setState(() => _busy = true);
    await context.runWithFeedback(action, successMessage: successMessage);
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _plan() async {
    final destination = await context.push<Place>(Routes.destinationSearch);
    if (destination == null || !mounted) return;
    await _run(() => _lobby.planTo(destination), successMessage: 'Ride planned. Your group can join now.');
  }

  Future<void> _cancel() async {
    final confirmed = await showBrodieConfirmDialog(
      context,
      title: 'Cancel ride?',
      message: 'Everyone who joined is taken out of the lobby.',
      confirmLabel: 'Cancel ride',
    );
    if (confirmed && mounted) await _run(_lobby.cancel, successMessage: 'Ride cancelled');
  }

  Future<void> _leave() async {
    final confirmed = await showBrodieConfirmDialog(
      context,
      title: 'Leave ride?',
      message: 'You can join again while the ride is open.',
      confirmLabel: 'Leave',
    );
    if (confirmed && mounted) await _run(_lobby.leave);
  }

  @override
  Widget build(BuildContext context) {
    final group = ref.watch(groupByIdProvider(widget.groupId)).value;
    final lobby = ref.watch(groupLobbyControllerProvider(widget.groupId));
    final me = ref.watch(currentUserProvider)?.id;
    final isLeader = group != null && group.leaderId == me;

    return Scaffold(
      appBar: BrodieAppBar(
        title: group?.name ?? 'Group',
        actions: [
          IconButton(
            tooltip: 'Members and invites',
            icon: const Icon(Icons.person_add_alt),
            onPressed: () => context.push(Routes.groupInvite(widget.groupId)),
          ),
        ],
      ),
      body: AsyncValueView(
        value: lobby,
        onRetry: () => ref.invalidate(groupLobbyControllerProvider(widget.groupId)),
        data: (lobby) => RefreshIndicator(
          onRefresh: () => ref.refresh(groupLobbyControllerProvider(widget.groupId).future),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              if (lobby == null)
                EmptyState(
                  icon: Icons.route_outlined,
                  title: 'No ride planned',
                  message: isLeader
                      ? 'Pick a destination. Your group can then join the ride.'
                      : "Your leader hasn't planned a ride yet.",
                  action: isLeader
                      ? BrodieButton(label: 'Plan a ride', icon: Icons.add_road, isLoading: _busy, onPressed: _plan)
                      : null,
                )
              else
                _Lobby(groupId: widget.groupId, lobby: lobby, me: me),
            ],
          ),
        ),
      ),
      bottomNavigationBar: switch (lobby.value) {
        final GroupLobby lobby => _LobbyActions(
            lobby: lobby,
            isLeader: isLeader,
            joined: lobby.riders.any((rider) => rider.userId == me),
            busy: _busy,
            onStart: () => _run(_lobby.start, successMessage: 'Ride started'),
            onCancel: _cancel,
            onJoin: () => _run(_lobby.join),
            onLeave: _leave,
          ),
        _ => null,
      },
    );
  }
}

class _Lobby extends ConsumerWidget {
  const _Lobby({required this.groupId, required this.lobby, required this.me});

  final String groupId;
  final GroupLobby lobby;
  final String? me;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final units = ref.watch(settingsControllerProvider.select((settings) => settings.units));
    final (:trip, :riders) = lobby;
    final distance = formatDistance(trip.route.distanceMeters, units);
    final duration = formatDuration(trip.route.duration);
    final active = trip.status == TripStatus.active;
    final leader = riders.where((rider) => rider.isLeader).firstOrNull;

    final joinedIds = {for (final rider in riders) rider.userId};
    final members = ref.watch(groupMembersControllerProvider(groupId)).value ?? const [];
    final notJoined = [for (final member in members) if (!joinedIds.contains(member.userId)) member];

    final String status;
    if (active) {
      final startedAt = trip.startedAt;
      final time = startedAt == null
          ? null
          : MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(startedAt.toLocal()));
      status = time == null ? 'Riding now' : 'Riding now · started $time';
    } else {
      status = leader == null || leader.userId == me
          ? 'Lobby open · start when everyone is in'
          : 'Lobby open · waiting for @${leader.username ?? 'leader'} to start';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(height: 220, child: RouteOverviewMap(path: trip.route.path)),
        Padding(
          padding: const EdgeInsets.all(BrodieSpace.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                (trip.name ?? 'Group ride').toUpperCase(),
                style: BrodieType.headline.copyWith(color: colors.textPrimary),
              ),
              const SizedBox(height: BrodieSpace.xxs),
              Text(
                '${distance.value} ${distance.unit} · ${duration.value} ${duration.unit} · meet at the start of the route',
                style: BrodieType.body.copyWith(color: colors.textSecondary),
              ),
              const SizedBox(height: BrodieSpace.sm),
              Row(
                children: [
                  Icon(active ? Icons.sports_motorsports : Icons.hourglass_top, size: 18, color: active ? colors.success : colors.accent),
                  const SizedBox(width: BrodieSpace.xs),
                  Expanded(child: Text(status, style: BrodieType.bodyStrong.copyWith(color: colors.textPrimary))),
                ],
              ),
              SectionLabel('Riders (${riders.length})'),
              BrodieListGroup(
                children: [
                  for (final rider in riders)
                    BrodieListTile(
                      leading: BrodieAvatar(name: rider.username ?? '?', highlighted: rider.userId == me),
                      title: '@${rider.username ?? 'rider'}',
                      subtitle: switch ((rider.isLeader, rider.userId == me)) {
                        (true, true) => 'Leader · You',
                        (true, false) => 'Leader',
                        (false, true) => 'You',
                        (false, false) => 'Joined',
                      },
                    ),
                ],
              ),
              if (notJoined.isNotEmpty) ...[
                const SectionLabel('Not joined yet'),
                BrodieListGroup(
                  children: [
                    for (final member in notJoined)
                      BrodieListTile(
                        leading: BrodieAvatar(name: member.username ?? '?'),
                        title: '@${member.username ?? 'rider'}',
                        subtitle: member.userId == me ? 'You' : null,
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _LobbyActions extends StatelessWidget {
  const _LobbyActions({
    required this.lobby,
    required this.isLeader,
    required this.joined,
    required this.busy,
    required this.onStart,
    required this.onCancel,
    required this.onJoin,
    required this.onLeave,
  });

  final GroupLobby lobby;
  final bool isLeader;
  final bool joined;
  final bool busy;
  final VoidCallback onStart;
  final VoidCallback onCancel;
  final VoidCallback onJoin;
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) {
    final planned = lobby.trip.status == TripStatus.planned;
    final buttons = <Widget>[
      if (isLeader) ...[
        BrodieButton.secondary(label: 'Cancel ride', onPressed: busy ? null : onCancel),
        if (planned) BrodieButton(label: 'Start ride', icon: Icons.flag_outlined, isLoading: busy, onPressed: onStart),
      ] else if (joined)
        BrodieButton.secondary(label: 'Leave ride', isLoading: busy, onPressed: onLeave)
      else
        BrodieButton(label: 'Join ride', icon: Icons.group_add_outlined, isLoading: busy, onPressed: onJoin),
    ];

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(BrodieSpace.md),
        child: Row(
          children: [
            for (final (index, button) in buttons.indexed) ...[
              if (index > 0) const SizedBox(width: BrodieSpace.sm),
              Expanded(child: button),
            ],
          ],
        ),
      ),
    );
  }
}
