import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design_system/design_system.dart';
import '../../../../core/utils/units.dart';
import '../../../settings/application/settings_controller.dart';
import '../../../vehicles/domain/vehicle.dart';
import '../../application/ride_providers.dart';
import '../../domain/ride_filter.dart';

/// "12 rides · 340 km · 14 h riding" for what the filters match, plus a way
/// to clear them.
class HistoryTotalsLine extends ConsumerWidget {
  const HistoryTotalsLine({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final units = ref.watch(settingsControllerProvider.select((settings) => settings.units));
    final filter = ref.watch(rideFilterControllerProvider);
    final totals = ref.watch(rideHistoryTotalsProvider).value;
    final text = switch (totals) {
      null => ' ',
      (count: 0, distanceMeters: _, movingTime: _) => filter.activeCount > 0 ? 'No matching rides' : ' ',
      (:final count, :final distanceMeters, :final movingTime) => [
        '$count ${count == 1 ? 'ride' : 'rides'}',
        formatDistance(distanceMeters, units).text,
        '${formatDuration(movingTime).text} riding',
      ].join(' · '),
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(BrodieSpace.md, 0, BrodieSpace.xs, BrodieSpace.xs),
      child: Row(
        children: [
          Expanded(
            child: Text(text, style: BrodieType.caption.copyWith(color: colors.textSecondary)),
          ),
          if (!filter.isDefault)
            TextButton(onPressed: ref.read(rideFilterControllerProvider.notifier).clear, child: const Text('Clear')),
        ],
      ),
    );
  }
}

/// Period, vehicle and sort. Changes apply as soon as they're tapped.
class HistoryFilterSheet extends ConsumerWidget {
  const HistoryFilterSheet({super.key, required this.vehicles});

  final List<Vehicle> vehicles;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final filter = ref.watch(rideFilterControllerProvider);
    final controller = ref.read(rideFilterControllerProvider.notifier);

    Widget chip(String label, bool selected, VoidCallback onTap) => ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      showCheckmark: false,
      selectedColor: colors.accent,
      labelStyle: BrodieType.bodyStrong.copyWith(color: selected ? colors.onAccent : colors.textPrimary),
      side: BorderSide(color: selected ? colors.accent : colors.border),
      shape: const RoundedRectangleBorder(borderRadius: BrodieSize.borderRadius),
    );

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(BrodieSpace.md, 0, BrodieSpace.md, BrodieSpace.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('FILTER & SORT', style: BrodieType.headline.copyWith(color: colors.textPrimary)),
            const SectionLabel('When'),
            Wrap(
              spacing: BrodieSpace.xs,
              runSpacing: BrodieSpace.xs,
              children: [
                for (final period in RidePeriod.values)
                  chip(
                    period.label,
                    filter.period == period,
                    () => controller.update((f) => f.copyWith(period: period)),
                  ),
              ],
            ),
            if (vehicles.isNotEmpty) ...[
              const SectionLabel('Vehicle'),
              Wrap(
                spacing: BrodieSpace.xs,
                runSpacing: BrodieSpace.xs,
                children: [
                  chip('Any', filter.vehicleId == null, () => controller.update((f) => f.copyWith(vehicleId: null))),
                  for (final vehicle in vehicles)
                    chip(
                      vehicle.name,
                      filter.vehicleId == vehicle.id,
                      () => controller.update((f) => f.copyWith(vehicleId: vehicle.id)),
                    ),
                ],
              ),
            ],
            const SectionLabel('Sort by'),
            RadioGroup<RideSort>(
              groupValue: filter.sort,
              onChanged: (sort) {
                if (sort != null) controller.update((f) => f.copyWith(sort: sort));
              },
              child: Column(
                children: [
                  for (final sort in RideSort.values)
                    RadioListTile<RideSort>(value: sort, title: Text(sort.label), contentPadding: EdgeInsets.zero),
                ],
              ),
            ),
            const SizedBox(height: BrodieSpace.sm),
            BrodieButton(label: 'Done', icon: Icons.check, onPressed: () => Navigator.pop(context)),
            if (!filter.isDefault) TextButton(onPressed: controller.clear, child: const Text('Clear all')),
          ],
        ),
      ),
    );
  }
}
