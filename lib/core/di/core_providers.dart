import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/env.dart';

part 'core_providers.g.dart';

/// The only place the app touches the Supabase singleton. Repositories get the
/// client through this provider so tests can override it.
@Riverpod(keepAlive: true)
SupabaseClient supabaseClient(Ref ref) => Supabase.instance.client;

/// Loaded once in bootstrap() and injected with an override.
@Riverpod(keepAlive: true)
SharedPreferences sharedPreferences(Ref ref) {
  throw UnimplementedError('sharedPreferencesProvider must be overridden in bootstrap()');
}

@Riverpod(keepAlive: true)
String mapboxAccessToken(Ref ref) => Env.mapboxAccessToken;
