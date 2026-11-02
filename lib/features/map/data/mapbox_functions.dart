import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/di/core_providers.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/errors/guard_remote.dart';
import '../domain/map_models.dart';

part 'mapbox_functions.g.dart';

/// Calls the Mapbox proxy Edge Functions in brodie-supabase
/// (`mapbox-directions`, `mapbox-search`). They hold the Mapbox token
/// server-side and enforce daily quotas, so the app never calls Mapbox's web
/// APIs directly.
class MapboxFunctions {
  MapboxFunctions(this._functions);

  final FunctionsClient _functions;

  Future<Map<String, dynamic>> invoke(
    String function,
    Map<String, Object?> body, {
    required String notFoundMessage,
    required String limitMessage,
  }) {
    return guardRemote(() async {
      try {
        final response = await _functions.invoke(function, body: body);
        return response.data as Map<String, dynamic>;
      } on FunctionException catch (error) {
        throw failureFor(error, notFoundMessage: notFoundMessage, limitMessage: limitMessage);
      }
    });
  }

  /// The functions answer "not found" and "limit reached" with a JSON `error`
  /// field; a 404 without one means the function itself isn't deployed.
  /// Other statuses are left to `guardRemote`.
  @visibleForTesting
  static Object failureFor(FunctionException error, {required String notFoundMessage, required String limitMessage}) {
    final fromFunction = error.details is Map && (error.details as Map)['error'] is String;
    return switch (error.status) {
      404 when fromFunction => NotFoundFailure(notFoundMessage),
      404 => const UnknownFailure("This isn't available right now. Try again later."),
      429 => RateLimitedFailure(limitMessage),
      _ => error,
    };
  }
}

/// GeoJSON order, as the functions expect: [longitude, latitude].
List<double> lngLat(GeoPoint point) => [point.longitude, point.latitude];

@Riverpod(keepAlive: true)
MapboxFunctions mapboxFunctions(Ref ref) => MapboxFunctions(ref.watch(supabaseClientProvider).functions);
