import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design_system/design_system.dart';
import '../data/usage_repository.dart';
import '../domain/api_usage.dart';

/// Today's allowance for the services with a daily cap (route previews,
/// place searches): what's left for this rider and for everyone.
class UsageScreen extends ConsumerWidget {
  const UsageScreen({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(myApiUsageProvider);
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
    final resetsAt = MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(usage.resetsAt));

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
