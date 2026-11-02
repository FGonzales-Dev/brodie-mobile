import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;

import '../data/owned_rows_table.dart';

/// View model for a screen that lists, adds, edits and deletes the user's own
/// rows (see [OwnedRowsTable]). After each change the list reloads while the
/// previous data stays visible; failures propagate to the caller.
class OwnedRowsController<T, D> extends AsyncNotifier<List<T>> {
  OwnedRowsController(this._table);

  final ProviderListenable<OwnedRowsTable<T, D>> _table;

  @override
  Future<List<T>> build() => ref.watch(_table).fetchMine();

  Future<void> add(D draft) => _mutate((table) => table.insert(draft));

  Future<void> edit(String id, D draft) => _mutate((table) => table.update(id, draft));

  Future<void> remove(String id) => _mutate((table) => table.delete(id));

  Future<void> _mutate(Future<void> Function(OwnedRowsTable<T, D> table) change) async {
    await change(ref.read(_table));
    ref.invalidateSelf();
    await future;
  }
}

/// Declares an auto-disposed [OwnedRowsController] provider for [table].
AsyncNotifierProvider<OwnedRowsController<T, D>, List<T>> ownedRowsControllerProvider<T, D>(
  ProviderListenable<OwnedRowsTable<T, D>> table,
) {
  return AsyncNotifierProvider.autoDispose(() => OwnedRowsController<T, D>(table));
}
