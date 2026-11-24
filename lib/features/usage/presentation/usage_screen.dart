import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design_system/design_system.dart';
import '../../../core/presentation/time_labels.dart';
import '../data/usage_repository.dart';
import '../domain/api_usage.dart';

/// Today's allowance for the services with a daily cap (route previews,
/// place searches): what's left for this rider and for everyone.
class UsageScreen extends ConsumerWidget {
  const UsageScreen({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    ref
      ..invalidate(myApiUsageProvider)
      ..invalidate(apiUsageByPurposeProvider);
    await ref.read(myApiUsageProvider.future);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: const BrodieAppBar(title: 'Usage & limits'),
      body: AsyncValueView(
        value: ref.watch(myApiUsageProvider),
        onRetry: () => ref.invalidate(myApiUsageProvider),
        data: (usages) => RefreshIndicator(
          onRefresh: () => _refresh(ref),
          child: ListView(
            padding: const EdgeInsets.all(BrodieSpace.md),
            children: [
              for (final usage in usages) ...[_UsageCard(usage: usage), const SizedBox(height: BrodieSpace.sm)],
              const _UsageByPurposeCard(),
              const _MapDisplayNote(),
            ],
          ),
        ),
      ),
    );
  }
}

class _UsageCard extends StatelessWidget {
  const _UsageCard({required this.usage});

  final ApiUsage usage;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final available = usage.availableNow;
    final fraction = usage.dailyLimit == 0 ? 0.0 : usage.remaining / usage.dailyLimit;
    final gaugeColor = available == 0
        ? colors.danger
        : fraction <= .2
        ? colors.warning
        : colors.primaryAction;
    final resetsAt = clockLabel(context, usage.resetsAt);

    return BrodieCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(usage.label.toUpperCase(), style: BrodieType.title.copyWith(color: colors.textPrimary)),
          const SizedBox(height: BrodieSpace.xs),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text('${usage.remaining}', style: BrodieType.stat.copyWith(color: colors.textPrimary, fontSize: 44)),
              const SizedBox(width: BrodieSpace.xs),
              Text(
                'OF ${usage.dailyLimit} LEFT FOR YOU TODAY',
                style: BrodieType.overline.copyWith(color: colors.textSecondary, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: BrodieSpace.xs),
          ClipRRect(
            borderRadius: BrodieSize.borderRadius,
            child: LinearProgressIndicator(
              value: fraction.clamp(0, 1),
              minHeight: 10,
              color: gaugeColor,
              backgroundColor: colors.surfaceRaised,
            ),
          ),
          const SizedBox(height: BrodieSpace.sm),
          Text(
            'All riders: ${usage.allRidersRemaining} of ${usage.allRidersDailyLimit} left today',
            style: BrodieType.body.copyWith(color: colors.textPrimary),
          ),
          if (available == 0 && usage.remaining > 0)
            Text(
              "The shared daily limit is used up, so this is paused for everyone until it resets.",
              style: BrodieType.caption.copyWith(color: colors.warning),
            ),
          Text('Resets at $resetsAt', style: BrodieType.caption.copyWith(color: colors.textSecondary)),
        ],
      ),
    );
  }
}

/// What the last week's route requests and searches were for, across all
/// riders: where usage could be cut. Hidden until there's something to show.
class _UsageByPurposeCard extends ConsumerWidget {
  const _UsageByPurposeCard();

  static const _services = {'mapbox_directions': 'Route requests', 'mapbox_search': 'Place searches'};

  static String _purposeLabel(String purpose) => switch (purpose) {
    'ride_preview' => 'Solo route previews',
    'reroute' => 'Reroutes during rides',
    'group_plan' => 'Group rides planned',
    'ride_destination' => 'Solo destinations',
    'group_destination' => 'Group ride destinations',
    _ => 'From older app versions',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final usage = ref.watch(apiUsageByPurposeProvider).value ?? const [];
    if (usage.isEmpty) return const SizedBox.shrink();

    return BrodieCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('LAST 7 DAYS · ALL RIDERS', style: BrodieType.title.copyWith(color: colors.textPrimary)),
          for (final MapEntry(key: apiName, value: label) in _services.entries)
            if (usage.where((row) => row.apiName == apiName).toList() case final rows when rows.isNotEmpty) ...[
              const SizedBox(height: BrodieSpace.sm),
              Text(
                '$label: ${rows.fold(0, (sum, row) => sum + row.count)}',
                style: BrodieType.bodyStrong.copyWith(color: colors.textPrimary),
              ),
              for (final row in rows)
                Padding(
                  padding: const EdgeInsets.only(top: BrodieSpace.xxs),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _purposeLabel(row.purpose),
                          style: BrodieType.body.copyWith(color: colors.textSecondary),
                        ),
                      ),
                      Text('${row.count}', style: BrodieType.bodyStrong.copyWith(color: colors.textPrimary)),
                    ],
                  ),
                ),
            ],
        ],
      ),
    );
  }
}

class _MapDisplayNote extends StatelessWidget {
  const _MapDisplayNote();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: BrodieSpace.sm),
      child: Text(
        'Showing the map has no daily limit: it is billed per monthly rider, not per use. '
        'Recent places cost nothing to reuse.',
        style: BrodieType.caption.copyWith(color: colors.textSecondary),
      ),
    );
  }
}
