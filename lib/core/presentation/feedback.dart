import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;

import '../errors/app_failure.dart';

/// For screens driven by an action view model (`AsyncNotifier<void>`): call
/// from `build` to show a snackbar whenever the action fails.
extension ActionErrorListener on WidgetRef {
  void showErrorsOf<T>(ProviderListenable<AsyncValue<T>> provider, BuildContext context) {
    listen(provider, (previous, next) {
      if (next case AsyncError(:final error) when !next.isLoading) context.showError(error);
    });
  }
}

/// Snackbar feedback and the try/catch-then-report pattern every screen
/// action needs.
extension FeedbackContext on BuildContext {
  void showMessage(String message) {
    ScaffoldMessenger.of(this)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void showError(Object error) => showMessage(AppFailure.messageFor(error));

  /// Runs [action] and reports failure (and optionally success) in a snackbar.
  /// Returns whether it succeeded, so callers can navigate only on success.
  Future<bool> runWithFeedback(Future<void> Function() action, {String? successMessage}) async {
    try {
      await action();
      if (successMessage != null && mounted) showMessage(successMessage);
      return true;
    } catch (error) {
      if (mounted) showError(error);
      return false;
    }
  }
}
