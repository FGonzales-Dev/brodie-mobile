import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../errors/app_failure.dart';
import '../app_theme.dart';
import '../tokens.dart';
import 'brodie_button.dart';

/// Centered icon, title, message and optional action for empty lists and
/// blocking states (e.g. missing permission).
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, this.message, this.action});

  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final content = Padding(
      padding: const EdgeInsets.all(BrodieSpace.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 44, color: colors.textSecondary),
          const SizedBox(height: BrodieSpace.md),
          Text(
            title.toUpperCase(),
            textAlign: TextAlign.center,
            style: BrodieType.title.copyWith(color: colors.textPrimary),
          ),
          if (message != null) ...[
            const SizedBox(height: BrodieSpace.xs),
            Text(
              message!,
              textAlign: TextAlign.center,
              style: BrodieType.body.copyWith(color: colors.textSecondary),
            ),
          ],
          if (action != null) ...[const SizedBox(height: BrodieSpace.lg), action!],
        ],
      ),
    );
    // Centered and scrollable when it fills a screen; inline inside lists,
    // where the height is unbounded.
    return LayoutBuilder(
      builder: (context, constraints) => constraints.hasBoundedHeight
          ? Center(child: SingleChildScrollView(child: content))
          : content,
    );
  }
}

class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.error, this.onRetry});

  final Object error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.error_outline,
      title: 'Something broke',
      message: AppFailure.messageFor(error),
      action: onRetry == null ? null : BrodieButton.secondary(label: 'Try again', onPressed: onRetry),
    );
  }
}

class LoadingState extends StatelessWidget {
  const LoadingState({super.key});

  @override
  Widget build(BuildContext context) => const Center(child: CircularProgressIndicator());
}

/// Renders an [AsyncValue] with the shared loading and error states.
/// While refreshing, the previous data stays on screen.
class AsyncValueView<T> extends StatelessWidget {
  const AsyncValueView({super.key, required this.value, required this.data, this.onRetry});

  final AsyncValue<T> value;
  final Widget Function(T data) data;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return value.when(
      skipLoadingOnRefresh: true,
      skipLoadingOnReload: true,
      data: data,
      loading: () => const LoadingState(),
      error: (error, _) => ErrorState(error: error, onRetry: onRetry),
    );
  }
}
