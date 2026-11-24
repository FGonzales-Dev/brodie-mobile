import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design_system/design_system.dart';
import '../../../core/presentation/feedback.dart';
import '../../../core/presentation/refresh_on_resume.dart';
import '../../../core/utils/validators.dart';
import '../../auth/presentation/widgets/road_art.dart';
import '../../emergency_contacts/application/emergency_contact_providers.dart';
import '../../map/application/location_access_controller.dart';
import '../../map/domain/map_models.dart';
import '../../vehicles/application/vehicle_providers.dart';
import '../../vehicles/domain/vehicle.dart';
import '../data/onboarding_store.dart';

/// First run, after the username: what Brodie does, why it needs location
/// (before the system prompt), and optional quick setup of a vehicle and an
/// emergency contact. Every setup step can be skipped; finishing or skipping
/// hands back to the router.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

enum _Step { together, live, safety, location, vehicle, contact }

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  static const _introSteps = {_Step.together, _Step.live, _Step.safety};

  final _pages = PageController();
  var _step = _Step.together;
  var _finishing = false;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _goTo(_Step step) {
    setState(() => _step = step);
    _pages.animateToPage(step.index, duration: const Duration(milliseconds: 280), curve: Curves.easeOutCubic);
  }

  void _next() => _step == _Step.values.last ? _finish() : _goTo(_Step.values[_step.index + 1]);

  void _back() {
    if (_step.index > 0) _goTo(_Step.values[_step.index - 1]);
  }

  Future<void> _finish() async {
    if (_finishing) return;
    setState(() => _finishing = true);
    // The router moves on as soon as this is recorded.
    await ref.read(onboardingDoneProvider.notifier).complete();
  }

  @override
  Widget build(BuildContext context) {
    final intro = _introSteps.contains(_step);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        body: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _pages,
                // Buttons drive it, so a half-filled form can't be swiped away.
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  const _IntroPage(
                    icon: Icons.groups,
                    title: 'Ride as a crew.',
                    body:
                        "Your group's leader plans the ride and the route. "
                        'Everyone joins from the group and follows the same line on the map.',
                  ),
                  const _IntroPage(
                    icon: Icons.sports_motorsports,
                    title: 'See your crew live.',
                    body:
                        "During a group ride, everyone on it sees where the others are. "
                        'Brodie tells you when someone falls behind, so nobody gets left at a junction.',
                  ),
                  const _IntroPage(
                    icon: Icons.sos,
                    title: 'Help is one tap away.',
                    body:
                        'The SOS button alerts your group with your location and opens a text '
                        'to your emergency contacts, ready to send.',
                  ),
                  _LocationStep(onDone: _next),
                  _VehicleStep(onDone: _next),
                  _ContactStep(onDone: _next, finishing: _finishing),
                ],
              ),
            ),
            if (intro)
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(BrodieSpace.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _Dots(count: _introSteps.length, current: _step.index),
                      const SizedBox(height: BrodieSpace.md),
                      BrodieButton(
                        label: _step == _Step.safety ? 'Get started' : 'Next',
                        icon: Icons.arrow_forward,
                        onPressed: _next,
                      ),
                      TextButton(onPressed: () => _goTo(_Step.location), child: const Text('Skip intro')),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _IntroPage extends StatelessWidget {
  const _IntroPage({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 260,
            child: Stack(
              children: [
                const Positioned.fill(child: RoadArt()),
                Center(
                  child: Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(color: colors.accent, borderRadius: BrodieSize.borderRadius),
                    child: Icon(icon, size: 52, color: colors.onAccent),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: BrodieSpace.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  title.toUpperCase(),
                  style: BrodieType.screenTitle.copyWith(fontSize: 44, color: colors.textPrimary),
                ),
                const SizedBox(height: BrodieSpace.sm),
                Text(body, style: BrodieType.body.copyWith(color: colors.textSecondary, fontSize: 16)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.current});

  final int count;
  final int current;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      label: 'Step ${current + 1} of $count',
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < count; i++)
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: i == current ? 24 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: i == current ? colors.accent : colors.border,
                borderRadius: BrodieSize.borderRadius,
              ),
            ),
        ],
      ),
    );
  }
}

