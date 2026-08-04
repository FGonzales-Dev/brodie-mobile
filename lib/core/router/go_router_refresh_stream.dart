import 'dart:async';

import 'package:flutter/foundation.dart';

/// Bridges a [Stream] to a [Listenable] so `go_router`'s `refreshListenable`
/// re-evaluates redirects whenever the stream emits (e.g. auth state changes).
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
