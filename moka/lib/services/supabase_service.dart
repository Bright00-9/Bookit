import 'package:supabase_flutter/supabase_flutter.dart';

const String supabaseUrl = 'YOUR_SUPABASE_URL';       // 🔁 Replace this
const String supabaseAnonKey = 'YOUR_SUPABASE_ANON_KEY'; // 🔁 Replace this

final supabase = Supabase.instance.client;

Future<void> initSupabase() async {
  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );
}
