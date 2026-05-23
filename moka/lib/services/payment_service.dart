import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

class PaymentService {
  // ── Backend URL ───────────────────────────────────────────
  // Uncomment the one that matches your environment:
  //static const String _backendUrl = 'http://10.0.2.2:3000'; // Android emulator
  static const String _backendUrl = 'http://localhost:3000';  // iOS simulator
  // static const String _backendUrl = 'https://your-backend.com'; // Production

  // ── Paystack keys ─────────────────────────────────────────
  // Keep secret key server-side in production.
  // For now it's called via your NestJS backend.
  static const String _paystackPublicKey =
      'pk_test_your_key_here'; // replace with your key

  static String? get _token =>
      Supabase.instance.client.auth.currentSession?.accessToken;

  static Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  // ─────────────────────────────────────────────────────────
  // ── JOB PAYMENT (existing — worker pays for completed job)
  // ─────────────────────────────────────────────────────────

  // Initialize job payment via NestJS backend
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

    if (response.statusCode != 200 &&
        response.statusCode != 201) {
      throw Exception(
          data['message'] ?? 'Failed to initialize payment');
    }

    return data;
  }

  // Verify job payment via NestJS backend
  static Future<bool> verifyPayment(String reference) async {
    final response = await http.post(
      Uri.parse('$_backendUrl/payments/verify'),
      headers: _headers,
      body: jsonEncode({'reference': reference}),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode != 200 &&
        response.statusCode != 201) {
      throw Exception(
          data['message'] ?? 'Failed to verify payment');
    }

    return data['success'] == true;
  }

  // Get payment for a job
  static Future<Map<String, dynamic>?> getJobPayment(
      String jobId) async {
    final data = await supabase
        .from('payments')
        .select()
        .eq('job_id', jobId)
        .maybeSingle();
    return data;
  }

  // Get all payments for current user
  static Future<List<Map<String, dynamic>>>
      getMyPayments() async {
    final user = supabase.auth.currentUser;
    if (user == null) return [];

    final data = await supabase
        .from('payments')
        .select('*, jobs(title, skill_needed)')
        .or('customer_id.eq.${user.id},worker_id.eq.${user.id}')
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(data);
  }

  // ─────────────────────────────────────────────────────────
  // ── ACCEPTANCE FEE (new — customer pays to accept worker)
  // ─────────────────────────────────────────────────────────

  // Fee amounts per medal tier
  static double getAcceptanceFee(String medal) {
    switch (medal) {
      case 'gold':
        return 5.0;
      case 'silver':
        return 4.0;
      case 'bronze':
      default:
        return 3.0;
    }
  }

  // Initialize acceptance fee via Paystack directly
  // (no NestJS needed — calls Paystack API via Edge Function)
  static Future<Map<String, dynamic>>
      initializeAcceptanceFee({
    required String applicationId,
    required String jobId,
    required String workerId,
    required String workerMedal,
    required String customerEmail,
  }) async {
    final amount = getAcceptanceFee(workerMedal);
    final reference =
        'ACCEPT_${DateTime.now().millisecondsSinceEpoch}';

    // Save pending fee record to Supabase
    await supabase.from('acceptance_fees').upsert({
      'application_id': applicationId,
      'job_id': jobId,
      'customer_id': supabase.auth.currentUser!.id,
      'worker_id': workerId,
      'worker_medal': workerMedal,
      'amount': amount,
      'currency': 'GHS',
      'paystack_reference': reference,
      'status': 'pending',
    });

    // Initialize via Paystack through your NestJS backend
    // so the secret key stays server-side
    final response = await http.post(
      Uri.parse('$_backendUrl/payments/acceptance/initialize'),
      headers: _headers,
      body: jsonEncode({
        'email': customerEmail,
        'amount': amount,
        'reference': reference,
        'currency': 'GHS',
        'channels': ['mobile_money'],
        'metadata': {
          'application_id': applicationId,
          'job_id': jobId,
          'worker_id': workerId,
          'medal': workerMedal,
          'fee_type': 'acceptance_fee',
        },
      }),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode != 200 &&
        response.statusCode != 201) {
      throw Exception(
          data['message'] ?? 'Failed to initialize fee payment');
    }

    // Return authorization_url + reference for WebView
    return {
      'authorization_url': data['authorization_url'],
      'reference': reference,
      'amount': amount,
    };
  }

  // Verify acceptance fee + accept application if paid
  static Future<bool> verifyAndConfirmAcceptanceFee({
    required String reference,
    required String applicationId,
    required String jobId,
    required String workerId,
  }) async {
    // Verify with Paystack via backend
    final response = await http.post(
      Uri.parse(
          '$_backendUrl/payments/acceptance/verify'),
      headers: _headers,
      body: jsonEncode({'reference': reference}),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode != 200 &&
        response.statusCode != 201) {
      throw Exception(
          data['message'] ?? 'Verification failed');
    }

    final success = data['success'] == true;

    if (success) {
      final transactionId =
          data['transaction_id']?.toString() ?? '';

      // Mark fee as paid
      await supabase
          .from('acceptance_fees')
          .update({
            'status': 'paid',
            'paystack_transaction_id': transactionId,
            'paid_at': DateTime.now().toIso8601String(),
          })
          .eq('paystack_reference', reference);

      // Accept the application
      await supabase
          .from('job_applications')
          .update({'status': 'accepted'})
          .eq('application_id', applicationId);

      // Decline all other applications for this job
      await supabase
          .from('job_applications')
          .update({'status': 'declined'})
          .eq('job_id', jobId)
          .neq('application_id', applicationId);

      // Update job status
      await supabase.from('jobs').update({
        'status': 'accepted',
        'accepted_worker_id': workerId,
      }).eq('id', jobId);

      // Create conversation
      await supabase.from('conversations').insert({
        'job_id': jobId,
        'customer_id': supabase.auth.currentUser!.id,
        'worker_id': workerId,
      });
    } else {
      // Mark fee as failed
      await supabase
          .from('acceptance_fees')
          .update({'status': 'failed'})
          .eq('paystack_reference', reference);
    }

    return success;
  }

  // Check if acceptance fee already paid for an application
  static Future<bool> isAcceptanceFeePaid(
      String applicationId) async {
    final data = await supabase
        .from('acceptance_fees')
        .select('status')
        .eq('application_id', applicationId)
        .eq('customer_id', supabase.auth.currentUser!.id)
        .maybeSingle();

    return data?['status'] == 'paid';
  }

  // Get acceptance fee history for current customer
  static Future<List<Map<String, dynamic>>>
      getAcceptanceFeeHistory() async {
    final user = supabase.auth.currentUser;
    if (user == null) return [];

    final data = await supabase
        .from('acceptance_fees')
        .select('''
          *,
          jobs(title, skill_needed),
          workers:users!worker_id(name, avatar_url)
        ''')
        .eq('customer_id', user.id)
        .eq('status', 'paid')
        .order('paid_at', ascending: false);

    return List<Map<String, dynamic>>.from(data);
  }
}