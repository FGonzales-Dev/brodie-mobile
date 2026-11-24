import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/router/routes.dart';
import '../../../core/design_system/design_system.dart';
import '../../../core/presentation/feedback.dart';
import '../../../core/presentation/keep_screen_on.dart';
import '../../../core/presentation/time_labels.dart';
import '../../emergency_contacts/application/emergency_contact_providers.dart';
import '../../emergency_contacts/domain/emergency_contact.dart';
import '../../group_ride/application/group_ride_controller.dart';
import '../../map/data/location_repository.dart';
import '../../map/domain/map_models.dart';
import '../../profile/application/my_profile_provider.dart';
import '../domain/sos_message.dart';

/// Opened from the SOS button on a ride screen. Counts down so an accidental
/// tap can be cancelled, then alerts the group (in a group ride) and opens
/// a text to the rider's emergency contacts with their location.
class SosScreen extends ConsumerStatefulWidget {
  const SosScreen({super.key, this.groupId, this.lastFix});

  /// Set during a group ride, whose riders get the alert straight away.
  final String? groupId;

  /// The ride's latest position, used until a fresh fix arrives.
  final GeoFix? lastFix;

  @override
  ConsumerState<SosScreen> createState() => _SosScreenState();
}

enum _Phase { counting, sending, sent }

class _SosScreenState extends ConsumerState<SosScreen> {
  static const _countdownSeconds = 5;

  var _phase = _Phase.counting;
  var _remaining = _countdownSeconds;
  Timer? _timer;
  GeoFix? _fix;

  /// Null when there is no group ride; false when the alert didn't go out.
  bool? _groupAlerted;
  List<EmergencyContact> _contacts = const [];
  var _contactsFailed = false;
  bool? _textOpened;
  var _cancellingGroupSos = false;

