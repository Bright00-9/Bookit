import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/worker_medal.dart';

class AcceptanceFeeService {
  final _supabase = Supabase.instance.client;

  String get _userId => _supabase.auth.currentUser!.id;

  // ── Fee amount per medal ──────────────────────────────────────
  static double getFeeForMedal(WorkerMedal medal) {
    switch (medal) {
      case WorkerMedal.bronze:
        return 3.0;
      case WorkerMedal.silver:
        return 4.0;
      case WorkerMedal.gold:
        return 5.0;
    }
  }

  // ── Check if fee already paid for this application ────────────
  Future<bool> isFeePaid(String applicationId) async {
    final data = await _supabase
        .from('acceptance_fees')
        .select('status')
        .eq('application_id', applicationId)
        .eq('customer_id', _userId)
        .maybeSingle();

    return data?['status'] == 'paid';
  }

  // ── Create a pending fee record ───────────────────────────────
  Future<String> createFeeRecord({
    required String applicationId,
    required String jobId,
    required String workerId,
    required WorkerMedal medal,
    required String paystackReference,
  }) async {
    final amount = getFeeForMedal(medal);

    final data = await _supabase
        .from('acceptance_fees')
        .insert({
          'application_id': applicationId,
          'job_id': jobId,
          'customer_id': _userId,
          'worker_id': workerId,
          'worker_medal': medal.name,
          'amount': amount,
          'currency': 'GHS',
          'paystack_reference': paystackReference,
          'status': 'pending',
        })
        .select('id')
        .single();

    return data['id'];
  }

  // ── Mark fee as paid and accept the application ───────────────
  Future<void> confirmPaymentAndAccept({
    required String applicationId,
    required String paystackReference,
    required String paystackTransactionId,
  }) async {
    // Update fee record to paid
    await _supabase
        .from('acceptance_fees')
        .update({
          'status': 'paid',
          'paystack_transaction_id': paystackTransactionId,
          'paid_at': DateTime.now().toIso8601String(),
        })
        .eq('application_id', applicationId)
        .eq('paystack_reference', paystackReference);

    // Accept the application
    await _supabase
        .from('applications')
        .update({'status': 'accepted'})
        .eq('application_id', applicationId);
  }

  // ── Mark fee as failed ────────────────────────────────────────
  Future<void> markFeeFailed({
    required String applicationId,
    required String paystackReference,
  }) async {
    await _supabase
        .from('acceptance_fees')
        .update({'status': 'failed'})
        .eq('application_id', applicationId)
        .eq('paystack_reference', paystackReference);
  }
}