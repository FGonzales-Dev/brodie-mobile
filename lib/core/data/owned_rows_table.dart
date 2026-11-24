import 'package:supabase_flutter/supabase_flutter.dart';

import '../errors/app_failure.dart';
import '../errors/guard_remote.dart';

/// CRUD for a table whose rows belong to the signed-in user via `user_id`
/// (RLS enforces ownership server-side). Vehicles and emergency contacts are
/// both this shape; each supplies its table name and row mapping.
///
/// [T] is the domain entity, [D] the user-editable draft.
class OwnedRowsTable<T, D> {
  const OwnedRowsTable(this._client, {required this.table, required this.fromRow, required this.toRow});

  final SupabaseClient _client;
  final String table;
  final T Function(Map<String, dynamic> row) fromRow;
  final Map<String, Object?> Function(D draft) toRow;

  String get _userId => _client.auth.currentUser?.id ?? (throw const UnauthenticatedFailure());

  Future<List<T>> fetchMine() => guardRemote(() async {
    final rows = await _client.from(table).select().eq('user_id', _userId).order('created_at');
    return rows.map(fromRow).toList();
  });

  Future<void> insert(D draft) => guardRemote(() => _client.from(table).insert({'user_id': _userId, ...toRow(draft)}));

  Future<void> update(String id, D draft) => guardRemote(() => _client.from(table).update(toRow(draft)).eq('id', id));

  Future<void> delete(String id) => guardRemote(() => _client.from(table).delete().eq('id', id));
}
