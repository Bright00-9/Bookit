import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

class PaymentService {
  //static const String _backendUrl = 'http://10.0.2.2:3000'; // Android emulator
  static const String _backendUrl = 'http://localhost:3000'; // iOS simulator
  // static const String _backendUrl = 'https://your-backend.com'; // Production

  // Get JWT token from Supabase session for backend auth
  static String? get _token =>
      Supabase.instance.client.auth.currentSession?.accessToken;

  static Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  // Initialize payment via backend
  static Future<Map<String, dynamic>> initializePayment({
    required String jobId,
    required String workerId,
    required double amount,
    required String customerEmail,
  }) async {
    final response = await http.post(
      Uri.parse('$_backendUrl/payments/initialize'),
      headers: _headers,
      body: jsonEncode({
        'jobId': jobId,
        'workerId': workerId,
        'amount': amount,
        'customerEmail': customerEmail,
      }),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception(data['message'] ?? 'Failed to initialize payment');
    }

    return data;
  }

  // Verify payment via backend
  static Future<bool> verifyPayment(String reference) async {
    final response = await http.post(
      Uri.parse('$_backendUrl/payments/verify'),
      headers: _headers,
      body: jsonEncode({'reference': reference}),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception(data['message'] ?? 'Failed to verify payment');
    }

    return data['success'] == true;
  }

  // Get payment for a job (directly from Supabase — safe to read)
  static Future<Map<String, dynamic>?> getJobPayment(String jobId) async {
    final data = await supabase
        .from('payments')
        .select()
        .eq('job_id', jobId)
        .maybeSingle();
    return data;
  }

  // Get all payments for current user
  static Future<List<Map<String, dynamic>>> getMyPayments() async {
    final user = supabase.auth.currentUser;
    if (user == null) return [];

    final data = await supabase
        .from('payments')
        .select('*, jobs(title, skill_needed)')
        .or('customer_id.eq.${user.id},worker_id.eq.${user.id}')
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(data);
  }
}
