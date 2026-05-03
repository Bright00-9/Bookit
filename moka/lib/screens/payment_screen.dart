import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/payment_service.dart';
import '../services/auth_service.dart';

class PaymentScreen extends StatefulWidget {
  final String jobId;
  final String workerId;
  final String workerName;
  final String jobTitle;
  final double amount;

  const PaymentScreen({
    super.key,
    required this.jobId,
    required this.workerId,
    required this.workerName,
    required this.jobTitle,
    required this.amount,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  bool _isLoading = false;
  bool _isVerifying = false;
  String? _reference;
  String _paymentStatus = 'pending'; // pending, success, failed
  Map<String, dynamic>? _existingPayment;
  bool _isCheckingExisting = true;

  // Paystack fee: 1.5% + GHS 0.10 for local, capped at GHS 2,000
  double get _paystackFee {
    final fee = widget.amount * 0.015 + 0.10;
    return fee > 2000 ? 2000 : fee;
  }

  double get _totalAmount => widget.amount + _paystackFee;

  @override
  void initState() {
    super.initState();
    _checkExistingPayment();
  }

  Future<void> _checkExistingPayment() async {
    setState(() => _isCheckingExisting = true);
    try {
      final payment = await PaymentService.getJobPayment(widget.jobId);
      if (mounted) {
        setState(() {
          _existingPayment = payment;
          if (payment != null) {
            _paymentStatus = payment['status'] ?? 'pending';
            _reference = payment['paystack_reference'];
          }
        });
      }
    } catch (e) {
      debugPrint('Error checking payment: $e');
    } finally {
      if (mounted) setState(() => _isCheckingExisting = false);
    }
  }

  Future<void> _initiatePayment() async {
    setState(() => _isLoading = true);
    try {
      final profile = await AuthService.getCurrentProfile();
      final email = AuthService.currentEmail ?? '';

      final result = await PaymentService.initializePayment(
        jobId: widget.jobId,
        workerId: widget.workerId,
        amount: widget.amount,
        customerEmail: email,
      );

      _reference = result['reference'];
      final authUrl = result['authorization_url'];

      // Open Paystack payment page
      final uri = Uri.parse(authUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        // After returning from browser, verify payment
        if (mounted) _showVerifyDialog();
      } else {
        throw Exception('Could not open payment page');
      }
    } catch (e) {
      if (!mounted) return;
      _showError(e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _verifyPayment() async {
    if (_reference == null) return;
    setState(() => _isVerifying = true);
    try {
      final success = await PaymentService.verifyPayment(_reference!);
      if (mounted) {
        setState(() => _paymentStatus = success ? 'success' : 'failed');
        if (success) {
          _showSuccessDialog();
        } else {
          _showError('Payment not completed. Please try again.');
        }
      }
    } catch (e) {
      if (!mounted) return;
      _showError('Could not verify payment. Please try again.');
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  void _showVerifyDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Confirm Payment',
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.w700)),
        content: const Text(
          'Have you completed the payment on Paystack?',
          style: TextStyle(color: Color(0xFF888888)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Not yet',
                style: TextStyle(color: Color(0xFF888888))),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _verifyPayment();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF6B00),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Yes, verify'),
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: const Color(0xFF4CAF50).withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded,
                  color: Color(0xFF4CAF50), size: 36),
            ),
            const SizedBox(height: 16),
            const Text('Payment Successful!',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(
              'GHS ${widget.amount.toStringAsFixed(2)} sent to ${widget.workerName}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Color(0xFF888888), fontSize: 14),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4CAF50),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: const Text('Done',
                    style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFE53935),
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D0D),
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_new,
              color: Colors.white, size: 20),
        ),
        title: const Text('Pay Worker',
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 18)),
      ),
      body: _isCheckingExisting
          ? const Center(
              child:
                  CircularProgressIndicator(color: Color(0xFFFF6B00)))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status banner if already paid
                  if (_paymentStatus == 'success') _buildSuccessBanner(),
                  if (_paymentStatus == 'failed') _buildFailedBanner(),

                  // Worker card
                  _buildWorkerCard(),
                  const SizedBox(height: 20),

                  // Amount breakdown
                  _buildAmountCard(),
                  const SizedBox(height: 20),

                  // Payment methods info
                  _buildPaymentMethodsCard(),
                  const SizedBox(height: 32),

                  // Pay button
                  if (_paymentStatus != 'success') _buildPayButton(),

                  // Verify button if pending
                  if (_paymentStatus == 'pending' &&
                      _existingPayment != null) ...[
                    const SizedBox(height: 12),
                    _buildVerifyButton(),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildSuccessBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF4CAF50).withOpacity(0.15),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: const Color(0xFF4CAF50).withOpacity(0.4)),
      ),
      child: const Row(
        children: [
          Icon(Icons.check_circle, color: Color(0xFF4CAF50), size: 20),
          SizedBox(width: 10),
          Text('Payment completed successfully!',
              style: TextStyle(
                  color: Color(0xFF4CAF50), fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildFailedBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFE53935).withOpacity(0.15),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: const Color(0xFFE53935).withOpacity(0.4)),
      ),
      child: const Row(
        children: [
          Icon(Icons.error_outline, color: Color(0xFFE53935), size: 20),
          SizedBox(width: 10),
          Text('Payment failed. Please try again.',
              style: TextStyle(
                  color: Color(0xFFE53935), fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildWorkerCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: const Color(0xFFFF6B00).withOpacity(0.15),
            child: Text(
              widget.workerName[0].toUpperCase(),
              style: const TextStyle(
                  color: Color(0xFFFF6B00),
                  fontSize: 20,
                  fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.workerName,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(widget.jobTitle,
                    style: const TextStyle(
                        color: Color(0xFF888888), fontSize: 13),
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'GHS ${widget.amount.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: Color(0xFFFF6B00),
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Text('Job amount',
                  style:
                      TextStyle(color: Color(0xFF888888), fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAmountCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Payment Breakdown',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 15)),
          const SizedBox(height: 14),
          _buildAmountRow('Job Amount',
              'GHS ${widget.amount.toStringAsFixed(2)}', false),
          const SizedBox(height: 8),
          _buildAmountRow('Paystack Fee (1.5% + 0.10)',
              'GHS ${_paystackFee.toStringAsFixed(2)}', false),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Divider(color: Color(0xFF2A2A2A)),
          ),
          _buildAmountRow(
              'Total', 'GHS ${_totalAmount.toStringAsFixed(2)}', true),
        ],
      ),
    );
  }

  Widget _buildAmountRow(String label, String value, bool isTotal) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(
                color:
                    isTotal ? Colors.white : const Color(0xFF888888),
                fontSize: isTotal ? 15 : 13,
                fontWeight:
                    isTotal ? FontWeight.w700 : FontWeight.normal)),
        Text(value,
            style: TextStyle(
                color: isTotal
                    ? const Color(0xFFFF6B00)
                    : Colors.white,
                fontSize: isTotal ? 16 : 13,
                fontWeight: isTotal
                    ? FontWeight.w800
                    : FontWeight.w600)),
      ],
    );
  }

  Widget _buildPaymentMethodsCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Accepted Payment Methods',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 15)),
          const SizedBox(height: 14),
          _buildMethodRow('💳', 'Visa / Mastercard'),
          const SizedBox(height: 10),
          _buildMethodRow('📱', 'MTN Mobile Money'),
          const SizedBox(height: 10),
          _buildMethodRow('📱', 'Vodafone Cash'),
          const SizedBox(height: 10),
          _buildMethodRow('📱', 'AirtelTigo Money'),
          const SizedBox(height: 14),
          const Row(
            children: [
              Icon(Icons.lock_outline,
                  color: Color(0xFF4CAF50), size: 14),
              SizedBox(width: 6),
              Text('Secured by Paystack',
                  style: TextStyle(
                      color: Color(0xFF4CAF50), fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMethodRow(String emoji, String label) {
    return Row(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 18)),
        const SizedBox(width: 10),
        Text(label,
            style: const TextStyle(
                color: Color(0xFFCCCCCC), fontSize: 14)),
        const Spacer(),
        const Icon(Icons.check_circle,
            color: Color(0xFF4CAF50), size: 16),
      ],
    );
  }

  Widget _buildPayButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _initiatePayment,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFFF6B00),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
        child: _isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2.5))
            : Text(
                'Pay GHS ${_totalAmount.toStringAsFixed(2)}',
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700),
              ),
      ),
    );
  }

  Widget _buildVerifyButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton(
        onPressed: _isVerifying ? null : _verifyPayment,
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFFFF6B00),
          side: const BorderSide(color: Color(0xFFFF6B00)),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
        ),
        child: _isVerifying
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    color: Color(0xFFFF6B00), strokeWidth: 2))
            : const Text('Already paid? Verify Payment',
                style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w600)),
      ),
    );
  }
}
