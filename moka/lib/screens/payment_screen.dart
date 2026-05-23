 import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/payment_service.dart';
import '../services/auth_service.dart';
import '../models/worker_medal.dart';

class PaymentScreen extends StatefulWidget {
  final String jobId;
  final String workerId;
  final String workerName;
  final String jobTitle;
  final double amount;
  final double? workerRating; // optional — for medal display

  const PaymentScreen({
    super.key,
    required this.jobId,
    required this.workerId,
    required this.workerName,
    required this.jobTitle,
    required this.amount,
    this.workerRating,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  bool _isLoading = false;
  bool _isVerifying = false;
  String? _reference;
  String _paymentStatus = 'pending';
  Map<String, dynamic>? _existingPayment;
  bool _isCheckingExisting = true;
  List<Map<String, dynamic>> _feeHistory = [];
  bool _isLoadingHistory = false;
  bool _showHistory = false;

  // Paystack fee: 1.5% + GHS 0.10, capped at GHS 2,000
  double get _paystackFee {
    final fee = widget.amount * 0.015 + 0.10;
    return fee > 2000 ? 2000 : fee;
  }

  double get _totalAmount => widget.amount + _paystackFee;

  WorkerMedal? get _medal => widget.workerRating != null &&
          widget.workerRating! > 0
      ? getMedal(widget.workerRating!)
      : null;

  @override
  void initState() {
    super.initState();
    _checkExistingPayment();
  }

  Future<void> _checkExistingPayment() async {
    setState(() => _isCheckingExisting = true);
    try {
      final payment =
          await PaymentService.getJobPayment(widget.jobId);
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

  Future<void> _loadFeeHistory() async {
    setState(() => _isLoadingHistory = true);
    try {
      final history =
          await PaymentService.getAcceptanceFeeHistory();
      if (mounted) setState(() => _feeHistory = history);
    } catch (e) {
      debugPrint('Error loading fee history: $e');
    } finally {
      if (mounted) setState(() => _isLoadingHistory = false);
    }
  }

  Future<void> _initiatePayment() async {
    setState(() => _isLoading = true);
    try {
      final email = AuthService.currentEmail ?? '';

      final result = await PaymentService.initializePayment(
        jobId: widget.jobId,
        workerId: widget.workerId,
        amount: widget.amount,
        customerEmail: email,
      );

      _reference = result['reference'];
      final authUrl = result['authorization_url'];

      final uri = Uri.parse(authUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri,
            mode: LaunchMode.externalApplication);
        if (mounted) _showVerifyDialog();
      } else {
        throw Exception('Could not open payment page');
      }
    } catch (e) {
      if (!mounted) return;
      _showError(
          e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _verifyPayment() async {
    if (_reference == null) return;
    setState(() => _isVerifying = true);
    try {
      final success =
          await PaymentService.verifyPayment(_reference!);
      if (mounted) {
        setState(() =>
            _paymentStatus = success ? 'success' : 'failed');
        if (success) {
          _showSuccessDialog();
        } else {
          _showError(
              'Payment not completed. Please try again.');
        }
      }
    } catch (e) {
      if (!mounted) return;
      _showError(
          'Could not verify payment. Please try again.');
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
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: const Text('Confirm Payment',
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700)),
        content: const Text(
          'Have you completed the payment on Paystack?',
          style: TextStyle(color: Color(0xFF888888)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Not yet',
                style: TextStyle(
                    color: Color(0xFF888888))),
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
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: const Color(0xFF4CAF50)
                    .withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                  Icons.check_circle_rounded,
                  color: Color(0xFF4CAF50),
                  size: 36),
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
                  backgroundColor:
                      const Color(0xFF4CAF50),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: const Text('Done',
                    style: TextStyle(
                        fontWeight: FontWeight.w700)),
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
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10)),
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
              child: CircularProgressIndicator(
                  color: Color(0xFFFF6B00)))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  // Status banners
                  if (_paymentStatus == 'success')
                    _buildSuccessBanner(),
                  if (_paymentStatus == 'failed')
                    _buildFailedBanner(),

                  // Worker card with medal
                  _buildWorkerCard(),
                  const SizedBox(height: 20),

                  // Amount breakdown
                  _buildAmountCard(),
                  const SizedBox(height: 20),

                  // Payment methods
                  _buildPaymentMethodsCard(),
                  const SizedBox(height: 20),

                  // Acceptance fee history
                  _buildFeeHistorySection(),
                  const SizedBox(height: 32),

                  // Pay button
                  if (_paymentStatus != 'success')
                    _buildPayButton(),

                  // Verify button
                  if (_paymentStatus == 'pending' &&
                      _existingPayment != null) ...[
                    const SizedBox(height: 12),
                    _buildVerifyButton(),
                  ],

                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }

  // ─── Status banners ───────────────────────────────────
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
          Icon(Icons.check_circle,
              color: Color(0xFF4CAF50), size: 20),
          SizedBox(width: 10),
          Text('Payment completed successfully!',
              style: TextStyle(
                  color: Color(0xFF4CAF50),
                  fontWeight: FontWeight.w600)),
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
          Icon(Icons.error_outline,
              color: Color(0xFFE53935), size: 20),
          SizedBox(width: 10),
          Text('Payment failed. Please try again.',
              style: TextStyle(
                  color: Color(0xFFE53935),
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  // ─── Worker card with medal ───────────────────────────
  Widget _buildWorkerCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        // Subtle medal tint if medal exists
        color: _medal != null
            ? Color.lerp(const Color(0xFF1A1A1A),
                _medal!.backgroundColor, 0.2)
            : const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _medal != null
              ? _medal!.accentColor.withOpacity(0.3)
              : const Color(0xFF2A2A2A),
        ),
      ),
      child: Row(
        children: [
          // Avatar with medal overlay
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _medal?.accentColor ??
                        const Color(0xFFFF6B00)
                            .withOpacity(0.4),
                    width: 2,
                  ),
                ),
                child: CircleAvatar(
                  radius: 25,
                  backgroundColor: _medal != null
                      ? _medal!.accentColor.withOpacity(0.15)
                      : const Color(0xFFFF6B00)
                          .withOpacity(0.15),
                  child: Text(
                    widget.workerName[0].toUpperCase(),
                    style: TextStyle(
                      color: _medal?.accentColor ??
                          const Color(0xFFFF6B00),
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              if (_medal != null)
                Positioned(
                  bottom: -3,
                  right: -3,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D0D0D),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: _medal!.accentColor,
                          width: 1),
                    ),
                    child: Text(_medal!.emoji,
                        style:
                            const TextStyle(fontSize: 10)),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(widget.workerName,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700)),
                    if (_medal != null) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: _medal!.accentColor
                              .withOpacity(0.15),
                          borderRadius:
                              BorderRadius.circular(6),
                          border: Border.all(
                              color: _medal!.accentColor
                                  .withOpacity(0.4)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_medal!.emoji,
                                style: const TextStyle(
                                    fontSize: 10)),
                            const SizedBox(width: 3),
                            Text(
                              _medal!.label,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: _medal!.accentColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(widget.jobTitle,
                    style: const TextStyle(
                        color: Color(0xFF888888),
                        fontSize: 13),
                    overflow: TextOverflow.ellipsis),
                if (widget.workerRating != null &&
                    widget.workerRating! > 0) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.star_rounded,
                          size: 13,
                          color: _medal?.starColor ??
                              const Color(0xFFFF6B00)),
                      const SizedBox(width: 3),
                      Text(
                        widget.workerRating!
                            .toStringAsFixed(1),
                        style: TextStyle(
                          fontSize: 12,
                          color: _medal?.accentColor ??
                              const Color(0xFFFF6B00),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'GHS ${widget.amount.toStringAsFixed(2)}',
                style: TextStyle(
                  color: _medal?.accentColor ??
                      const Color(0xFFFF6B00),
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Text('Job amount',
                  style: TextStyle(
                      color: Color(0xFF888888),
                      fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Amount card ──────────────────────────────────────
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
              'GHS ${widget.amount.toStringAsFixed(2)}',
              false),
          const SizedBox(height: 8),
          _buildAmountRow(
              'Paystack Fee (1.5% + 0.10)',
              'GHS ${_paystackFee.toStringAsFixed(2)}',
              false),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Divider(color: Color(0xFF2A2A2A)),
          ),
          _buildAmountRow('Total',
              'GHS ${_totalAmount.toStringAsFixed(2)}',
              true),
        ],
      ),
    );
  }

  Widget _buildAmountRow(
      String label, String value, bool isTotal) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(
                color: isTotal
                    ? Colors.white
                    : const Color(0xFF888888),
                fontSize: isTotal ? 15 : 13,
                fontWeight: isTotal
                    ? FontWeight.w700
                    : FontWeight.normal)),
        Text(value,
            style: TextStyle(
                color: isTotal
                    ? (_medal?.accentColor ??
                        const Color(0xFFFF6B00))
                    : Colors.white,
                fontSize: isTotal ? 16 : 13,
                fontWeight: isTotal
                    ? FontWeight.w800
                    : FontWeight.w600)),
      ],
    );
  }

  // ─── Payment methods card ─────────────────────────────
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
                      color: Color(0xFF4CAF50),
                      fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMethodRow(String emoji, String label) {
    return Row(
      children: [
        Text(emoji,
            style: const TextStyle(fontSize: 18)),
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

  // ─── Acceptance fee history ───────────────────────────
  Widget _buildFeeHistorySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Toggle header
        GestureDetector(
          onTap: () async {
            setState(() => _showHistory = !_showHistory);
            if (_showHistory && _feeHistory.isEmpty) {
              await _loadFeeHistory();
            }
          },
          child: Row(
            mainAxisAlignment:
                MainAxisAlignment.spaceBetween,
            children: [
              const Text('Acceptance Fee History',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15)),
              Icon(
                _showHistory
                    ? Icons.keyboard_arrow_up
                    : Icons.keyboard_arrow_down,
                color: const Color(0xFF888888),
              ),
            ],
          ),
        ),

        if (_showHistory) ...[
          const SizedBox(height: 12),
          if (_isLoadingHistory)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(
                    color: Color(0xFFFF6B00)),
              ),
            )
          else if (_feeHistory.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: const Color(0xFF2A2A2A)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline,
                      color: Color(0xFF888888), size: 16),
                  SizedBox(width: 8),
                  Text('No acceptance fees paid yet.',
                      style: TextStyle(
                          color: Color(0xFF888888),
                          fontSize: 13)),
                ],
              ),
            )
          else
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: const Color(0xFF2A2A2A)),
              ),
              child: Column(
                children: _feeHistory
                    .asMap()
                    .entries
                    .map((entry) {
                  final idx = entry.key;
                  final fee = entry.value;
                  final job = fee['jobs'] as Map?;
                  final worker =
                      fee['workers'] as Map?;
                  final medal = fee['worker_medal'] != null
                      ? _medalFromString(
                          fee['worker_medal'])
                      : null;
                  final isLast =
                      idx == _feeHistory.length - 1;

                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            // Medal emoji
                            if (medal != null)
                              Text(medal.emoji,
                                  style: const TextStyle(
                                      fontSize: 22))
                            else
                              const Icon(
                                  Icons.payments_outlined,
                                  color: Color(0xFF888888),
                                  size: 22),
                            const SizedBox(width: 12),

                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment
                                        .start,
                                children: [
                                  Text(
                                    job?['title'] ??
                                        'Job',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight:
                                            FontWeight.w600,
                                        fontSize: 13),
                                    overflow: TextOverflow
                                        .ellipsis,
                                  ),
                                  Text(
                                    worker?['name'] ??
                                        'Worker',
                                    style: const TextStyle(
                                        color: Color(
                                            0xFF888888),
                                        fontSize: 12),
                                  ),
                                ],
                              ),
                            ),

                            Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.end,
                              children: [
                                Text(
                                  'GHS ${(fee['amount'] as num).toStringAsFixed(2)}',
                                  style: TextStyle(
                                    color: medal
                                            ?.accentColor ??
                                        const Color(
                                            0xFFFF6B00),
                                    fontWeight:
                                        FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                                if (medal != null)
                                  Text(
                                    medal.label,
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: medal
                                          .accentColor
                                          .withOpacity(0.7),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (!isLast)
                        const Divider(
                            height: 1,
                            color: Color(0xFF2A2A2A),
                            indent: 16),
                    ],
                  );
                }).toList(),
              ),
            ),
        ],
      ],
    );
  }

  WorkerMedal _medalFromString(String medal) {
    switch (medal) {
      case 'gold':
        return WorkerMedal.gold;
      case 'silver':
        return WorkerMedal.silver;
      default:
        return WorkerMedal.bronze;
    }
  }

  // ─── Buttons ──────────────────────────────────────────
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
                    fontSize: 16,
                    fontWeight: FontWeight.w700),
              ),
      ),
    );
  }

  Widget _buildVerifyButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton(
        onPressed:
            _isVerifying ? null : _verifyPayment,
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFFFF6B00),
          side: const BorderSide(
              color: Color(0xFFFF6B00)),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
        ),
        child: _isVerifying
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    color: Color(0xFFFF6B00),
                    strokeWidth: 2))
            : const Text(
                'Already paid? Verify Payment',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600)),
      ),
    );
  }
}