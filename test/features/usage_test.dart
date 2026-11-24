import 'package:brodie/features/usage/data/usage_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Map<String, dynamic> row({int used = 12, int limit = 30, int allUsed = 4, int allLimit = 16}) => {
    'api_name': 'mapbox_search',
    'label': 'Place searches',
    'used_today': used,
    'user_daily_limit': limit,
    'all_riders_used_today': allUsed,
    'global_daily_limit': allLimit,
    'resets_at': '2026-10-30T00:00:00+00:00',
  };

  test('reads get_my_api_usage rows and works out what is left', () {
    final usage = UsageRepository.usageFromRow(row());

    expect(usage.label, 'Place searches');
    expect(usage.remaining, 18);
    expect(usage.allRidersRemaining, 12);
    expect(usage.availableNow, 12, reason: 'the shared limit runs out first');
    expect(usage.resetsAt.isUtc, isFalse, reason: 'shown in local time');
  });

  test('never reports a negative allowance (refused calls are counted too)', () {
    final usage = UsageRepository.usageFromRow(row(used: 33, allUsed: 20));

    expect(usage.remaining, 0);
    expect(usage.allRidersRemaining, 0);
  });
}
