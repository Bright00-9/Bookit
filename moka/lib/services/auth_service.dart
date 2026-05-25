import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

class AuthService {
  // ── Sign up ───────────────────────────────────────────
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
        if (skill != null) 'skill': skill,
      },
    );

    // Only create settings if session exists
    // (no email confirmation required)
    // If confirmation required, profile may not
    // exist yet so skip silently
    if (response.user != null &&
        response.session != null) {
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
        debugPrint('Settings init error: $e');
      }
    }

    return response;
  }

  // ── Login ─────────────────────────────────────────────
  static Future<AuthResponse> login({
    required String email,
    required String password,
  }) async {
    return await supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  // ── Logout ────────────────────────────────────────────
  // Clears FCM token before signing out
  static Future<void> logout() async {
    try {
      await updateFcmToken(null);
    } catch (_) {}
    await supabase.auth.signOut();
  }

  // ── Get current user profile ──────────────────────────
  // Uses maybeSingle so it returns null instead
  // of throwing when no row found
  static Future<Map<String, dynamic>?> getCurrentProfile() async {
    final user = supabase.auth.currentUser;
    if (user == null) return null;

    try {
      final response = await supabase
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();
      return response;
    } catch (e) {
      debugPrint('Error loading profile: $e');
      return null;
    }
  }

  // ── Get current user role ─────────────────────────────
  static Future<String?> getCurrentRole() async {
    final profile = await getCurrentProfile();
    return profile?['role'];
  }

  // ── Update FCM token ──────────────────────────────────
  // Accepts null to clear token on logout
  static Future<void> updateFcmToken(
      String? token) async {
    final user = supabase.auth.currentUser;
    if (user == null) return;
    try {
      await supabase
          .from('profiles')
          .update({'fcm_token': token})
          .eq('id', user.id);
    } catch (e) {
      debugPrint('FCM token update error: $e');
    }
  }

  // ── Get current user email ────────────────────────────
  static String? get currentEmail =>
      supabase.auth.currentUser?.email;

  // ── Get current user id ───────────────────────────────
  static String? get currentUserId =>
      supabase.auth.currentUser?.id;

  // ── Check if user is logged in ────────────────────────
  static bool get isLoggedIn =>
      supabase.auth.currentUser != null;

  // ── Update profile name and phone ─────────────────────
  static Future<void> updateProfile({
    required String name,
    required String phone,
  }) async {
    final user = supabase.auth.currentUser;
    if (user == null) return;
    try {
      await supabase.from('profiles').update({
        'name': name,
        'phone': phone,
      }).eq('id', user.id);
    } catch (e) {
      debugPrint('Update profile error: $e');
      rethrow;
    }
  }

  // ── Update worker online status and location ──────────
  static Future<void> updateWorkerStatus({
    required bool isOnline,
    double? lat,
    double? lng,
  }) async {
    final user = supabase.auth.currentUser;
    if (user == null) return;
    try {
      await supabase.from('profiles').update({
        'is_online': isOnline,
        if (lat != null) 'lat': lat,
        if (lng != null) 'lng': lng,
      }).eq('id', user.id);
    } catch (e) {
      debugPrint('Worker status update error: $e');
    }
  }

  // ── Restore session on app startup ───────────────────
  static Future<bool> restoreSession() async {
    try {
      final session =
          supabase.auth.currentSession;
      if (session == null) return false;
      if (!session.isExpired) return true;
      final response =
          await supabase.auth.refreshSession();
      return response.session != null;
    } catch (_) {
      return false;
    }
  }

  // ── Change password ───────────────────────────────────
  static Future<void> changePassword(
      String newPassword) async {
    await supabase.auth.updateUser(
        UserAttributes(password: newPassword));
  }

  // ── Send password reset email ─────────────────────────
  static Future<void> sendPasswordReset(
      String email) async {
    await supabase.auth
        .resetPasswordForEmail(email);
  }

  // ── Delete account ────────────────────────────────────
  // Clears all user data then signs out.
  // Auth record deletion requires admin API
  // or a Supabase Edge Function.
  static Future<void> deleteAccount() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    try {
      // Clear FCM token first
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

      // Sign out — auth.users record deletion
      // handled server-side via Edge Function
      await supabase.auth.signOut();
    } catch (e) {
      debugPrint('Delete account error: $e');
      rethrow;
    }
  }

  // ── Sync role to user_settings ────────────────────────
  // Call after login to keep user_role in sync
  static Future<void> syncRoleToSettings() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    try {
      final profile = await getCurrentProfile();
      final role = profile?['role'];
      if (role == null) return;

      await supabase.from('user_settings').upsert({
        'user_id': user.id,
        'user_role': role,
      });
    } catch (e) {
      debugPrint('Sync role error: $e');
    }
  }

  // ── Create user settings after email confirm ──────────
  // Call this after the user confirms their email
  // and logs in for the first time
  static Future<void> initSettingsAfterLogin() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    try {
      // Check if settings already exist
      final existing = await supabase
          .from('user_settings')
          .select('user_id')
          .eq('user_id', user.id)
          .maybeSingle();

      if (existing != null) return;

      // Get role from profile
      final profile = await getCurrentProfile();
      final role = profile?['role'] ?? 'customer';

      await supabase.from('user_settings').insert({
        'user_id': user.id,
        'user_role': role,
        'job_radius_km': 10,
        'notify_new_jobs': true,
        'notify_application_updates': true,
        'notify_messages': true,
        'notify_promotions': false,
        'show_tips': true,
      });
    } catch (e) {
      debugPrint('Init settings error: $e');
    }
  }
}