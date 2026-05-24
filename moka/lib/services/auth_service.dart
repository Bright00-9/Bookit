import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  // ── Sign up ───────────────────────────────────────────────
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

    // Create default user_settings row on signup
    if (response.user != null) {
      try {
        await supabase.from('user_settings').upsert({
          'user_id': response.user!.id,
          'user_role': role,
          'job_radius_km': 10,
          'notify_new_jobs': true,
          'notify_application_updates': true,
          'notify_messages': true,
          'notify_promotions': false,
          'show_tips': true,
        });
      } catch (e) {
        // Non-critical — settings will be created on first load
        debugPrint('Settings init error: $e');
      }
    }

    return response;
  }

  // ── Login ─────────────────────────────────────────────────
  static Future<AuthResponse> login({
    required String email,
    required String password,
  }) async {
    return await supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  // ── Logout ────────────────────────────────────────────────
  // Clears FCM token before signing out so worker
  // stops receiving notifications after logout
  static Future<void> logout() async {
    try {
      // Clear FCM token from database before signing out
      await updateFcmToken(null);
    } catch (_) {
      // Non-critical — proceed with logout regardless
    }
    await supabase.auth.signOut();
  }

  // ── Get current user profile ──────────────────────────────
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

  // ── Get current user role ─────────────────────────────────
  static Future<String?> getCurrentRole() async {
    final profile = await getCurrentProfile();
    return profile?['role'];
  }

  // ── Update FCM token ──────────────────────────────────────
  // Accepts null to clear token on logout
  static Future<void> updateFcmToken(String? token) async {
    final user = supabase.auth.currentUser;
    if (user == null) return;
    await supabase
        .from('profiles')
        .update({'fcm_token': token}).eq('id', user.id);
  }

  // ── Get current user email ────────────────────────────────
  static String? get currentEmail =>
      supabase.auth.currentUser?.email;

  // ── Update profile name and phone ─────────────────────────
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

  // ── Update worker online status and location ──────────────
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

  // ── Check if user is logged in ────────────────────────────
  static bool get isLoggedIn =>
      supabase.auth.currentUser != null;

  // ── Get current user id ───────────────────────────────────
  static String? get currentUserId =>
      supabase.auth.currentUser?.id;

  // ── Refresh session ───────────────────────────────────────
  // Call this on app startup to restore session
  static Future<bool> restoreSession() async {
    try {
      final session = supabase.auth.currentSession;
      if (session == null) return false;

      // Session is still valid
      if (!session.isExpired) return true;

      // Try to refresh
      final response =
          await supabase.auth.refreshSession();
      return response.session != null;
    } catch (_) {
      return false;
    }
  }

  // ── Change password ───────────────────────────────────────
  static Future<void> changePassword(
      String newPassword) async {
    await supabase.auth
        .updateUser(UserAttributes(password: newPassword));
  }

  // ── Delete account ────────────────────────────────────────
  // Deletes all user data before signing out.
  // The auth.users record deletion requires a
  // Supabase Edge Function or admin API call.
  static Future<void> deleteAccount() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    try {
      // Clear FCM token
      await updateFcmToken(null);

      // Delete user data in order
      await supabase
          .from('user_settings')
          .delete()
          .eq('user_id', user.id);

      await supabase
          .from('resumes')
          .delete()
          .eq('user_id', user.id);

      await supabase
          .from('worker_verifications')
          .delete()
          .eq('user_id', user.id);

      // Sign out — auth record deletion handled by
      // Supabase Edge Function 'delete-user'
      await supabase.auth.signOut();
    } catch (e) {
      debugPrint('Delete account error: $e');
      rethrow;
    }
  }

  // ── Send password reset email ─────────────────────────────
  static Future<void> sendPasswordReset(
      String email) async {
    await supabase.auth.resetPasswordForEmail(email);
  }

  // ── Update user role in settings ──────────────────────────
  // Call this if role changes or on first settings load
  static Future<void> syncRoleToSettings() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final profile = await getCurrentProfile();
    final role = profile?['role'];
    if (role == null) return;

    await supabase.from('user_settings').upsert({
      'user_id': user.id,
      'user_role': role,
    });
  }
}