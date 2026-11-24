import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design_system/design_system.dart';
import 'feedback.dart';
import 'owned_rows_controller.dart';

/// Full list-management screen for the user's own rows: list, empty state,
/// add button, and edit/delete per row with confirmation and feedback.
/// Each feature supplies the row presentation and a form sheet that pops a
/// draft [D].
class OwnedRowsScreen<T, D> extends ConsumerWidget {
  const OwnedRowsScreen({
    super.key,
    required this.provider,
    required this.title,
    required this.noun,
    required this.empty,
    required this.idOf,
    required this.titleOf,
    required this.subtitleOf,
    required this.leadingOf,
    required this.formBuilder,
    this.afterDelete,
  });

  final AsyncNotifierProvider<OwnedRowsController<T, D>, List<T>> provider;
  final String title;

  /// Singular, lowercase ("vehicle"), used in buttons and messages.
  final String noun;
  final EmptyState empty;
  final String Function(T item) idOf;
  final String Function(T item) titleOf;
  final String? Function(T item) subtitleOf;
  final Widget Function(T item) leadingOf;

  /// Builds the add (null) or edit form; it pops a draft when saved.
  final Widget Function(T? existing) formBuilder;

  /// Cleanup after a row is deleted, e.g. removing its photo file.
  final Future<void> Function(WidgetRef ref, T item)? afterDelete;

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final draft = await showBrodieSheet<D>(context, builder: (_) => formBuilder(null));
    if (draft == null || !context.mounted) return;
    await context.runWithFeedback(() => ref.read(provider.notifier).add(draft), successMessage: 'Saved');
  }

  Future<void> _edit(BuildContext context, WidgetRef ref, T item) async {
    final draft = await showBrodieSheet<D>(context, builder: (_) => formBuilder(item));
    if (draft == null || !context.mounted) return;
    await context.runWithFeedback(() => ref.read(provider.notifier).edit(idOf(item), draft), successMessage: 'Saved');
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, T item) async {
    final confirmed = await showBrodieConfirmDialog(
      context,
      title: 'Delete $noun?',
      message: 'Remove "${titleOf(item)}". This cannot be undone.',
      confirmLabel: 'Delete',
    );
    if (!confirmed || !context.mounted) return;
    await context.runWithFeedback(() async {
      await ref.read(provider.notifier).remove(idOf(item));
      await afterDelete?.call(ref, item);
    });
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: BrodieAppBar(title: title),
      body: AsyncValueView(
        value: ref.watch(provider),
        onRetry: () => ref.invalidate(provider),
        data: (items) => items.isEmpty
            ? empty
            : ListView(
                padding: const EdgeInsets.all(BrodieSpace.md),
                children: [
                  BrodieListGroup(
                    children: [
                      for (final item in items)
                        BrodieListTile(
                          leading: leadingOf(item),
                          title: titleOf(item),
                          subtitle: subtitleOf(item),
                          trailing: EditDeleteActions(
                            onEdit: () => _edit(context, ref, item),
                            onDelete: () => _delete(context, ref, item),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(BrodieSpace.md),
          child: BrodieButton(label: 'Add $noun', icon: Icons.add, onPressed: () => _add(context, ref)),
        ),
      ),
    );
  }
}
