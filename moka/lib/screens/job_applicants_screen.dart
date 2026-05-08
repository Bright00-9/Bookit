import 'package:flutter/material.dart';
import '../services/job_service.dart';
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
  String? _acceptingId;

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

  Future<void> _acceptWorker(Map<String, dynamic> application) async {
    final applicationId = application['id'];
    final workerId = application['worker_id'];
    final worker = application['profiles'] as Map<String, dynamic>?;
    final workerName = worker?['name'] ?? 'Worker';

    // Confirm dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Accept Worker',
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.w700)),
        content: Text(
          'Accept $workerName for this job? This will notify them and start the job.',
          style: const TextStyle(color: Color(0xFF888888)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel',
                style: TextStyle(color: Color(0xFF888888))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4CAF50),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Accept'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _acceptingId = applicationId);
    try {
      await JobService.acceptWorker(
        jobId: widget.jobId,
        workerId: workerId,
        applicationId: applicationId,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$workerName accepted! Job is now active 🔨'),
          backgroundColor: const Color(0xFF4CAF50),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
        ),
      );
      Navigator.pop(context, true); // return true to trigger refresh
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Failed to accept worker. Try again.'),
          backgroundColor: const Color(0xFFE53935),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
        ),
      );
    } finally {
      if (mounted) setState(() => _acceptingId = null);
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
              child: CircularProgressIndicator(color: Color(0xFFFF6B00)))
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
            style: TextStyle(color: Color(0xFF888888), fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildApplicantCard(Map<String, dynamic> application) {
    final worker = application['profiles'] as Map<String, dynamic>?;
    final name = worker?['name'] ?? 'Worker';
    final skill = worker?['skill'] ?? '';
    final rating = (worker?['rating'] ?? 0.0).toDouble();
    final avatarUrl = worker?['avatar_url'];
    final isOnline = worker?['is_online'] == true;
    final workerId = worker?['id'];
    final status = application['status'] ?? 'pending';
    final isAccepting = _acceptingId == application['id'];

    Color statusColor = const Color(0xFFFF9800);
    String statusLabel = 'Pending';
    if (status == 'accepted') {
      statusColor = const Color(0xFF4CAF50);
      statusLabel = 'Accepted ✓';
    } else if (status == 'declined') {
      statusColor = const Color(0xFF555555);
      statusLabel = 'Declined';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: status == 'accepted'
              ? const Color(0xFF4CAF50).withOpacity(0.4)
              : const Color(0xFF2A2A2A),
        ),
      ),
      child: Column(
        children: [
          // Worker info
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Avatar
                GestureDetector(
                  onTap: () {
                    if (workerId != null) {
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
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor:
                            const Color(0xFFFF6B00).withOpacity(0.15),
                        backgroundImage: avatarUrl != null
                            ? NetworkImage(avatarUrl)
                            : null,
                        child: avatarUrl == null
                            ? Text(name[0].toUpperCase(),
                                style: const TextStyle(
                                    color: Color(0xFFFF6B00),
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800))
                            : null,
                      ),
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
                    ],
                  ),
                ),
                const SizedBox(width: 14),

                // Name + skill + rating
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
                              color: Color(0xFF888888), fontSize: 13)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          ...List.generate(
                            5,
                            (i) => Icon(Icons.star_rounded,
                                size: 14,
                                color: i < rating.round()
                                    ? const Color(0xFFFF6B00)
                                    : const Color(0xFF333333)),
                          ),
                          const SizedBox(width: 4),
                          Text(rating.toStringAsFixed(1),
                              style: const TextStyle(
                                  color: Color(0xFF888888),
                                  fontSize: 12)),
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
                            color: Color(0xFF555555), fontSize: 11)),
                  ],
                ),
              ],
            ),
          ),

          // Action buttons — only show if still pending
          if (status == 'pending') ...[
            Container(
              height: 1,
              color: const Color(0xFF2A2A2A),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Row(
                children: [
                  // View profile
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        if (workerId != null) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  PublicProfileScreen(userId: workerId),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.person_outline, size: 16),
                      label: const Text('View Profile'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF888888),
                        side: const BorderSide(color: Color(0xFF2A2A2A)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        padding:
                            const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Accept
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed:
                          isAccepting ? null : () => _acceptWorker(application),
                      icon: isAccepting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.check_circle_outline,
                              size: 16),
                      label: Text(isAccepting ? 'Accepting...' : 'Accept Worker'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4CAF50),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        padding:
                            const EdgeInsets.symmetric(vertical: 10),
                        elevation: 0,
                        textStyle: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 13),
                      ),
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
