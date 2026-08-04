import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/config/env.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'data/repositories/settings_repository.dart';
import 'features/profile/application/settings_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MapboxOptions.setAccessToken(Env.mapboxAccessToken);
  await Supabase.initialize(
    url: Env.supabaseUrl,
    publishableKey: Env.supabasePublishableKey,
  );
  final prefs = await SharedPreferences.getInstance();
  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const BrodieApp(),
    ),
  );
}

class BrodieApp extends ConsumerWidget {
  const BrodieApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeControllerProvider);

    return MaterialApp.router(
      title: 'Brodie',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      routerConfig: appRouter,
    );
  }
}
