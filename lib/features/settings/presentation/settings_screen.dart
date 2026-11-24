import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design_system/design_system.dart';
import '../../../core/presentation/refresh_on_resume.dart';
import '../../../core/utils/units.dart';
import '../../map/application/location_access_controller.dart';
import '../../map/domain/map_models.dart';
import '../application/settings_controller.dart';
import '../domain/app_settings.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsControllerProvider);
    final controller = ref.read(settingsControllerProvider.notifier);
    final locationAccess = ref.watch(locationAccessControllerProvider).value;

    return Scaffold(
      appBar: const BrodieAppBar(title: 'Settings'),
      body: RefreshOnResume(
        onResume: () => ref.read(locationAccessControllerProvider.notifier).refresh(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(BrodieSpace.md, 0, BrodieSpace.md, BrodieSpace.xl),
          children: [
            const SectionLabel('Theme'),
            BrodieSegmentedControl<ThemePreference>(
              options: const [
                (ThemePreference.system, 'System'),
                (ThemePreference.light, 'Light'),
                (ThemePreference.dark, 'Dark'),
              ],
              selected: settings.theme,
              onChanged: (theme) => controller.update((s) => s.copyWith(theme: theme)),
            ),
            const SectionLabel('Units'),
            BrodieSegmentedControl<DistanceUnit>(
              options: const [(DistanceUnit.km, 'Kilometers'), (DistanceUnit.mi, 'Miles')],
              selected: settings.units,
              onChanged: (units) => controller.update((s) => s.copyWith(units: units)),
            ),
            const SectionLabel('Notifications'),
            BrodieListGroup(
              children: [
                BrodieListTile(
                  title: 'Push notifications',
                  subtitle: 'Ride invites, regroup alerts, SOS',
                  trailing: Switch(
                    value: settings.notificationsEnabled,
                    onChanged: (enabled) => controller.update((s) => s.copyWith(notificationsEnabled: enabled)),
                  ),
                ),
              ],
            ),
            const SectionLabel('Location'),
            BrodieListGroup(
              children: [
                BrodieListTile(
                  title: 'Location access',
                  subtitle: _describe(locationAccess),
                  trailing: TextButton(
                    onPressed: () => ref.read(locationAccessControllerProvider.notifier).openSystemSettings(),
                    child: const Text('Open settings'),
                  ),
                ),
              ],
            ),
            const SectionLabel('Group rides'),
            BrodieListGroup(
              children: [
                BrodieListTile(
                  title: 'Broadcast interval',
                  subtitle: 'Share your position every ${settings.broadcastIntervalSeconds} s during a group ride',
                ),
                Slider(
                  value: settings.broadcastIntervalSeconds.toDouble(),
                  min: 3,
                  max: 30,
                  divisions: 27,
                  label: '${settings.broadcastIntervalSeconds} s',
                  onChanged: (value) => controller.update((s) => s.copyWith(broadcastIntervalSeconds: value.round())),
                ),
                BrodieListTile(
                  title: 'Battery saver',
                  subtitle: 'Fewer location updates, longer battery',
                  trailing: Switch(
                    value: settings.batterySaver,
                    onChanged: (enabled) => controller.update((s) => s.copyWith(batterySaver: enabled)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _describe(LocationAccess? access) => switch (access) {
    null => 'Checking…',
    LocationAccess.always => 'Always allowed',
    LocationAccess.whileInUse => 'While using the app',
    LocationAccess.denied => 'Not allowed yet',
    LocationAccess.deniedForever => 'Blocked. Allow it in system settings',
    LocationAccess.serviceDisabled => 'Location services are off',
  };
}
