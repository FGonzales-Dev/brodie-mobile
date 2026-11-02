import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/presentation/refresh_on_resume.dart';
import '../application/ride_providers.dart';

/// Uploads rides that finished without signal: once when the signed-in app
/// opens, and again whenever it returns to the foreground.
class PendingRideUploader extends ConsumerStatefulWidget {
  const PendingRideUploader({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<PendingRideUploader> createState() => _PendingRideUploaderState();
}

class _PendingRideUploaderState extends ConsumerState<PendingRideUploader> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _upload());
  }

  void _upload() {
    if (mounted) ref.read(rideSyncProvider.notifier).uploadPending();
  }

  @override
  Widget build(BuildContext context) => RefreshOnResume(onResume: _upload, child: widget.child);
}
