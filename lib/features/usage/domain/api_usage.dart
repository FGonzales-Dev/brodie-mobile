import 'dart:math' as math;

import 'package:freezed_annotation/freezed_annotation.dart';

part 'api_usage.freezed.dart';

/// Today's use of one rate-limited service (e.g. route previews), for the
/// signed-in rider and across all riders.
@freezed
abstract class ApiUsage with _$ApiUsage {
  const factory ApiUsage({
    required String apiName,
    required String label,
    required int usedToday,
    required int dailyLimit,
    required int allRidersUsedToday,
    required int allRidersDailyLimit,
    required DateTime resetsAt,
  }) = _ApiUsage;

  const ApiUsage._();

  // Refused calls are counted too, so "used" can pass the limit.
  int get remaining => math.max(0, dailyLimit - usedToday);
  int get allRidersRemaining => math.max(0, allRidersDailyLimit - allRidersUsedToday);

  /// What actually stops the rider: whichever allowance runs out first.
  int get availableNow => math.min(remaining, allRidersRemaining);
}