/// Shared layout for the setup steps: heading, body, then the step's own
/// content and buttons pinned to the bottom.
class _SetupPage extends StatelessWidget {
  const _SetupPage({required this.icon, required this.title, required this.body, this.content, required this.actions});

  final IconData icon;
  final String title;
  final String body;
  final Widget? content;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(BrodieSpace.lg, BrodieSpace.xl, BrodieSpace.lg, BrodieSpace.md),
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconTile(icon: icon),
                ),
                const SizedBox(height: BrodieSpace.md),
                Text(
                  title.toUpperCase(),
                  style: BrodieType.screenTitle.copyWith(fontSize: 40, color: colors.textPrimary),
                ),
                const SizedBox(height: BrodieSpace.sm),
                Text(body, style: BrodieType.body.copyWith(color: colors.textSecondary, fontSize: 16)),
                if (content != null) ...[const SizedBox(height: BrodieSpace.lg), content!],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(BrodieSpace.md),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: actions),
          ),
        ],
      ),
    );
  }
}

/// Why Brodie needs location, shown before the system prompt so the rider
/// knows what they're agreeing to.
class _LocationStep extends ConsumerWidget {
  const _LocationStep({required this.onDone});

  final VoidCallback onDone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(locationAccessControllerProvider.notifier);
    final access = ref.watch(locationAccessControllerProvider);
    final asking = access.isLoading;

    final List<Widget> actions = switch (access.value) {
      final LocationAccess granted when granted.isGranted => [
        BrodieButton(label: 'Continue', icon: Icons.arrow_forward, onPressed: onDone),
      ],
      LocationAccess.deniedForever || LocationAccess.serviceDisabled => [
        BrodieButton(label: 'Open settings', icon: Icons.settings, onPressed: controller.openSystemSettings),
        TextButton(onPressed: onDone, child: const Text('Not now')),
      ],
      _ => [
        BrodieButton(
          label: 'Allow location',
          icon: Icons.my_location,
          isLoading: asking,
          onPressed: () async {
            await controller.request();
            onDone();
          },
        ),
        TextButton(onPressed: asking ? null : onDone, child: const Text('Not now')),
      ],
    };

    return RefreshOnResume(
      onResume: controller.refresh,
      child: _SetupPage(
        icon: Icons.location_on_outlined,
        title: 'Your location',
        body:
            'Brodie uses your location while you use the app, to show where you are and route you. '
            "During a group ride, it's shared with the riders on that ride until it ends, also with the "
            "screen locked, and it isn't stored. Your own rides are saved to your history.",
        content: switch (access.value) {
          final LocationAccess granted when granted.isGranted => const _Done(
            text: 'Location is on. You can change this in Settings any time.',
          ),
          LocationAccess.deniedForever => const _Note(
            text: 'Location is blocked for Brodie. Allow it in system settings.',
          ),
          LocationAccess.serviceDisabled => const _Note(
            text: "Your phone's location is off. Turn it on in system settings.",
          ),
          _ => null,
        },
        actions: actions,
      ),
    );
  }
}

class _VehicleStep extends ConsumerStatefulWidget {
  const _VehicleStep({required this.onDone});

  final VoidCallback onDone;

  @override
  ConsumerState<_VehicleStep> createState() => _VehicleStepState();
}

