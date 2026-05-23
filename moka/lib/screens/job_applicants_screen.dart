 import 'package:flutter/material.dart';
import '../services/job_service.dart';
import '../services/acceptance_fee_service.dart';
import '../models/worker_medal.dart';
import '../widgets/worker_medal_badge.dart';
import '../widgets/accept_worker_sheet.dart';
import 'public_profile_screen.dart';

class JobApplicantsScreen extends StatefulWidget {
  final String jobId;
  final String jobTitle;

  const JobApplicantsScreen({
    super.key,
    required this.jobId,
    required this.jobTitle,
  });

  @override
  State<JobApplicantsScreen> createState() => _JobApplicantsScreenState();
}

class _JobApplicantsScreenState extends State<JobApplicantsScreen> {
  List<Map<String, dynamic>> _applicants = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadApplicants();
  }

  Future<void> _loadApplicants() async {
    setState(() => _isLoading = true);
    try {
      final data = await JobService.getJobApplicants(widget.jobId);
      if (mounted) setState(() => _applicants = data);
    } catch (e) {
      debugPrint('Error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _timeAgo(String? ts) {
    if (ts == null) return '';
    final diff = DateTime.now().difference(DateTime.parse(ts));
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
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
                    color: Color(0xFF888888), fontSize: 12),
                overflow: TextOverflow.ellipsis),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _loadApplicants,
            icon: const Icon(Icons.refresh, color: Color(0xFF888888)),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child:
                  CircularProgressIndicator(color: Color(0xFFFF6B00)))
          : _applicants.isEmpty
              ? _buildEmpty()
              : RefreshIndicator(
                  color: const Color(0xFFFF6B00),
                  backgroundColor: const Color(0xFF1A1A1A),
                  onRefresh: _loadApplicants,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: _applicants.length,
                    itemBuilder: (context, i) =>
                        _buildApplicantCard(_applicants[i]),
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
            style:
                TextStyle(color: Color(0xFF888888), fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildApplicantCard(Map<String, dynamic> application) {
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

    // ── Medal ──
    final medal = rating > 0 ? getMedal(rating) : null;
    final fee = medal != null
        ? AcceptanceFeeService.getFeeForMedal(medal)
        : 3.0;

    // ── Status display ──
    Color statusColor = const Color(0xFFFF9800);
    String statusLabel = '🕐 Pending';
    if (status == 'accepted') {
      statusColor = const Color(0xFF4CAF50);
      statusLabel = '✅ Accepted';
    } else if (status == 'declined' || status == 'rejected') {
      statusColor = const Color(0xFF555555);
      statusLabel = '❌ Declined';
    } else if (status == 'fee_pending') {
      statusColor = const Color(0xFFFF9800);
      statusLabel = '⏳ Payment Pending';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        // Subtle medal tint on card background
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

          // ── Worker info ──────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [

                // Avatar with medal overlay
                GestureDetector(
                  onTap: () {
                    if (workerId.isNotEmpty) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              PublicProfileScreen(userId: workerId),
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
                              ? medal.accentColor.withOpacity(0.15)
                              : const Color(0xFFFF6B00)
                                  .withOpacity(0.15),
                          backgroundImage: avatarUrl != null
                              ? NetworkImage(avatarUrl)
                              : null,
                          child: avatarUrl == null
                              ? Text(
                                  name[0].toUpperCase(),
                                  style: TextStyle(
                                    color: medal?.accentColor ??
                                        const Color(0xFFFF6B00),
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
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
                                color: const Color(0xFF1A1A1A),
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
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0D0D0D),
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: medal.accentColor,
                                  width: 1),
                            ),
                            child: Text(medal.emoji,
                                style:
                                    const TextStyle(fontSize: 11)),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),

                // Name + skill + rating + medal badge
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 16)),
                      const SizedBox(height: 2),
                      Text(skill,
                          style: const TextStyle(
                              color: Color(0xFF888888),
                              fontSize: 13)),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          // Stars with medal color
                          ...List.generate(
                            5,
                            (i) => Icon(
                              Icons.star_rounded,
                              size: 14,
                              color: i < rating.round()
                                  ? (medal?.starColor ??
                                      const Color(0xFFFF6B00))
                                  : const Color(0xFF333333),
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
                          // Medal badge
                          if (medal != null)
                            _DarkMedalBadge(medal: medal),
                        ],
                      ),
                    ],
                  ),
                ),

                // Status + time
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(statusLabel,
                          style: TextStyle(
                              color: statusColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w700)),
                    ),
                    const SizedBox(height: 4),
                    Text(_timeAgo(application['created_at']),
                        style: const TextStyle(
                            color: Color(0xFF555555),
                            fontSize: 11)),
                  ],
                ),
              ],
            ),
          ),

          // ── Action buttons (pending only) ────────────────
          if (status == 'pending') ...[
            Container(height: 1, color: const Color(0xFF2A2A2A)),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
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
                              builder: (_) => PublicProfileScreen(
                                  userId: workerId),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.person_outline,
                          size: 16),
                      label: const Text('Profile'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor:
                            const Color(0xFF888888),
                        side: const BorderSide(
                            color: Color(0xFF2A2A2A)),
                        shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(
                            vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Accept — opens payment sheet
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: () => AcceptWorkerSheet.show(
                        context,
                        applicationId: applicationId,
                        jobId: widget.jobId,
                        workerId: workerId,
                        workerName: name,
                        workerAvatarUrl: avatarUrl,
                        workerRating: rating,
                        onAccepted: _loadApplicants,
                      ),
                      icon: const Icon(
                          Icons.check_circle_outline,
                          size: 16),
                      label: Text(
                        'Accept · GHC ${fee.toStringAsFixed(0)}',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: medal?.accentColor ??
                            const Color(0xFF4CAF50),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(
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

          // ── Fee paid badge (accepted) ────────────────────
          if (status == 'accepted') ...[
            Container(height: 1, color: const Color(0xFF2A2A2A)),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
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
// Overrides the default light colors to match the dark UI
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
        border:
            Border.all(color: medal.accentColor.withOpacity(0.4)),
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