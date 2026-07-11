 import 'package:flutter/material.dart';
import '../services/job_service.dart';
import '../services/payment_service.dart';
import '../models/worker_medal.dart';
import '../services/identity_verification_service.dart';
import '../widgets/accept_worker_sheet.dart';
import 'public_profile_screen.dart';
import 'identity_verification_screen.dart';

class JobApplicantsScreen extends StatefulWidget {
  final String jobId;
  final String jobTitle;

  const JobApplicantsScreen({
    super.key,
    required this.jobId,
    required this.jobTitle,
  });

  @override
  State<JobApplicantsScreen> createState() =>
      _JobApplicantsScreenState();
}

class _JobApplicantsScreenState
    extends State<JobApplicantsScreen> {
  List<Map<String, dynamic>> _applicants = [];
  bool _isLoading = true;

  // Cache customer's own verification status
  // so we don't fetch on every card tap
  bool? _customerVerified;

  @override
  void initState() {
    super.initState();
    _loadApplicants();
    _checkCustomerVerification();
  }

  // ── Check if the customer viewing this screen
  // is identity verified ─────────────────────────────────
  Future<void> _checkCustomerVerification() async {
    try {
      final service = IdentityVerificationService();
      final verified = await service.canPerformActions();
      if (mounted) {
        setState(() => _customerVerified = verified);
      }
    } catch (_) {
      if (mounted) setState(() => _customerVerified = true);
    }
  }

  Future<void> _loadApplicants() async {
    setState(() => _isLoading = true);
    try {
      final data =
          await JobService.getJobApplicants(widget.jobId);
      if (mounted) setState(() => _applicants = data);
    } catch (e) {
      debugPrint('Error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Handle accept — checks customer verification
  // before opening payment sheet ─────────────────────────
  Future<void> _handleAccept({
    required String applicationId,
    required String workerId,
    required String workerName,
    required String? workerAvatarUrl,
    required double rating,
  }) async {
    // If verification status not yet loaded, wait
    if (_customerVerified == null) {
      await _checkCustomerVerification();
    }

    if (_customerVerified == false) {
      // Show verification required dialog
      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: const Color(0xFFFF6B00)
                      .withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                    Icons.shield_outlined,
                    color: Color(0xFFFF6B00),
                    size: 32),
              ),
              const SizedBox(height: 16),
              const Text('Verification Required',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              const Text(
                'You need to verify your identity before accepting workers. It only takes a few minutes.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Color(0xFF888888),
                    fontSize: 13,
                    height: 1.5),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            const IdentityVerificationScreen(
                                isBlocking: true),
                      ),
                    ).then((_) =>
                        _checkCustomerVerification());
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        const Color(0xFFFF6B00),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: const Text('Verify Now',
                      style: TextStyle(
                          fontWeight: FontWeight.w700)),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Maybe Later',
                    style: TextStyle(
                        color: Color(0xFF888888),
                        fontSize: 13)),
              ),
            ],
          ),
        ),
      );
      return;
    }

    // Customer is verified — open payment sheet
    if (!mounted) return;
    AcceptWorkerSheet.show(
      context,
      applicationId: applicationId,
      jobId: widget.jobId,
      workerId: workerId,
      workerName: workerName,
      workerAvatarUrl: workerAvatarUrl,
      workerRating: rating,
      onAccepted: _loadApplicants,
    );
  }

  String _timeAgo(String? ts) {
    if (ts == null) return '';
    final diff =
        DateTime.now().difference(DateTime.parse(ts));
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60)
      return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Applicants',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 18)),
            Text(widget.jobTitle,
                style: const TextStyle(
                    color: Color(0xFF888888),
                    fontSize: 12),
                overflow: TextOverflow.ellipsis),
          ],
        ),
        actions: [
          // Show verification status in app bar
          if (_customerVerified == false)
            GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      const IdentityVerificationScreen(
                          isBlocking: true),
                ),
              ).then(
                  (_) => _checkCustomerVerification()),
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF9800)
                      .withOpacity(0.15),
                  borderRadius:
                      BorderRadius.circular(8),
                  border: Border.all(
                      color: const Color(0xFFFF9800)
                          .withOpacity(0.5)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.shield_outlined,
                        color: Color(0xFFFF9800),
                        size: 14),
                    SizedBox(width: 4),
                    Text('Verify',
                        style: TextStyle(
                            color: Color(0xFFFF9800),
                            fontSize: 12,
                            fontWeight:
                                FontWeight.w600)),
                  ],
                ),
              ),
            ),
          IconButton(
            onPressed: _loadApplicants,
            icon: const Icon(Icons.refresh,
                color: Color(0xFF888888)),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                  color: Color(0xFFFF6B00)))
          : _applicants.isEmpty
              ? _buildEmpty()
              : RefreshIndicator(
                  color: const Color(0xFFFF6B00),
                  backgroundColor:
                      const Color(0xFF1A1A1A),
                  onRefresh: _loadApplicants,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: _applicants.length,
                    itemBuilder: (context, i) =>
                        _buildApplicantCard(
                            _applicants[i]),
                  ),
                ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.people_outline,
              color: Color(0xFF555555), size: 48),
          const SizedBox(height: 12),
          const Text('No applicants yet',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          const Text(
            'Workers nearby will apply shortly.\nPull down to refresh.',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: Color(0xFF888888), fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildApplicantCard(
      Map<String, dynamic> application) {
    final worker =
        application['profiles'] as Map<String, dynamic>?;
    final name = worker?['name'] ?? 'Worker';
    final skill = worker?['skill'] ?? '';
    final rating = (worker?['rating'] ?? 0.0).toDouble();
    final avatarUrl = worker?['avatar_url'];
    final isOnline = worker?['is_online'] == true;
    final workerId = worker?['id'] ?? '';
    final status = application['status'] ?? 'pending';
    final applicationId = application['id'] ?? '';

    // Worker identity verification status
    final workerIdentityStatus =
        worker?['identity_status'] ?? 'unverified';
    final workerIsVerified =
        workerIdentityStatus == 'verified' ||
            workerIdentityStatus == 'auto_passed';

    // ── Medal ──
    final medal = rating > 0 ? getMedal(rating) : null;
    final fee = medal != null
        ? PaymentService.getAcceptanceFee(medal.name)
        : 3.0;

    // ── Status display ──
    Color statusColor = const Color(0xFFFF9800);
    String statusLabel = 'Pending';
    if (status == 'accepted') {
      statusColor = const Color(0xFF4CAF50);
      statusLabel = 'Accepted';
    } else if (status == 'declined' ||
        status == 'rejected') {
      statusColor = const Color(0xFF555555);
      statusLabel = 'Declined';
    } else if (status == 'fee_pending') {
      statusColor = const Color(0xFFFF9800);
      statusLabel = 'Payment Pending';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: medal != null
            ? Color.lerp(
                const Color(0xFF1A1A1A),
                medal.backgroundColor,
                0.15,
              )
            : const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: status == 'accepted'
              ? const Color(0xFF4CAF50).withOpacity(0.4)
              : medal != null
                  ? medal.accentColor.withOpacity(0.25)
                  : const Color(0xFF2A2A2A),
        ),
      ),
      child: Column(
        children: [

          // ── Worker info ──────────────────────────
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [

                // Avatar with medal + verification overlay
                GestureDetector(
                  onTap: () {
                    if (workerId.isNotEmpty) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              PublicProfileScreen(
                                  userId: workerId),
                        ),
                      );
                    }
                  },
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: medal?.accentColor ??
                                const Color(0xFFFF6B00)
                                    .withOpacity(0.3),
                            width: 2,
                          ),
                        ),
                        child: CircleAvatar(
                          radius: 26,
                          backgroundColor: medal != null
                              ? medal.accentColor
                                  .withOpacity(0.15)
                              : const Color(0xFFFF6B00)
                                  .withOpacity(0.15),
                          backgroundImage: avatarUrl !=
                                  null
                              ? NetworkImage(avatarUrl)
                              : null,
                          child: avatarUrl == null
                              ? Text(
                                  name[0].toUpperCase(),
                                  style: TextStyle(
                                    color: medal
                                            ?.accentColor ??
                                        const Color(
                                            0xFFFF6B00),
                                    fontSize: 20,
                                    fontWeight:
                                        FontWeight.w800,
                                  ),
                                )
                              : null,
                        ),
                      ),

                      // Online dot
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: isOnline
                                ? const Color(0xFF4CAF50)
                                : const Color(0xFF555555),
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: const Color(
                                    0xFF1A1A1A),
                                width: 2),
                          ),
                        ),
                      ),

                      // Medal badge on avatar
                      if (medal != null)
                        Positioned(
                          top: -4,
                          left: -4,
                          child: Container(
                            padding:
                                const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: const Color(
                                  0xFF0D0D0D),
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color:
                                      medal.accentColor,
                                  width: 1),
                            ),
                            child: Text(medal.emoji,
                                style: const TextStyle(
                                    fontSize: 11)),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),

                // Name + skill + rating + badges
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      // Name + verified badge
                      Row(
                        children: [
                          Flexible(
                            child: Text(name,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight:
                                        FontWeight.w700,
                                    fontSize: 15),
                                overflow:
                                    TextOverflow.ellipsis),
                          ),
                          const SizedBox(width: 4),
                          // Identity verified badge
                          if (workerIsVerified)
                            const Icon(Icons.verified,
                                color: Color(0xFF2196F3),
                                size: 15)
                          else
                            Tooltip(
                              message:
                                  'Worker not yet verified',
                              child: const Icon(
                                  Icons.shield_outlined,
                                  color: Color(0xFF555555),
                                  size: 15),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(skill,
                          style: const TextStyle(
                              color: Color(0xFF888888),
                              fontSize: 13)),
                      const SizedBox(height: 6),

                      // Stars + rating + medal badge
                      Row(
                        children: [
                          ...List.generate(
                            5,
                            (i) => Icon(
                              Icons.star_rounded,
                              size: 14,
                              color: i < rating.round()
                                  ? (medal?.starColor ??
                                      const Color(
                                          0xFFFF6B00))
                                  : const Color(
                                      0xFF333333),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            rating.toStringAsFixed(1),
                            style: TextStyle(
                              color: medal?.accentColor ??
                                  const Color(0xFF888888),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 6),
                          if (medal != null)
                            _DarkMedalBadge(medal: medal),
                        ],
                      ),

                      // Unverified worker warning
                      if (!workerIsVerified) ...[
                        const SizedBox(height: 6),
                        Container(
                          padding:
                              const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF9800)
                                .withOpacity(0.1),
                            borderRadius:
                                BorderRadius.circular(6),
                            border: Border.all(
                                color: const Color(
                                        0xFFFF9800)
                                    .withOpacity(0.3)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                  Icons.warning_amber_outlined,
                                  color: Color(0xFFFF9800),
                                  size: 11),
                              SizedBox(width: 3),
                              Text('Not verified',
                                  style: TextStyle(
                                      color:
                                          Color(0xFFFF9800),
                                      fontSize: 10,
                                      fontWeight:
                                          FontWeight.w600)),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // Status chip + time
                Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color:
                            statusColor.withOpacity(0.15),
                        borderRadius:
                            BorderRadius.circular(8),
                      ),
                      child: Text(statusLabel,
                          style: TextStyle(
                              color: statusColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w700)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                        _timeAgo(
                            application['created_at']),
                        style: const TextStyle(
                            color: Color(0xFF555555),
                            fontSize: 11)),
                  ],
                ),
              ],
            ),
          ),

          // ── Action buttons (pending only) ────────
          if (status == 'pending') ...[
            Container(
                height: 1,
                color: const Color(0xFF2A2A2A)),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  16, 12, 16, 16),
              child: Row(
                children: [

                  // View profile
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        if (workerId.isNotEmpty) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  PublicProfileScreen(
                                      userId: workerId),
                            ),
                          );
                        }
                      },
                      icon: const Icon(
                          Icons.person_outline,
                          size: 16),
                      label: const Text('Profile'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor:
                            const Color(0xFF888888),
                        side: const BorderSide(
                            color: Color(0xFF2A2A2A)),
                        shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(
                                    10)),
                        padding:
                            const EdgeInsets.symmetric(
                                vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Accept button
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: () => _handleAccept(
                        applicationId: applicationId,
                        workerId: workerId,
                        workerName: name,
                        workerAvatarUrl: avatarUrl,
                        rating: rating,
                      ),
                      icon: const Icon(
                          Icons.check_circle_outline,
                          size: 16),
                      label: Text(
                        'Accept · GHC ${fee.toStringAsFixed(0)}',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            medal?.accentColor ??
                                const Color(0xFF4CAF50),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(
                                    10)),
                        padding:
                            const EdgeInsets.symmetric(
                                vertical: 10),
                        elevation: 0,
                        textStyle: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // ── Fee paid row (accepted) ───────────────
          if (status == 'accepted') ...[
            Container(
                height: 1,
                color: const Color(0xFF2A2A2A)),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  16, 10, 16, 14),
              child: Row(
                mainAxisAlignment:
                    MainAxisAlignment.center,
                children: [
                  Icon(Icons.payments_outlined,
                      size: 14,
                      color: medal?.accentColor ??
                          const Color(0xFF4CAF50)),
                  const SizedBox(width: 6),
                  Text(
                    'Platform fee of GHC ${fee.toStringAsFixed(0)} paid',
                    style: TextStyle(
                      fontSize: 12,
                      color: medal?.accentColor ??
                          const Color(0xFF4CAF50),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Dark-themed medal badge ───────────────────────────────────
class _DarkMedalBadge extends StatelessWidget {
  final WorkerMedal medal;

  const _DarkMedalBadge({required this.medal});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: medal.accentColor.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
            color: medal.accentColor.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(medal.emoji,
              style: const TextStyle(fontSize: 10)),
          const SizedBox(width: 3),
          Text(
            medal.label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: medal.accentColor,
            ),
          ),
        ],
      ),
    );
  }
}