  @override
  void initState() {
    super.initState();
    _fix = widget.lastFix;
    unawaited(_freshFix());
    HapticFeedback.heavyImpact();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_remaining <= 1) {
        _send();
      } else {
        HapticFeedback.heavyImpact();
        setState(() => _remaining--);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _freshFix() async {
    try {
      final fix = await ref.read(locationRepositoryProvider).currentFix();
      if (mounted) _fix = fix;
    } catch (_) {
      // Keep the ride's last position.
    }
  }

  GroupRideController? get _groupRide {
    final groupId = widget.groupId;
    if (groupId == null || ref.read(groupRideControllerProvider(groupId)).value == null) return null;
    return ref.read(groupRideControllerProvider(groupId).notifier);
  }

  Future<void> _send() async {
    if (_phase != _Phase.counting) return;
    _timer?.cancel();
    HapticFeedback.vibrate();
    setState(() => _phase = _Phase.sending);

    // The group first: it's the only part that goes out without the rider
    // tapping anything else.
    final group = _groupRide;
    bool? groupAlerted;
    if (group != null) {
      try {
        await group.sendSos();
        groupAlerted = true;
      } catch (_) {
        groupAlerted = false;
      }
    }

    var contacts = const <EmergencyContact>[];
    var contactsFailed = false;
    try {
      contacts = await ref.read(emergencyContactsControllerProvider.future);
    } catch (_) {
      contactsFailed = true;
    }
    if (!mounted) return;
    setState(() {
      _groupAlerted = groupAlerted;
      _contacts = contacts;
      _contactsFailed = contactsFailed;
      _phase = _Phase.sent;
    });
    if (contacts.isNotEmpty) await _openText();
  }

  Future<void> _openText() async {
    final time = _fix == null ? '' : clockLabel(context, _fix!.timestamp);
    final body = SosMessage.text(username: ref.read(myProfileProvider).value?.username, fix: _fix, time: time);
    final uri = SosMessage.smsUri(
      [for (final contact in _contacts) contact.phone],
      body,
      platform: defaultTargetPlatform,
    );
    var opened = false;
    try {
      opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
    if (mounted) setState(() => _textOpened = opened);
  }

  Future<void> _call(EmergencyContact contact) async {
    var opened = false;
    try {
      opened = await launchUrl(SosMessage.callUri(contact.phone), mode: LaunchMode.externalApplication);
    } catch (_) {}
    if (!opened && mounted) context.showMessage("Couldn't open the phone app. Call ${contact.phone}.");
  }

  Future<void> _imSafe() async {
    final group = _groupRide;
    if (group == null) return;
    setState(() => _cancellingGroupSos = true);
    final ok = await context.runWithFeedback(group.cancelSos, successMessage: 'Your group knows you are safe');
    if (!mounted) return;
    setState(() => _cancellingGroupSos = false);
    if (ok) context.pop();
  }

  Future<void> _retryGroup() async {
    final group = _groupRide;
    if (group == null) return;
    try {
      await group.sendSos();
      if (mounted) setState(() => _groupAlerted = true);
    } catch (_) {
      if (mounted) context.showMessage("Still couldn't reach your group. Try calling someone.");
    }
  }

  @override
  Widget build(BuildContext context) {
    // Loads the contacts during the countdown, and keeps them loaded.
    ref.watch(emergencyContactsControllerProvider);
    return KeepScreenOn(
      child: PopScope(
        // Leaving mid-countdown cancels it; nothing has been sent yet.
        canPop: _phase != _Phase.sending,
        child: switch (_phase) {
          _Phase.counting || _Phase.sending => _Countdown(
            remaining: _remaining,
            sending: _phase == _Phase.sending,
            inGroupRide: widget.groupId != null,
            onCancel: () => context.pop(),
            onSendNow: _send,
          ),
          _Phase.sent => _Sent(
            groupAlerted: _groupAlerted,
            contacts: _contacts,
            contactsFailed: _contactsFailed,
            textOpened: _textOpened,
            hasLocation: _fix != null,
            cancellingGroupSos: _cancellingGroupSos,
            onRetryGroup: _retryGroup,
            onOpenText: _openText,
            onCall: _call,
            onAddContacts: () => context.push(Routes.emergencyContacts),
            onImSafe: _groupAlerted == true ? _imSafe : null,
            onDone: () => context.pop(),
          ),
        },
      ),
    );
  }
}

class _Countdown extends StatelessWidget {
  const _Countdown({
    required this.remaining,
    required this.sending,
    required this.inGroupRide,
    required this.onCancel,
    required this.onSendNow,
  });

  final int remaining;
  final bool sending;
  final bool inGroupRide;
  final VoidCallback onCancel;
  final VoidCallback onSendNow;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    const onDanger = Color(0xFFFFFFFF);
    return Scaffold(
      backgroundColor: colors.danger,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(BrodieSpace.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Text(
                'SOS',
                textAlign: TextAlign.center,
                style: BrodieType.stat.copyWith(color: onDanger, fontSize: 56),
              ),
              const SizedBox(height: BrodieSpace.md),
              Text(
                sending ? 'Sending…' : '$remaining',
                textAlign: TextAlign.center,
                style: BrodieType.stat.copyWith(color: onDanger, fontSize: sending ? 40 : 120),
              ),
              const SizedBox(height: BrodieSpace.md),
              Text(
                inGroupRide
                    ? 'Your group sees your SOS and location. Then a text to your emergency contacts opens, ready to send.'
                    : 'A text to your emergency contacts opens with your location, ready to send.',
                textAlign: TextAlign.center,
                style: BrodieType.bodyStrong.copyWith(color: onDanger, fontSize: 16),
              ),
              const Spacer(),
              SizedBox(
                height: 72,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: onDanger,
                    foregroundColor: colors.danger,
                    shape: const RoundedRectangleBorder(borderRadius: BrodieSize.borderRadius),
                  ),
                  onPressed: sending ? null : onCancel,
                  child: Text('CANCEL', style: BrodieType.button.copyWith(color: colors.danger, fontSize: 22)),
                ),
              ),
              const SizedBox(height: BrodieSpace.sm),
              TextButton(
                onPressed: sending ? null : onSendNow,
                child: Text('Send now', style: BrodieType.bodyStrong.copyWith(color: onDanger, fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Sent extends StatelessWidget {
  const _Sent({
    required this.groupAlerted,
    required this.contacts,
    required this.contactsFailed,
    required this.textOpened,
    required this.hasLocation,
    required this.cancellingGroupSos,
    required this.onRetryGroup,
    required this.onOpenText,
    required this.onCall,
    required this.onAddContacts,
    required this.onImSafe,
    required this.onDone,
  });

  final bool? groupAlerted;
  final List<EmergencyContact> contacts;
  final bool contactsFailed;
  final bool? textOpened;
  final bool hasLocation;
  final bool cancellingGroupSos;
  final VoidCallback onRetryGroup;
  final VoidCallback onOpenText;
  final ValueChanged<EmergencyContact> onCall;
  final VoidCallback onAddContacts;
  final VoidCallback? onImSafe;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      appBar: const BrodieAppBar(title: 'SOS'),
      body: ListView(
        padding: const EdgeInsets.all(BrodieSpace.md),
        children: [
          if (groupAlerted case final alerted?)
            _Step(
              done: alerted,
              title: alerted ? 'Your group was alerted' : "Couldn't reach your group",
              detail: alerted
                  ? 'They see your SOS and where you are until you tap "I\'m safe".'
                  : 'No connection right now.',
              action: alerted
                  ? null
                  : BrodieButton.secondary(label: 'Try again', compact: true, onPressed: onRetryGroup),
            ),
          if (contactsFailed)
            const _Step(
              done: false,
              title: "Couldn't load your emergency contacts",
              detail: 'No connection right now. Call someone directly if you can.',
            )
          else if (contacts.isEmpty)
            _Step(
              done: false,
              title: 'No emergency contacts yet',
              detail: 'Add someone Brodie can text when you send an SOS.',
              action: BrodieButton.secondary(label: 'Add contacts', compact: true, onPressed: onAddContacts),
            )
          else
            _Step(
              done: textOpened ?? false,
              title: textOpened == false ? "Couldn't open your messages app" : 'Tap Send in your messages app',
              detail: [
                'The text to ${contacts.length == 1 ? contacts.single.name : '${contacts.length} contacts'} is ready'
                    "${hasLocation ? ' with your location' : ", but your location wasn't available"}.",
                "Brodie can't send it for you.",
              ].join(' '),
              action: BrodieButton.secondary(label: 'Open text again', compact: true, onPressed: onOpenText),
            ),
          if (contacts.isNotEmpty) ...[
            const SectionLabel('Call'),
            BrodieListGroup(
              children: [
                for (final contact in contacts)
                  BrodieListTile(
                    leading: BrodieAvatar(name: contact.name),
                    title: contact.name,
                    subtitle: [contact.phone, ?contact.relationship].join(' · '),
                    trailing: IconButton(
                      tooltip: 'Call ${contact.name}',
                      icon: Icon(Icons.call, color: colors.success),
                      onPressed: () => onCall(contact),
                    ),
                    onTap: () => onCall(contact),
                  ),
              ],
            ),
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(BrodieSpace.md),
          child: onImSafe == null
              ? BrodieButton(label: 'Done', icon: Icons.check, onPressed: onDone)
              : BrodieButton(
                  label: "I'm safe",
                  icon: Icons.check_circle_outline,
                  isLoading: cancellingGroupSos,
                  onPressed: onImSafe,
                ),
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.done, required this.title, required this.detail, this.action});

  final bool done;
  final String title;
  final String detail;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: BrodieSpace.sm),
      child: BrodieCard(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              done ? Icons.check_circle : Icons.error_outline,
              color: done ? colors.success : colors.warning,
              size: 28,
            ),
            const SizedBox(width: BrodieSpace.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: BrodieType.bodyStrong.copyWith(color: colors.textPrimary)),
                  const SizedBox(height: BrodieSpace.xxs),
                  Text(detail, style: BrodieType.body.copyWith(color: colors.textSecondary)),
                  if (action != null) ...[const SizedBox(height: BrodieSpace.sm), action!],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
