import 'package:supabase_flutter/supabase_flutter.dart';

const String supabaseUrl = 'https://xtbsezfdmeuhfycglegk.supabase.co';      
const String supabaseAnonKey = 'sb_publishable_b2mO7hKBJ2qF0T2rjQNesg_nz5_2Ixe'; 

final supabase = Supabase.instance.client;

Future<void> initSupabase() async {
  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );
}





