import 'package:supabase_flutter/supabase_flutter.dart';
import '/settings_model.dart';

class SettingsService {
  final _supabase = Supabase.instance.client;

  String get _userId => _supabase.auth.currentUser!.id;

  Future<AppSettings> fetchSettings() async {
    final data = await _supabase
        .from('user_settings')
        .select()
        .eq('user_id', _userId)
        .maybeSingle();

    if (data == null) return AppSettings(); // return defaults
    return AppSettings.fromJson(data);
  }

  Future<void> saveSettings(AppSettings settings) async {
    await _supabase.from('user_settings').upsert({
      'user_id': _userId,
      ...settings.toJson(),
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> deleteAccount() async {
    // Delete user data first, then call your backend to remove auth user
    await _supabase.from('user_settings').delete().eq('user_id', _userId);
    await _supabase.from('resumes').delete().eq('user_id', _userId);
    // Call your NestJS endpoint to delete the auth.users record
    // await _supabase.functions.invoke('delete-user');
    await _supabase.auth.signOut();
  }

  Future<void> changePassword(String newPassword) async {
    await _supabase.auth.updateUser(UserAttributes(password: newPassword));
  }
}