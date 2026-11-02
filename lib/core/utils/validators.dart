/// Form validators shared across screens. Each returns null when valid.
abstract final class Validators {
  static const minPasswordLength = 6;
  static const usernameRule = '3-20 characters: lowercase letters, numbers, underscores.';

  // Mirrors the `profiles_username_format` check constraint in brodie-supabase.
  static final _usernamePattern = RegExp(r'^[a-z0-9_]{3,20}$');

  static bool isValidUsername(String value) => _usernamePattern.hasMatch(value);

  static String? Function(String?) required(String message) {
    return (value) => (value == null || value.trim().isEmpty) ? message : null;
  }

  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) return 'Enter your email';
    if (!value.contains('@')) return 'Enter a valid email';
    return null;
  }

  static String? password(String? value) {
    if (value == null || value.isEmpty) return 'Enter your password';
    if (value.length < minPasswordLength) {
      return 'Password must be at least $minPasswordLength characters';
    }
    return null;
  }
}
