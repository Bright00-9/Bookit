import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

class AuthService {
  // Sign up
  static Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String name,
    required String phone,
    required String role,
    String? skill,
  }) async {
    final response = await supabase.auth.signUp(
      email: email,
      password: password,
      data: {        
        'name': name,
        'phone': phone,
        'role': role,
        'skill': skill,
      },
    );
    return response; 
  }

  // Login
  static Future<AuthResponse> login({
    required String email,
    required String password,
  }) async {
    return await supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  // Logout
  static Future<void> logout() async {
    await supabase.auth.signOut();
  }

  // Get current user profile
  static Future<Map<String, dynamic>?> getCurrentProfile() async {
    final user = supabase.auth.currentUser;
    if (user == null) return null;

    final response = await supabase
        .from('profiles')
        .select()
        .eq('id', user.id)
        .single();

    return response;
  }

  // Get current user role
  static Future<String?> getCurrentRole() async {
    final profile = await getCurrentProfile();
    return profile?['role'];
  }

  // Update FCM token
  static Future<void> updateFcmToken(String token) async {
    final user = supabase.auth.currentUser;
    if (user == null) return;
    await supabase
        .from('profiles')
        .update({'fcm_token': token}).eq('id', user.id);
  }

  // Get current user email
  static String? get currentEmail => supabase.auth.currentUser?.email;

  // Update profile name and phone
  static Future<void> updateProfile({
    required String name,
    required String phone,
  }) async {
    final user = supabase.auth.currentUser;
    if (user == null) return;
    await supabase.from('profiles').update({
      'name': name,
      'phone': phone,
    }).eq('id', user.id);
  }

  // Update worker online status and location
  static Future<void> updateWorkerStatus({
    required bool isOnline,
    double? lat,
    double? lng,
  }) async {
    final user = supabase.auth.currentUser;
    if (user == null) return;
    await supabase.from('profiles').update({
      'is_online': isOnline,
      if (lat != null) 'lat': lat,
      if (lng != null) 'lng': lng,
    }).eq('id', user.id);
  }
}
