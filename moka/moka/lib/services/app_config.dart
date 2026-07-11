const String backendBaseUrl = String.fromEnvironment('BACKEND_BASE_URL');

const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const String supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

void validateAppConfig() {
  if (backendBaseUrl.isEmpty || supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
    throw StateError(
      'BACKEND_BASE_URL, SUPABASE_URL and SUPABASE_ANON_KEY must be provided as --dart-define values.',
    );
  }
}
