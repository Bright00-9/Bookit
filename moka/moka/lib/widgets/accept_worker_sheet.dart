import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/worker_medal.dart';
import 'worker_medal_badge.dart';
import '../services/acceptance_fee_service.dart';
import '../services/paystack_service.dart';

class AcceptWorkerSheet extends StatefulWidget {
  final String applicationId;
  final String jobId;
  final String workerId;
  final String workerName;
  final String? workerAvatarUrl;
  final double workerRating;
  final VoidCallback onAccepted;

  const AcceptWorkerSheet({
    super.key,
    required this.applicationId,
    required this.jobId,
    required this.workerId,
    required this.workerName,
    this.workerAvatarUrl,
    required this.workerRating,
    required this.onAccepted,
  });

  // ── Easy launcher ────────────────────────────────────────────
  static Future<void> show(
    BuildContext context, {
    required String applicationId,
    required String jobId,
    required String workerId,
    required String workerName,
    String? workerAvatarUrl,
    required double workerRating,
    required VoidCallback onAccepted,
  }) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => AcceptWorkerSheet(
        applicationId: applicationId,
        jobId: jobId,
        workerId: workerId,
        workerName: workerName,
        workerAvatarUrl: workerAvatarUrl,
        workerRating: workerRating,
        onAccepted: onAccepted,
      ),
    );
  }

  @override
  State<AcceptWorkerSheet> createState() => _AcceptWorkerSheetState();
}

class _AcceptWorkerSheetState extends State<AcceptWorkerSheet> {
  final _feeService = AcceptanceFeeService();
  final _supabase = Supabase.instance.client;

  bool _isProcessing = false;
  bool _feePaid = false;

  late WorkerMedal _medal;
  late double _fee;

  @override
  void initState() {
    super.initState();
    _medal = getMedal(widget.workerRating);
    _fee = AcceptanceFeeService.getFeeForMedal(_medal);
    _checkExistingFee();
  }

  Future<void> _checkExistingFee() async {
    final paid = await _feeService.isFeePaid(widget.applicationId);
    if (mounted) setState(() => _feePaid = paid);
  }

  Future<void> _handlePayAndAccept() async {
    setState(() => _isProcessing = true);

    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('Not logged in');

      final result = await PaymentService.initializeAcceptanceFee(
        applicationId: widget.applicationId,
        jobId: widget.jobId,
        workerId: widget.workerId,
        workerMedal: _medal.name,
      );

      final reference = result['reference'] as String;

      setState(() => _isProcessing = false);

      if (!mounted) return;

      final paid = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => PaystackWebView(
            authorizationUrl: result['authorization_url'] as String,
            reference: reference,
            onSuccess: () => Navigator.pop(context, true),
            onCancel: () => Navigator.pop(context, false),
          ),
        ),
      );

      if (paid != true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Payment cancelled.')),
          );
        }
        return;
      }

      setState(() => _isProcessing = true);
      final success = await PaymentService.verifyAndConfirmAcceptanceFee(
        reference: reference,
      );

      if (success) {
        setState(() => _feePaid = true);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Payment successful. Worker accepted.')),
          );
          Navigator.pop(context);
          widget.onAccepted();
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Payment could not be verified. Try again.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [

            // ── Handle ──
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // ── Title ──
            const Text(
              'Accept Worker',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),

            // ── Worker info card ──
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _medal.backgroundColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: _medal.accentColor.withOpacity(0.4)),
              ),
              child: Row(
                children: [
                  // Avatar
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: _medal.accentColor, width: 2),
                        ),
                        child: ClipOval(
                          child: widget.workerAvatarUrl != null
                              ? Image.network(widget.workerAvatarUrl!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      _defaultAvatar())
                              : _defaultAvatar(),
                        ),
                      ),
                      Positioned(
                        bottom: -4,
                        right: -4,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: _medal.accentColor, width: 1),
                          ),
                          child: Text(_medal.emoji,
                              style: const TextStyle(fontSize: 12)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 14),

                  // Name + rating
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.workerName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.star_rounded,
                                size: 15,
                                color: _medal.starColor),
                            const SizedBox(width: 3),
                            Text(
                              widget.workerRating.toStringAsFixed(1),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: _medal.accentColor,
                              ),
                            ),
                            const SizedBox(width: 8),
                            WorkerMedalBadge(
                                medal: _medal, showLabel: true),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── Fee breakdown ──
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('What is this fee?',
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'A small platform fee is charged when you accept a worker. The fee varies based on the worker\'s medal tier.',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  const Divider(height: 20),
                  _feeRow('Bronze Worker Fee', 'GHC 3.00',
                      highlight: _medal == WorkerMedal.bronze),
                  const SizedBox(height: 6),
                  _feeRow('Silver Worker Fee', 'GHC 4.00',
                      highlight: _medal == WorkerMedal.silver),
                  const SizedBox(height: 6),
                  _feeRow('Gold Worker Fee', 'GHC 5.00',
                      highlight: _medal == WorkerMedal.gold),
                  const Divider(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('You pay today',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      Text(
                        'GHC ${_fee.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: _medal.accentColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── Pay & Accept button ──
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isProcessing || _feePaid
                    ? null
                    : _handlePayAndAccept,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: _medal.accentColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isProcessing
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white),
                          ),
                          SizedBox(width: 12),
                          Text('Processing...'),
                        ],
                      )
                    : _feePaid
                        ? const Text('Already paid and accepted')
                        : Text(
                            'Pay GHC ${_fee.toStringAsFixed(2)} & Accept',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15),
                          ),
              ),
            ),
            const SizedBox(height: 12),

            // ── Cancel ──
            TextButton(
              onPressed: _isProcessing
                  ? null
                  : () => Navigator.pop(context),
              child: const Text('Cancel',
                  style: TextStyle(color: Colors.grey)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _feeRow(String label, String amount,
      {bool highlight = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: highlight ? Colors.black87 : Colors.grey,
            fontWeight:
                highlight ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        Text(
          amount,
          style: TextStyle(
            fontSize: 13,
            color: highlight ? _medal.accentColor : Colors.grey,
            fontWeight:
                highlight ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Widget _defaultAvatar() => Container(
        color: Colors.grey.shade200,
        child: const Icon(Icons.person, color: Colors.grey, size: 28),
      );
}