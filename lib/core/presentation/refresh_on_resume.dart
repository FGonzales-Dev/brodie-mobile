import 'package:flutter/widgets.dart';

/// Calls [onResume] whenever the app returns to the foreground, e.g. to
/// re-check a permission the user may have changed in system settings.
class RefreshOnResume extends StatefulWidget {
  const RefreshOnResume({super.key, required this.onResume, required this.child});

  final VoidCallback onResume;
  final Widget child;

  @override
  State<RefreshOnResume> createState() => _RefreshOnResumeState();
}

class _RefreshOnResumeState extends State<RefreshOnResume> {
  late final _listener = AppLifecycleListener(onResume: () => widget.onResume());

  @override
  void dispose() {
    _listener.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
