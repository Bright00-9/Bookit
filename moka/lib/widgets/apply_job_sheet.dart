import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/payment_service.dart';
import '../widgets/paystack_web_view.dart';

class ApplyJobSheet extends StatefulWidget {
  final String jobId;
  final String jobTitle;
  final String customerName;
  final VoidCallback onApplied;

  const ApplyJobSheet({
    super.key,
    required this.jobId,
    required this.jobTitle,
    required this.customerName,
    required this.onApplied,
  });

  // Easy launcher
  static Future<void> show(
    BuildContext context, {
    required String jobId,
    required String jobTitle,
    required String customerName,
    required VoidCallback onApplied,
  }) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      backgroundColor: const Color(0xFF0D0D0D),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
            top: Radius.circular(24)),
      ),
      builder: (_) => ApplyJobSheet(
        jobId: jobId,
        jobTitle: jobTitle,
        customerName: customerName,
        onApplied: onApplied,
      ),
    );
  }

  @override
  State<ApplyJobSheet> createState() =>
      _ApplyJobSheetState();
}

class _ApplyJobSheetState
    extends State<ApplyJobSheet> {
  bool _isProcessing = false;
  bool _alreadyApplied = false;
  bool _isChecking = true;

  @override
  void initState() {
    super.initState();
    _checkAlreadyApplied();
  }

  Future<void> _checkAlreadyApplied() async {
    try {
      final applied =
          await PaymentService.hasAlreadyApplied(
              widget.jobId);
      if (mounted) {
        setState(() {
          _alreadyApplied = applied;
          _isChecking = false;
        });
      }
    } catch (_) {
      if (mounted)
        setState(() => _isChecking = false);
    }
  }

  Future<void> _handlePayAndApply() async {
    setState(() => _isProcessing = true);

    try {
      final user =
          Supabase.instance.client.auth.currentUser;
      if (user == null)
        throw Exception('Not logged in');

      // Initialize payment
      final result = await PaymentService
          .initializeApplicationFee(
        jobId: widget.jobId,
        workerEmail: user.email!,
      );

      final authUrl = result['authorization_url'];
      final reference = result['reference'];

      setState(() => _isProcessing = false);

      if (!mounted) return;

      // Open Paystack WebView
      final paid = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => PaystackWebView(
            authorizationUrl: authUrl,
            reference: reference,
            onSuccess: () =>
                Navigator.pop(context, true),
            onCancel: () =>
                Navigator.pop(context, false),
          ),
        ),
      );

      if (paid != true) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(
            const SnackBar(
                content: Text('Payment cancelled.')),
          );
        }
        return;
      }

      // Verify + submit application
      setState(() => _isProcessing = true);

      final success = await PaymentService
          .verifyAndSubmitApplication(
        reference: reference,
        jobId: widget.jobId,
      );

      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(
            const SnackBar(
              content: Text(
                  '✅ Applied successfully!'),
              backgroundColor:
                  Color(0xFF4CAF50),
            ),
          );
          Navigator.pop(context);
          widget.onApplied();
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(
            const SnackBar(
              content: Text(
                  'Payment could not be verified. Try again.'),
              backgroundColor:
                  Color(0xFFE53935),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(
          SnackBar(
              content: Text('Error: $e'),
              backgroundColor:
                  const Color(0xFFE53935)),
        );
      }
    } finally {
      if (mounted)
        setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom:
            MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        child: _isChecking
            ? const Center(
                child: CircularProgressIndicator(
                    color: Color(0xFFFF6B00)))
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(
                            0xFF2A2A2A),
                        borderRadius:
                            BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Icon
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF6B00)
                          .withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                        Icons.work_outline,
                        color: Color(0xFFFF6B00),
                        size: 30),
                  ),
                  const SizedBox(height: 16),

                  // Title
                  const Text(
                    'Apply for Job',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Job info
                  Text(
                    widget.jobTitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF888888),
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    'Posted by ${widget.customerName}',
                    style: const TextStyle(
                      color: Color(0xFF555555),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Fee breakdown card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1A1A),
                      borderRadius:
                          BorderRadius.circular(14),
                      border: Border.all(
                          color:
                              const Color(0xFF2A2A2A)),
                    ),
                    child: Column(
                      children: [
                        const Row(
                          mainAxisAlignment:
                              MainAxisAlignment
                                  .spaceBetween,
                          children: [
                            Text('What is this fee?',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight:
                                        FontWeight.w700,
                                    fontSize: 13)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'A small platform fee is charged when you apply for a job. This keeps the platform running and ensures serious applications only.',
                          style: TextStyle(
                              color:
                                  Color(0xFF888888),
                              fontSize: 12,
                              height: 1.5),
                        ),
                        const Divider(
                            height: 20,
                            color: Color(0xFF2A2A2A)),
                        Row(
                          mainAxisAlignment:
                              MainAxisAlignment
                                  .spaceBetween,
                          children: [
                            const Text(
                                'Application Fee',
                                style: TextStyle(
                                    color: Color(
                                        0xFF888888),
                                    fontSize: 13)),
                            Text(
                              'GHC ${PaymentService.applicationFeeAmount.toStringAsFixed(2)}',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight:
                                      FontWeight.w600,
                                  fontSize: 13),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment:
                              MainAxisAlignment
                                  .spaceBetween,
                          children: [
                            const Text('You pay',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight:
                                        FontWeight.w700,
                                    fontSize: 15)),
                            Text(
                              'GHC ${PaymentService.applicationFeeAmount.toStringAsFixed(2)}',
                              style: const TextStyle(
                                color:
                                    Color(0xFFFF6B00),
                                fontWeight:
                                    FontWeight.w800,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Already applied state
                  if (_alreadyApplied) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4CAF50)
                            .withOpacity(0.1),
                        borderRadius:
                            BorderRadius.circular(12),
                        border: Border.all(
                            color: const Color(
                                    0xFF4CAF50)
                                .withOpacity(0.4)),
                      ),
                      child: const Row(
                        mainAxisAlignment:
                            MainAxisAlignment.center,
                        children: [
                          Icon(
                              Icons
                                  .check_circle_outline,
                              color:
                                  Color(0xFF4CAF50),
                              size: 18),
                          SizedBox(width: 8),
                          Text(
                              'You have already applied',
                              style: TextStyle(
                                  color: Color(
                                      0xFF4CAF50),
                                  fontWeight:
                                      FontWeight.w600)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () =>
                          Navigator.pop(context),
                      child: const Text('Close',
                          style: TextStyle(
                              color:
                                  Color(0xFF888888))),
                    ),
                  ] else ...[
                    // Pay & Apply button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isProcessing
                            ? null
                            : _handlePayAndApply,
                        style:
                            ElevatedButton.styleFrom(
                          backgroundColor:
                              const Color(0xFFFF6B00),
                          foregroundColor:
                              Colors.white,
                          padding:
                              const EdgeInsets.symmetric(
                                  vertical: 16),
                          shape:
                              RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius
                                          .circular(
                                              14)),
                          elevation: 0,
                        ),
                        child: _isProcessing
                            ? const Row(
                                mainAxisAlignment:
                                    MainAxisAlignment
                                        .center,
                                children: [
                                  SizedBox(
                                    width: 20,
                                    height: 20,
                                    child:
                                        CircularProgressIndicator(
                                            strokeWidth:
                                                2,
                                            color: Colors
                                                .white),
                                  ),
                                  SizedBox(width: 10),
                                  Text('Processing...',
                                      style: TextStyle(
                                          fontWeight:
                                              FontWeight
                                                  .w700)),
                                ],
                              )
                            : Text(
                                'Pay GHC ${PaymentService.applicationFeeAmount.toStringAsFixed(0)} & Apply',
                                style: const TextStyle(
                                    fontWeight:
                                        FontWeight.w700,
                                    fontSize: 15),
                              ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: _isProcessing
                          ? null
                          : () =>
                              Navigator.pop(context),
                      child: const Text('Cancel',
                          style: TextStyle(
                              color:
                                  Color(0xFF888888))),
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}