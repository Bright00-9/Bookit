 import 'package:flutter/material.dart';
import '../services/payment_service.dart';
import '../models/worker_medal.dart';

class PaymentScreen extends StatefulWidget {
  final String jobId;
  final String workerId;
  final String workerName;
  final String jobTitle;
  final double? workerRating;

  const PaymentScreen({
    super.key,
    required this.jobId,
    required this.workerId,
    required this.workerName,
    required this.jobTitle,
    this.workerRating,
  });

  @override
  State<PaymentScreen> createState() =>
      _PaymentScreenState();
}

class _PaymentScreenState
    extends State<PaymentScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Acceptance fee history (customer)
  List<Map<String, dynamic>> _acceptanceFees = [];
  bool _isLoadingAcceptance = true;

  // Application fee history (worker)
  List<Map<String, dynamic>> _applicationFees = [];
  bool _isLoadingApplication = true;

  WorkerMedal? get _medal =>
      widget.workerRating != null &&
              widget.workerRating! > 0
          ? getMedal(widget.workerRating!)
          : null;

  @override
  void initState() {
    super.initState();
    _tabController =
        TabController(length: 2, vsync: this);
    _loadAcceptanceFees();
    _loadApplicationFees();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAcceptanceFees() async {
    try {
      final data = await PaymentService
          .getAcceptanceFeeHistory();
      if (mounted)
        setState(() => _acceptanceFees = data);
    } catch (e) {
      debugPrint('Acceptance fees error: $e');
    } finally {
      if (mounted)
        setState(
            () => _isLoadingAcceptance = false);
    }
  }

  Future<void> _loadApplicationFees() async {
    try {
      final data = await PaymentService
          .getApplicationFeeHistory();
      if (mounted)
        setState(() => _applicationFees = data);
    } catch (e) {
      debugPrint('Application fees error: $e');
    } finally {
      if (mounted)
        setState(
            () => _isLoadingApplication = false);
    }
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
        title: const Text('Payment History',
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 18)),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFFFF6B00),
          indicatorWeight: 3,
          labelColor: const Color(0xFFFF6B00),
          unselectedLabelColor:
              const Color(0xFF555555),
          labelStyle: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13),
          tabs: const [
            Tab(
              child: Row(
                mainAxisAlignment:
                    MainAxisAlignment.center,
                children: [
                  Icon(Icons.how_to_reg_outlined,
                      size: 15),
                  SizedBox(width: 5),
                  Text('Accepted Workers'),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment:
                    MainAxisAlignment.center,
                children: [
                  Icon(Icons.work_outline,
                      size: 15),
                  SizedBox(width: 5),
                  Text('Job Applications'),
                ],
              ),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // ── Tab 1: Acceptance fees ─────────────
          _buildAcceptanceFeeTab(),
          // ── Tab 2: Application fees ────────────
          _buildApplicationFeeTab(),
        ],
      ),
    );
  }

  // ─── Acceptance fee tab ───────────────────────
  Widget _buildAcceptanceFeeTab() {
    if (_isLoadingAcceptance) {
      return const Center(
          child: CircularProgressIndicator(
              color: Color(0xFFFF6B00)));
    }

    if (_acceptanceFees.isEmpty) {
      return _buildEmptyState(
        icon: Icons.how_to_reg_outlined,
        title: 'No acceptance fees yet',
        subtitle:
            'Fees paid to accept workers will appear here.',
      );
    }

    return RefreshIndicator(
      onRefresh: _loadAcceptanceFees,
      color: const Color(0xFFFF6B00),
      backgroundColor: const Color(0xFF1A1A1A),
      child: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: _acceptanceFees.length,
        itemBuilder: (_, i) =>
            _buildAcceptanceFeeCard(
                _acceptanceFees[i]),
      ),
    );
  }

  Widget _buildAcceptanceFeeCard(
      Map<String, dynamic> fee) {
    final job = fee['jobs'] as Map?;
    final worker = fee['workers'] as Map?;
    final medal = fee['worker_medal'] != null
        ? _medalFromString(fee['worker_medal'])
        : null;
    final paidAt = fee['paid_at'] != null
        ? DateTime.parse(fee['paid_at'])
        : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: medal != null
            ? Color.lerp(
                const Color(0xFF1A1A1A),
                medal.backgroundColor,
                0.15)
            : const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: medal != null
              ? medal.accentColor.withOpacity(0.3)
              : const Color(0xFF2A2A2A),
        ),
      ),
      child: Row(
        children: [
          // Medal or icon
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: (medal?.accentColor ??
                      const Color(0xFFFF6B00))
                  .withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: medal != null
                  ? Text(medal.emoji,
                      style: const TextStyle(
                          fontSize: 20))
                  : const Icon(
                      Icons.payments_outlined,
                      color: Color(0xFFFF6B00),
                      size: 20),
            ),
          ),
          const SizedBox(width: 12),

          // Job + worker info
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  job?['title'] ?? 'Job',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  'Worker: ${worker?['name'] ?? '—'}',
                  style: const TextStyle(
                      color: Color(0xFF888888),
                      fontSize: 12),
                ),
                if (medal != null)
                  Text(
                    '${medal.emoji} ${medal.label} worker',
                    style: TextStyle(
                        color: medal.accentColor,
                        fontSize: 11),
                  ),
                if (paidAt != null)
                  Text(
                    _formatDate(paidAt),
                    style: const TextStyle(
                        color: Color(0xFF555555),
                        fontSize: 11),
                  ),
              ],
            ),
          ),

          // Amount
          Column(
            crossAxisAlignment:
                CrossAxisAlignment.end,
            children: [
              Text(
                'GHC ${(fee['amount'] as num).toStringAsFixed(2)}',
                style: TextStyle(
                  color: medal?.accentColor ??
                      const Color(0xFFFF6B00),
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
              Container(
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.symmetric(
                    horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50)
                      .withOpacity(0.15),
                  borderRadius:
                      BorderRadius.circular(5),
                ),
                child: const Text('Paid',
                    style: TextStyle(
                        color: Color(0xFF4CAF50),
                        fontSize: 10,
                        fontWeight:
                            FontWeight.w600)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Application fee tab ──────────────────────
  Widget _buildApplicationFeeTab() {
    if (_isLoadingApplication) {
      return const Center(
          child: CircularProgressIndicator(
              color: Color(0xFFFF6B00)));
    }

    if (_applicationFees.isEmpty) {
      return _buildEmptyState(
        icon: Icons.work_outline,
        title: 'No application fees yet',
        subtitle:
            'Fees paid to apply for jobs will appear here.',
      );
    }

    return RefreshIndicator(
      onRefresh: _loadApplicationFees,
      color: const Color(0xFFFF6B00),
      backgroundColor: const Color(0xFF1A1A1A),
      child: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: _applicationFees.length,
        itemBuilder: (_, i) =>
            _buildApplicationFeeCard(
                _applicationFees[i]),
      ),
    );
  }

  Widget _buildApplicationFeeCard(
      Map<String, dynamic> fee) {
    final job = fee['jobs'] as Map?;
    final paidAt = fee['paid_at'] != null
        ? DateTime.parse(fee['paid_at'])
        : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: const Color(0xFF2A2A2A)),
      ),
      child: Row(
        children: [
          // Icon
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFFF6B00)
                  .withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.work_outline,
                color: Color(0xFFFF6B00), size: 20),
          ),
          const SizedBox(width: 12),

          // Job info
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  job?['title'] ?? 'Job',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  job?['skill_needed'] ?? '',
                  style: const TextStyle(
                      color: Color(0xFF888888),
                      fontSize: 12),
                ),
                if (paidAt != null)
                  Text(
                    _formatDate(paidAt),
                    style: const TextStyle(
                        color: Color(0xFF555555),
                        fontSize: 11),
                  ),
              ],
            ),
          ),

          // Amount
          Column(
            crossAxisAlignment:
                CrossAxisAlignment.end,
            children: [
              Text(
                'GHC ${(fee['amount'] as num).toStringAsFixed(2)}',
                style: const TextStyle(
                  color: Color(0xFFFF6B00),
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
              Container(
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.symmetric(
                    horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50)
                      .withOpacity(0.15),
                  borderRadius:
                      BorderRadius.circular(5),
                ),
                child: const Text('Paid',
                    style: TextStyle(
                        color: Color(0xFF4CAF50),
                        fontSize: 10,
                        fontWeight:
                            FontWeight.w600)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Empty state ──────────────────────────────
  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                shape: BoxShape.circle,
                border: Border.all(
                    color: const Color(0xFF2A2A2A)),
              ),
              child: Icon(icon,
                  color: const Color(0xFF555555),
                  size: 32),
            ),
            const SizedBox(height: 16),
            Text(title,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Color(0xFF888888),
                    fontSize: 13,
                    height: 1.5)),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}