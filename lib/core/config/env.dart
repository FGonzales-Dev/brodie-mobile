import 'package:envied/envied.dart';

part 'env.g.dart';

@Envied(path: '.env')
abstract class Env {
  @EnviedField(varName: 'SUPABASE_URL')
  static const String supabaseUrl = _Env.supabaseUrl;

  @EnviedField(varName: 'SUPABASE_PUBLISHABLE_KEY')
  static const String supabasePublishableKey = _Env.supabasePublishableKey;

  @EnviedField(varName: 'MAPBOX_ACCESS_TOKEN')
  static const String mapboxAccessToken = _Env.mapboxAccessToken;
}