class _VehicleStepState extends ConsumerState<_VehicleStep> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  var _type = VehicleType.motorcycle;
  var _saving = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    final saved = await context.runWithFeedback(
      () => ref.read(vehiclesControllerProvider.notifier).add((type: _type, name: _name.text.trim())),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (saved) widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final existing = ref.watch(vehiclesControllerProvider).value ?? const [];
    if (existing.isNotEmpty) {
      return _SetupPage(
        icon: Icons.two_wheeler,
        title: 'Your ride',
        body: 'Your rides are tagged with what you rode, and your crew can see it.',
        content: _Done(
          text: existing.length == 1
              ? '${existing.single.name} is in your garage.'
              : '${existing.length} vehicles in your garage.',
        ),
        actions: [BrodieButton(label: 'Continue', icon: Icons.arrow_forward, onPressed: widget.onDone)],
      );
    }
    return _SetupPage(
      icon: Icons.two_wheeler,
      title: 'What do you ride?',
      body: 'Your rides are tagged with it, and your crew knows what to look for. You can add more later in Profile.',
      content: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            BrodieSegmentedControl<VehicleType>(
              options: [for (final type in VehicleType.values) (type, type.label)],
              selected: _type,
              onChanged: (type) => setState(() => _type = type),
            ),
            const SizedBox(height: BrodieSpace.md),
            BrodieTextField(
              controller: _name,
              label: 'Name',
              hint: _type == VehicleType.motorcycle ? 'e.g. Honda ADV 160' : 'e.g. Trek Domane',
              textInputAction: TextInputAction.done,
              validator: Validators.required('Enter a name, or skip this step'),
              onSubmitted: (_) => _save(),
            ),
          ],
        ),
      ),
      actions: [
        BrodieButton(label: 'Save', icon: Icons.check, isLoading: _saving, onPressed: _save),
        TextButton(onPressed: _saving ? null : widget.onDone, child: const Text('Skip for now')),
      ],
    );
  }
}

class _ContactStep extends ConsumerStatefulWidget {
  const _ContactStep({required this.onDone, required this.finishing});

  final VoidCallback onDone;
  final bool finishing;

  @override
  ConsumerState<_ContactStep> createState() => _ContactStepState();
}

class _ContactStepState extends ConsumerState<_ContactStep> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  var _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    final saved = await context.runWithFeedback(
      () => ref.read(emergencyContactsControllerProvider.notifier).add((
        name: _name.text.trim(),
        phone: _phone.text.trim(),
        relationship: null,
      )),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (saved) widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final existing = ref.watch(emergencyContactsControllerProvider).value ?? const [];
    final busy = _saving || widget.finishing;
    if (existing.isNotEmpty) {
      return _SetupPage(
        icon: Icons.health_and_safety_outlined,
        title: 'Emergency contact',
        body: 'If you send an SOS, Brodie opens a text to them with your location.',
        content: _Done(
          text: existing.length == 1
              ? '${existing.single.name} is your emergency contact.'
              : '${existing.length} emergency contacts saved.',
        ),
        actions: [
          BrodieButton(label: 'Finish', icon: Icons.check, isLoading: widget.finishing, onPressed: widget.onDone),
        ],
      );
    }
    return _SetupPage(
      icon: Icons.health_and_safety_outlined,
      title: 'Who should we text?',
      body:
          'If you send an SOS, Brodie opens a text to your emergency contact with your location. '
          'Add more in Profile.',
      content: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            BrodieTextField(
              controller: _name,
              label: 'Name',
              icon: Icons.person_outline,
              textInputAction: TextInputAction.next,
              validator: Validators.required('Enter a name, or skip this step'),
            ),
            const SizedBox(height: BrodieSpace.md),
            BrodieTextField(
              controller: _phone,
              label: 'Phone',
              icon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.done,
              validator: Validators.required('Enter a phone number, or skip this step'),
              onSubmitted: (_) => _save(),
            ),
          ],
        ),
      ),
      actions: [
        BrodieButton(label: 'Save and finish', icon: Icons.check, isLoading: busy, onPressed: _save),
        TextButton(onPressed: busy ? null : widget.onDone, child: const Text('Skip and finish')),
      ],
    );
  }
}

class _Done extends StatelessWidget {
  const _Done({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) =>
      BrodieAlert(icon: Icons.check_circle, color: context.colors.success, message: text, margin: EdgeInsets.zero);
}

class _Note extends StatelessWidget {
  const _Note({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) =>
      BrodieAlert(icon: Icons.info_outline, color: context.colors.warning, message: text, margin: EdgeInsets.zero);
}
