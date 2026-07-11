import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

class PaymentService {
  // static const String _baseUrl = 'http://10.0.2.2:3000';
  static const String _baseUrl = 'http://localhost:3000';
  // static const String _baseUrl = 'https://your-backend.com';

  static String? get _token =>
      Supabase.instance.client.auth.currentSession
          ?.accessToken;

  static Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_token != null)
          'Authorization': 'Bearer $_token',
      };

  // ─────────────────────────────────────────────────────
  // ── ACCEPTANCE FEE
  // Customer pays to accept a worker (GHC 3/4/5)
  // ─────────────────────────────────────────────────────

  // Fee per medal tier
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

  // Initialize acceptance fee via backend
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

    // Save pending record
    await supabase.from('acceptance_fees').upsert({
      'application_id': applicationId,
      'job_id': jobId,
      'customer_id':
          supabase.auth.currentUser!.id,
      'worker_id': workerId,
      'worker_medal': workerMedal,
      'amount': amount,
      'currency': 'GHS',
      'paystack_reference': reference,
      'status': 'pending',
    });

    // Initialize via backend
    final response = await http.post(
      Uri.parse(
          '$_baseUrl/payments/acceptance/initialize'),
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
          data['message'] ??
              'Failed to initialize fee payment');
    }

    return {
      'authorization_url':
          data['authorization_url'],
      'reference': reference,
      'amount': amount,
    };
  }

  // Verify acceptance fee + accept application
  static Future<bool>
      verifyAndConfirmAcceptanceFee({
    required String reference,
    required String applicationId,
    required String jobId,
    required String workerId,
  }) async {
    final response = await http.post(
      Uri.parse(
          '$_baseUrl/payments/acceptance/verify'),
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
            'paystack_transaction_id':
                transactionId,
            'paid_at':
                DateTime.now().toIso8601String(),
          })
          .eq('paystack_reference', reference);

      // Accept the application
      await supabase
          .from('job_applications')
          .update({'status': 'accepted'})
          .eq('application_id', applicationId);

      // Decline all other applications
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
      await supabase
          .from('conversations')
          .insert({
        'job_id': jobId,
        'customer_id':
            supabase.auth.currentUser!.id,
        'worker_id': workerId,
      });
    } else {
      await supabase
          .from('acceptance_fees')
          .update({'status': 'failed'})
          .eq('paystack_reference', reference);
    }

    return success;
  }

  // Check if acceptance fee already paid
  static Future<bool> isAcceptanceFeePaid(
      String applicationId) async {
    final data = await supabase
        .from('acceptance_fees')
        .select('status')
        .eq('application_id', applicationId)
        .eq('customer_id',
            supabase.auth.currentUser!.id)
        .maybeSingle();
    return data?['status'] == 'paid';
  }

  // ─────────────────────────────────────────────────────
  // ── APPLICATION FEE
  // Worker pays GHC 5 to apply for a job
  // ─────────────────────────────────────────────────────

  static const double applicationFeeAmount = 5.0;

  // Initialize application fee via backend
  static Future<Map<String, dynamic>>
      initializeApplicationFee({
    required String jobId,
    required String workerEmail,
  }) async {
    final reference =
        'APPLY_${DateTime.now().millisecondsSinceEpoch}';

    // Save pending record
    await supabase
        .from('application_fees')
        .insert({
      'job_id': jobId,
      'worker_id': supabase.auth.currentUser!.id,
      'amount': applicationFeeAmount,
      'currency': 'GHS',
      'paystack_reference': reference,
      'status': 'pending',
    });

    // Initialize via backend
    final response = await http.post(
      Uri.parse(
          '$_baseUrl/payments/application/initialize'),
      headers: _headers,
      body: jsonEncode({
        'email': workerEmail,
        'amount': applicationFeeAmount,
        'reference': reference,
        'currency': 'GHS',
        'channels': ['mobile_money'],
        'metadata': {
          'job_id': jobId,
          'worker_id':
              supabase.auth.currentUser!.id,
          'fee_type': 'application_fee',
        },
      }),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode != 200 &&
        response.statusCode != 201) {
      throw Exception(
          data['message'] ??
              'Failed to initialize payment');
    }

    return {
      'authorization_url':
          data['authorization_url'],
      'reference': reference,
      'amount': applicationFeeAmount,
    };
  }

  // Verify application fee + submit application
  static Future<bool>
      verifyAndSubmitApplication({
    required String reference,
    required String jobId,
  }) async {
    final response = await http.post(
      Uri.parse(
          '$_baseUrl/payments/application/verify'),
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
          .from('application_fees')
          .update({
            'status': 'paid',
            'paystack_transaction_id':
                transactionId,
            'paid_at':
                DateTime.now().toIso8601String(),
          })
          .eq('paystack_reference', reference);

      // Now submit the actual application
      await supabase
          .from('job_applications')
          .insert({
        'job_id': jobId,
        'worker_id':
            supabase.auth.currentUser!.id,
        'status': 'pending',
      });

      // Update application_fees with application_id
      final application = await supabase
          .from('job_applications')
          .select('id')
          .eq('job_id', jobId)
          .eq('worker_id',
              supabase.auth.currentUser!.id)
          .maybeSingle();

      if (application != null) {
        await supabase
            .from('application_fees')
            .update({
              'application_id': application['id'],
            })
            .eq('paystack_reference', reference);
      }
    } else {
      // Mark fee as failed and clean up
      await supabase
          .from('application_fees')
          .update({'status': 'failed'})
          .eq('paystack_reference', reference);
    }

    return success;
  }

  // Check if worker already paid to apply
  static Future<bool> hasAlreadyApplied(
      String jobId) async {
    final data = await supabase
        .from('job_applications')
        .select('id')
        .eq('job_id', jobId)
        .eq('worker_id',
            supabase.auth.currentUser!.id)
        .maybeSingle();
    return data != null;
  }

  // Check if application fee already paid
  static Future<bool> isApplicationFeePaid(
      String jobId) async {
    final data = await supabase
        .from('application_fees')
        .select('status')
        .eq('job_id', jobId)
        .eq('worker_id',
            supabase.auth.currentUser!.id)
        .eq('status', 'paid')
        .maybeSingle();
    return data != null;
  }

  // Get application fee history for worker
  static Future<List<Map<String, dynamic>>>
      getApplicationFeeHistory() async {
    final user = supabase.auth.currentUser;
    if (user == null) return [];

    final data = await supabase
        .from('application_fees')
        .select('*, jobs(title, skill_needed)')
        .eq('worker_id', user.id)
        .eq('status', 'paid')
        .order('paid_at', ascending: false);

    return List<Map<String, dynamic>>.from(data);
  }

  // Get acceptance fee history for customer
  static Future<List<Map<String, dynamic>>>
      getAcceptanceFeeHistory() async {
    final user = supabase.auth.currentUser;
    if (user == null) return [];

    final data = await supabase
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

  static void _checkStatus(http.Response res) {
    if (res.statusCode != 200 &&
        res.statusCode != 201) {
      final body = jsonDecode(res.body);
      throw Exception(
          body['message'] ?? 'Request failed');
    }
  }
}