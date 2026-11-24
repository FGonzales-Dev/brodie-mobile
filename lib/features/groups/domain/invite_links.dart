/// Group invite links: `https://<host>/join/<code>`. The host is the small
/// static site in `brodie-links`, which serves the files that let iOS and
/// Android open these links straight in the app, and a fallback page for
/// people who don't have it.
abstract final class InviteLinks {
  /// Change this and the site's project name together.
  static const host = 'brodie-app.pages.dev';

  static const _joinPath = 'join';

  static Uri forCode(String code) => Uri.https(host, '/$_joinPath/$code');

  /// Case, spaces and dashes don't matter, the same as on the server.
  static String normalize(String code) => code.toUpperCase().replaceAll(RegExp(r'[\s-]'), '');

  /// The code in what a rider typed or pasted: a bare code or a whole
  /// invite link. Null when it's neither.
  static String? codeFrom(String input) {
    final trimmed = input.trim();
    final uri = Uri.tryParse(trimmed);
    if (uri != null && uri.host.isNotEmpty) {
      final segments = uri.pathSegments;
      final at = segments.indexOf(_joinPath);
      if (uri.host != host || at < 0 || at + 1 >= segments.length) return null;
      return _validOrNull(normalize(segments[at + 1]));
    }
    return _validOrNull(normalize(trimmed));
  }

  static String? _validOrNull(String code) => RegExp(r'^[A-Z0-9]{4,12}$').hasMatch(code) ? code : null;
}
