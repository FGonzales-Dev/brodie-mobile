/// Failures the presentation layer is allowed to see. Repositories translate
/// SDK and network exceptions into one of these (see `guardRemote`), so UI code
/// never imports Supabase or http types.
sealed class AppFailure implements Exception {
  const AppFailure(this.message);

  /// Safe to show to the user as-is.
  final String message;

  /// User-facing text for any error caught in the UI.
  static String messageFor(Object error) =>
      error is AppFailure ? error.message : const UnknownFailure().message;

  @override
  String toString() => '$runtimeType: $message';
}

class NetworkFailure extends AppFailure {
  const NetworkFailure([super.message = 'No connection. Check your network and try again.']);
}

class AuthFailure extends AppFailure {
  const AuthFailure(super.message);
}

class UnauthenticatedFailure extends AppFailure {
  const UnauthenticatedFailure([super.message = 'Your session has ended. Please sign in again.']);
}

class PermissionFailure extends AppFailure {
  const PermissionFailure([super.message = "You don't have access to do that."]);
}

class ConflictFailure extends AppFailure {
  const ConflictFailure([super.message = 'That already exists.']);
}

class NotFoundFailure extends AppFailure {
  const NotFoundFailure([super.message = "We couldn't find that."]);
}

/// A rule enforced server-side (stored procedure `raise exception`) whose
/// message is written for the user.
class ValidationFailure extends AppFailure {
  const ValidationFailure(super.message);
}

/// A daily usage limit (e.g. route requests) was reached; see the
/// `consume_api_quota` function in brodie-supabase.
class RateLimitedFailure extends AppFailure {
  const RateLimitedFailure([super.message = "You've reached today's limit for this. Try again tomorrow."]);
}

class LocationFailure extends AppFailure {
  const LocationFailure([super.message = "Couldn't get your location. Check that location services are on."]);
}

class UnknownFailure extends AppFailure {
  const UnknownFailure([super.message = 'Something went wrong. Please try again.']);
}
