import 'dart:async';

/// Runs only the last action scheduled within [delay], e.g. a search request
/// after the user stops typing. Call [cancel] when the owner is disposed.
class Debouncer {
  Debouncer(this.delay);

  final Duration delay;
  Timer? _timer;

  void run(void Function() action) {
    _timer?.cancel();
    _timer = Timer(delay, action);
  }

  void cancel() => _timer?.cancel();
}
