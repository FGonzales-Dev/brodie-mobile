import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_failure.dart';

/// Runs a data-layer call and rethrows anything it throws as an [AppFailure],
/// keeping the original stack trace. Every repository method goes through this.
Future<T> guardRemote<T>(Future<T> Function() call) async {
  try {
    return await call();
  } catch (error, stackTrace) {
    Error.throwWithStackTrace(mapToFailure(error), stackTrace);
  }
}

AppFailure mapToFailure(Object error) {
  return switch (error) {
    AppFailure() => error,
    AuthException(:final message) => AuthFailure(message),
    PostgrestException(:final code, :final message) => _fromPostgrest(code, message),
    FunctionException(:final status) => _fromFunctionStatus(status),
    SocketException() || TimeoutException() || http.ClientException() => const NetworkFailure(),
    _ => const UnknownFailure(),
  };
}

/// Edge Functions answer with plain HTTP statuses (see brodie-supabase).
AppFailure _fromFunctionStatus(int status) => switch (status) {
  401 => const UnauthenticatedFailure(),
  404 => const NotFoundFailure(),
  429 => const RateLimitedFailure(),
  502 || 503 || 504 => const NetworkFailure('The service is temporarily unavailable. Try again shortly.'),
  _ => const UnknownFailure(),
};

// Codes: https://www.postgresql.org/docs/current/errcodes-appendix.html
AppFailure _fromPostgrest(String? code, String message) {
  return switch (code) {
    '23505' => const ConflictFailure(),
    '42501' => const PermissionFailure(),
    'PGRST116' => const NotFoundFailure(),
    // `raise exception` in our stored procedures carries a user-facing message.
    'P0001' => ValidationFailure(message),
    _ => const UnknownFailure(),
  };
}
