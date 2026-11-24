import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/di/core_providers.dart';
import '../../../core/errors/guard_remote.dart';
import '../domain/api_usage.dart';

part 'usage_repository.g.dart';

/// Daily limits and today's usage of the rate-limited services, read from
/// `get_my_api_usage` (brodie-supabase), which reports the same limits the
/// Edge Functions enforce.
class UsageRepository {
  UsageRepository(this._client);

  final SupabaseClient _client;

  Future<List<ApiUsage>> fetchMyUsage() => guardRemote(() async {
    final rows = await _client.rpc('get_my_api_usage');
    return (rows as List).cast<Map<String, dynamic>>().map(usageFromRow).toList();
  });

  /// The last [days] days' billed calls by purpose, all riders.
  Future<List<ApiUsageByPurpose>> fetchUsageByPurpose({int days = 7}) => guardRemote(() async {
    final rows = await _client.rpc('get_api_usage_by_purpose', params: {'p_days': days});
    return (rows as List).cast<Map<String, dynamic>>().map(byPurposeFromRow).toList();
  });

  @visibleForTesting
  static ApiUsageByPurpose byPurposeFromRow(Map<String, dynamic> row) => (
    apiName: row['api_name'] as String,
    purpose: row['purpose'] as String,
    count: (row['call_count'] as num).toInt(),
  );

  @visibleForTesting
  static ApiUsage usageFromRow(Map<String, dynamic> row) => ApiUsage(
    apiName: row['api_name'] as String,
    label: row['label'] as String,
    usedToday: (row['used_today'] as num).toInt(),
    dailyLimit: (row['user_daily_limit'] as num).toInt(),
    allRidersUsedToday: (row['all_riders_used_today'] as num).toInt(),
    allRidersDailyLimit: (row['global_daily_limit'] as num).toInt(),
    resetsAt: DateTime.parse(row['resets_at'] as String).toLocal(),
  );
}

@Riverpod(keepAlive: true)
UsageRepository usageRepository(Ref ref) => UsageRepository(ref.watch(supabaseClientProvider));

@riverpod
Future<List<ApiUsage>> myApiUsage(Ref ref) => ref.watch(usageRepositoryProvider).fetchMyUsage();

/// Where the last week's billed calls went, for the Usage screen.
@riverpod
Future<List<ApiUsageByPurpose>> apiUsageByPurpose(Ref ref) => ref.watch(usageRepositoryProvider).fetchUsageByPurpose();
