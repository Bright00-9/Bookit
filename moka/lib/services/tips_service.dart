import 'package:supabase_flutter/supabase_flutter.dart';

class TipsService {
  final _supabase = Supabase.instance.client;

  String get _userId => _supabase.auth.currentUser!.id;

  Future<bool> getTipsEnabled() async {
    try {
      final data = await _supabase
          .from('user_settings')
          .select('show_tips')
          .eq('user_id', _userId)
          .maybeSingle();
      return data?['show_tips'] ?? true;
    } catch (_) {
      return true; // default to showing tips if fetch fails
    }
  }

  Future<void> setTipsEnabled(bool enabled) async {
    await _supabase.from('user_settings').upsert({
      'user_id': _userId,
      'show_tips': enabled,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> disableTips() => setTipsEnabled(false);
}