import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_config.dart';

final supabase = Supabase.instance.client;

Future<void> initSupabase() async {
  validateAppConfig();

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );
}





