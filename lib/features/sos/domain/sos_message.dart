import 'package:flutter/foundation.dart';

import '../../map/domain/map_models.dart';

/// The SOS text sent to emergency contacts, and the links that open the
/// phone's messages and dialer apps with it ready. Apps can't send a text
/// themselves on iOS or Android; the rider taps Send.
abstract final class SosMessage {
  /// What the contacts read. [time] is already formatted for the rider's
  /// locale, e.g. "8:04 AM".
  static String text({required String? username, required GeoFix? fix, required String time}) {
    final who = username == null ? 'a Brodie rider' : '@$username on Brodie';
    final where = switch (fix) {
      null => 'I could not get my location.',
      final fix =>
        'My location: ${mapLink(fix.position)} '
            '(within ${fix.accuracyMeters.isFinite ? fix.accuracyMeters.round() : '?'} m, at $time).',
    };
    return 'SOS from $who. I may need help. $where This message was sent from the Brodie app.';
  }

  /// Opens in Google Maps or the browser on any phone.
  static String mapLink(GeoPoint point) =>
      'https://maps.google.com/?q=${point.latitude.toStringAsFixed(6)},${point.longitude.toStringAsFixed(6)}';

  /// A new text to every number in [phones], with [body] filled in.
  ///
  /// iOS only takes several recipients through `sms:/open?addresses=...`;
  /// Android takes them comma-separated in the path. The body is encoded by
  /// hand: [Uri]'s own query encoding turns spaces into `+`, which some
  /// messages apps show literally.
  static Uri smsUri(List<String> phones, String body, {required TargetPlatform platform}) {
    final numbers = [for (final phone in phones) ?_dialable(phone)].join(',');
    final encodedBody = Uri.encodeComponent(body);
    return platform == TargetPlatform.iOS
        ? Uri.parse('sms:/open?addresses=$numbers&body=$encodedBody')
        : Uri.parse('sms:$numbers?body=$encodedBody');
  }

  static Uri callUri(String phone) => Uri(scheme: 'tel', path: _dialable(phone) ?? phone);

  /// Digits only, keeping a leading +; null when nothing dialable is left.
  static String? _dialable(String phone) {
    final trimmed = phone.trim();
    final digits = trimmed.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return null;
    return trimmed.startsWith('+') ? '+$digits' : digits;
  }
}
