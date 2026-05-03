import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

class PaymentService {
  // 🔁 Replace with your Paystack secret key
  static const String _paystackSecretKey = 'sk_test_YOUR_PAYSTACK_SECRET_KEY';
  static const String _paystackBaseUrl = 'https://api.paystack.co';

  // Initialize a Paystack transaction
  static Future<Map<String, dynamic>> initializePayment({
    required String jobId,
    required String workerId,
    required double amount,
    required String customerEmail,
  }) async {
    final user = supabase.auth.currentUser;
    if (user == null) throw Exception('Not logged in');

    // Generate unique reference
    final reference =
        'moka_${jobId.replaceAll('-', '').substring(0, 8)}_${DateTime.now().millisecondsSinceEpoch}';

    // Create payment record in Supabase
    await supabase.from('payments').insert({
      'job_id': jobId,
      'customer_id': user.id,
      'worker_id': workerId,
      'amount': amount,
      'status': 'pending',
      'paystack_reference': reference,
    });

    // Initialize with Paystack API
    final response = await http.post(
      Uri.parse('$_paystackBaseUrl/transaction/initialize'),
      headers: {
        'Authorization': 'Bearer $_paystackSecretKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'email': customerEmail,
        'amount': (amount * 100).toInt(), // Paystack uses kobo/pesewas
        'currency': 'GHS',
        'reference': reference,
        'metadata': {
          'job_id': jobId,
          'worker_id': workerId,
          'custom_fields': [
            {
              'display_name': 'Job ID',
              'variable_name': 'job_id',
              'value': jobId,
            }
          ],
        },
        'channels': ['card', 'mobile_money'],
      }),
    );

    final data = jsonDecode(response.body);
    if (!data['status']) {
      throw Exception(data['message'] ?? 'Failed to initialize payment');
    }

    return {
      'authorization_url': data['data']['authorization_url'],
      'reference': reference,
      'access_code': data['data']['access_code'],
    };
  }

  // Verify payment after redirect
  static Future<bool> verifyPayment(String reference) async {
    final response = await http.get(
      Uri.parse('$_paystackBaseUrl/transaction/verify/$reference'),
      headers: {
        'Authorization': 'Bearer $_paystackSecretKey',
      },
    );

    final data = jsonDecode(response.body);
    if (!data['status']) return false;

    final transactionData = data['data'];
    final isSuccess = transactionData['status'] == 'success';

    if (isSuccess) {
      // Update payment record in Supabase
      await supabase.from('payments').update({
        'status': 'success',
        'paystack_transaction_id':
            transactionData['id'].toString(),
        'payment_method': transactionData['channel'],
        'paid_at': DateTime.now().toIso8601String(),
      }).eq('paystack_reference', reference);
    } else {
      await supabase.from('payments').update({
        'status': 'failed',
      }).eq('paystack_reference', reference);
    }

    return isSuccess;
  }

  // Get payment for a job
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
