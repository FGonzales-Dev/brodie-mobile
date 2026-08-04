import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../data/repositories/settings_repository.dart';
import 'application/settings_controller.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  PermissionStatus? _locationStatus;

  @override
  void initState() {
    super.initState();
    _loadLocationStatus();
  }

  Future<void> _loadLocationStatus() async {
    final status = await Permission.locationAlways.status;
    if (mounted) setState(() => _locationStatus = status);
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeControllerProvider);
    final units = ref.watch(unitsControllerProvider);
    final notificationsEnabled = ref.watch(notificationsEnabledControllerProvider);
    final broadcastInterval = ref.watch(broadcastIntervalControllerProvider);
    final batterySaver = ref.watch(batterySaverControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const _SectionHeader('Theme'),
          RadioGroup<ThemeMode>(
            groupValue: themeMode,
            onChanged: (value) {
              if (value != null) ref.read(themeModeControllerProvider.notifier).setThemeMode(value);
            },
            child: const Column(
              children: [
                RadioListTile<ThemeMode>(title: Text('System'), value: ThemeMode.system),
                RadioListTile<ThemeMode>(title: Text('Light'), value: ThemeMode.light),
                RadioListTile<ThemeMode>(title: Text('Dark'), value: ThemeMode.dark),
              ],
            ),
          ),
          const Divider(),
          const _SectionHeader('Units'),
          RadioGroup<DistanceUnit>(
            groupValue: units,
            onChanged: (value) {
              if (value != null) ref.read(unitsControllerProvider.notifier).setUnits(value);
            },
            child: const Column(
              children: [
                RadioListTile<DistanceUnit>(title: Text('Kilometers'), value: DistanceUnit.km),
                RadioListTile<DistanceUnit>(title: Text('Miles'), value: DistanceUnit.mi),
              ],
            ),
          ),
          const Divider(),
          const _SectionHeader('Notifications'),
          SwitchListTile(
            title: const Text('Push notifications'),
            subtitle: const Text('Ride invites, regroup alerts, SOS'),
            value: notificationsEnabled,
            onChanged: (value) => ref.read(notificationsEnabledControllerProvider.notifier).setEnabled(value),
          ),
          const Divider(),
          const _SectionHeader('Location'),
          ListTile(
            title: const Text('Background location'),
            subtitle: Text(_describeStatus(_locationStatus)),
            trailing: TextButton(
              onPressed: () async {
                await openAppSettings();
                _loadLocationStatus();
              },
              child: const Text('Open Settings'),
            ),
          ),
          const Divider(),
          const _SectionHeader('Advanced'),
          ListTile(
            title: const Text('Broadcast interval'),
            subtitle: Text('$broadcastInterval seconds while in an active group ride'),
          ),
          Slider(
            value: broadcastInterval.toDouble(),
            min: 3,
            max: 30,
            divisions: 27,
            label: '$broadcastInterval s',
            onChanged: (value) =>
                ref.read(broadcastIntervalControllerProvider.notifier).setInterval(value.round()),
          ),
          SwitchListTile(
            title: const Text('Battery saver'),
            subtitle: const Text('Reduce location update frequency to save battery'),
            value: batterySaver,
            onChanged: (value) => ref.read(batterySaverControllerProvider.notifier).setEnabled(value),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  String _describeStatus(PermissionStatus? status) {
    switch (status) {
      case null:
        return 'Checking…';
      case PermissionStatus.granted:
        return 'Always allowed';
      case PermissionStatus.limited:
        return 'While using the app';
      case PermissionStatus.denied:
        return 'Not granted';
      case PermissionStatus.permanentlyDenied:
        return 'Denied — enable in OS settings';
      case PermissionStatus.restricted:
        return 'Restricted';
      case PermissionStatus.provisional:
        return 'Provisional';
    }
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
      ),
    );
  }
}
