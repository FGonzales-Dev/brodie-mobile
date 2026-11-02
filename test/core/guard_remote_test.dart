import 'dart:io';

import 'package:brodie/core/errors/app_failure.dart';
import 'package:brodie/core/errors/guard_remote.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('mapToFailure', () {
    test('maps Postgres error codes to specific failures', () {
      expect(mapToFailure(const PostgrestException(message: 'dup', code: '23505')), isA<ConflictFailure>());
      expect(mapToFailure(const PostgrestException(message: 'no', code: '42501')), isA<PermissionFailure>());
      expect(mapToFailure(const PostgrestException(message: 'none', code: 'PGRST116')), isA<NotFoundFailure>());
    });

    test('keeps the message of errors raised by stored procedures', () {
      final failure = mapToFailure(const PostgrestException(message: 'Username already taken', code: 'P0001'));

      expect(failure, isA<ValidationFailure>());
      expect(failure.message, 'Username already taken');
    });

    test('maps auth and network errors', () {
      expect(mapToFailure(const AuthException('Invalid login credentials')).message, 'Invalid login credentials');
      expect(mapToFailure(const SocketException('offline')), isA<NetworkFailure>());
    });

    test('maps Edge Function statuses', () {
      expect(mapToFailure(const FunctionException(status: 429)), isA<RateLimitedFailure>());
      expect(mapToFailure(const FunctionException(status: 401)), isA<UnauthenticatedFailure>());
      expect(mapToFailure(const FunctionException(status: 404)), isA<NotFoundFailure>());
      expect(mapToFailure(const FunctionException(status: 502)), isA<NetworkFailure>());
      expect(mapToFailure(const FunctionException(status: 500)), isA<UnknownFailure>());
    });

    test('passes AppFailures through and hides anything unexpected', () {
      const original = NotFoundFailure('gone');

      expect(mapToFailure(original), same(original));
      expect(mapToFailure(StateError('boom')), isA<UnknownFailure>());
    });
  });

  test('guardRemote rethrows as AppFailure', () async {
    await expectLater(
      guardRemote<void>(() async => throw const SocketException('offline')),
      throwsA(isA<NetworkFailure>()),
    );
  });
}
