import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_config.dart';

class PaymentService {
  static const String _baseUrl = backendBaseUrl;

  static String get _token {
    final token = Supabase.instance.client.auth.currentSession?.accessToken;
    if (token == null || token.isEmpty) {
      throw Exception('Missing Supabase session token. Please sign in again.');
    }
    return token;
  }

  static Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_token',
      };

  static double getAcceptanceFee(String medal) {
    switch (medal.toLowerCase()) {
      case 'gold':
        return 5.0;
      case 'silver':
        return 4.0;
      case 'bronze':
      default:
        return 3.0;
    }
  }

  static Future<Map<String, dynamic>> initializeAcceptanceFee({
    required String applicationId,
    required String jobId,
    required String workerId,
    required String workerMedal,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/payments/acceptance/initialize'),
      headers: _headers,
      body: jsonEncode({
        'applicationId': applicationId,
        'jobId': jobId,
        'workerId': workerId,
        'workerMedal': workerMedal,
      }),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception(data['message'] ?? 'Failed to initialize acceptance fee');
    }

    return {
      'authorization_url': data['authorization_url'],
      'reference': data['reference'],
      'amount': data['amount'],
    };
  }

  static Future<bool> verifyAndConfirmAcceptanceFee({
    required String reference,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/payments/acceptance/verify'),
      headers: _headers,
      body: jsonEncode({'reference': reference}),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception(data['message'] ?? 'Failed to verify acceptance fee');
    }

    return data['success'] == true;
  }

  static Future<bool> isAcceptanceFeePaid(String applicationId) async {
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) return false;

    final data = await Supabase.instance.client
        .from('acceptance_fees')
        .select('status')
        .eq('application_id', applicationId)
        .eq('customer_id', currentUser.id)
        .maybeSingle();
    return data?['status'] == 'paid';
  }

  static const double applicationFeeAmount = 5.0;

  static Future<Map<String, dynamic>> initializeApplicationFee({
    required String jobId,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/payments/application/initialize'),
      headers: _headers,
      body: jsonEncode({'jobId': jobId}),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception(data['message'] ?? 'Failed to initialize application fee');
    }

    return {
      'authorization_url': data['authorization_url'],
      'reference': data['reference'],
      'amount': data['amount'],
    };
  }

  static Future<bool> verifyAndSubmitApplication({
    required String reference,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/payments/application/verify'),
      headers: _headers,
      body: jsonEncode({'reference': reference}),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception(data['message'] ?? 'Failed to verify application fee');
    }

    return data['success'] == true;
  }

  static Future<bool> hasAlreadyApplied(String jobId) async {
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) return false;

    final data = await Supabase.instance.client
        .from('job_applications')
        .select('id')
        .eq('job_id', jobId)
        .eq('worker_id', currentUser.id)
        .maybeSingle();
    return data != null;
  }

  static Future<bool> isApplicationFeePaid(String jobId) async {
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) return false;

    final data = await Supabase.instance.client
        .from('application_fees')
        .select('status')
        .eq('job_id', jobId)
        .eq('worker_id', currentUser.id)
        .eq('status', 'paid')
        .maybeSingle();
    return data != null;
  }

  static Future<List<Map<String, dynamic>>> getApplicationFeeHistory() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return [];

    final data = await Supabase.instance.client
        .from('application_fees')
        .select('*, jobs(title, skill_needed)')
        .eq('worker_id', user.id)
        .eq('status', 'paid')
        .order('paid_at', ascending: false);

    return List<Map<String, dynamic>>.from(data);
  }

  static Future<List<Map<String, dynamic>>> getAcceptanceFeeHistory() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return [];

    final data = await Supabase.instance.client
        .from('acceptance_fees')
        .select('''
          *,
          jobs(title, skill_needed),
          workers:profiles!worker_id(name, avatar_url)
        ''')
        .eq('customer_id', user.id)
        .eq('status', 'paid')
        .order('paid_at', ascending: false);

    return List<Map<String, dynamic>>.from(data);
  }
}

