import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Tracks whether the signed-in user has completed username selection, so
/// the router's redirect callback can gate access to the app on it — mirrors
/// how auth state itself is read directly from the Supabase client rather
/// than through Riverpod, since `redirect` runs outside the widget tree.
class ProfileGate extends ChangeNotifier {
  ProfileGate._() {
    Supabase.instance.client.auth.onAuthStateChange.listen((state) {
      final session = state.session;
      if (session == null) {
        _setHasUsername(null);
      } else {
        _refresh(session.user.id);
      }
    });
  }

  static final instance = ProfileGate._();

  bool? _hasUsername;
  bool? get hasUsername => _hasUsername;

  Future<void> _refresh(String userId) async {
    try {
      final response =
          await Supabase.instance.client.from('profiles').select('username').eq('id', userId).single();
      _setHasUsername((response['username'] as String?) != null);
    } catch (_) {
      _setHasUsername(false);
    }
  }

  /// Called right after `set_username()` succeeds, so the redirect fires
  /// immediately instead of waiting on a network refetch.
  void markHasUsername() => _setHasUsername(true);

  void _setHasUsername(bool? value) {
    if (_hasUsername == value) return;
    _hasUsername = value;
    notifyListeners();
  }
}
