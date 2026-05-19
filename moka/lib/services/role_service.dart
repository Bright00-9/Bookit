import 'package:supabase_flutter/supabase_flutter.dart';

enum UserRole { customer, worker, unknown }

class RoleService {
  final _supabase = Supabase.instance.client;

  Future<UserRole> fetchRole() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return UserRole.unknown;

      final data = await _supabase
          .from('users')
          .select('user_role')
          .eq('id', userId)
          .maybeSingle();

      if (data == null) return UserRole.unknown;

      switch (data['user_role']) {
        case 'customer':
          return UserRole.customer;
        case 'worker':
          return UserRole.worker;
        default:
          return UserRole.unknown;
      }
    } catch (_) {
      return UserRole.unknown;
    }
  }
}