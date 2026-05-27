import 'package:flutter/material.dart';
import '../services/job_service.dart';
import 'post_job_screen.dart';
import 'payment_screen.dart';
import 'rate_worker_screen.dart';
import 'job_applicants_screen.dart';

class MyJobsScreen extends StatefulWidget {
  const MyJobsScreen({super.key});

  @override
  State<MyJobsScreen> createState() => _MyJobsScreenState();
}

class _MyJobsScreenState extends State<MyJobsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _allJobs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadJobs();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadJobs() async {
    setState(() => _isLoading = true);
    try {
      final jobs = await JobService.getMyJobs();
      if (mounted) setState(() => _allJobs = jobs);
    } catch (e) {
      debugPrint('Error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> get _openJobs =>
      _allJobs.where((j) => j['status'] == 'open').toList();
  List<Map<String, dynamic>> get _activeJobs =>
      _allJobs.where((j) => j['status'] == 'accepted').toList();
  List<Map<String, dynamic>> get _completedJobs =>
      _allJobs.where((j) => j['status'] == 'completed').toList();
  List<Map<String, dynamic>> get _expiredJobs =>
      _allJobs.where((j) => j['status'] == 'expired').toList();

  String _timeAgo(String? ts) {
    if (ts == null) return '';
    final diff = DateTime.now().difference(DateTime.parse(ts));
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} mins ago';
    if (diff.inHours < 24) return '${diff.inHours} hrs ago';
    if (diff.inDays == 1) return 'Yesterday';
    return '${diff.inDays} days ago';
  }

  Future<void> _markComplete(Map<String, dynamic> job) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Mark as Complete',
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.w700)),
        content: const Text(
          'Is the job done? This will move it to completed and prompt payment.',
          style: TextStyle(color: Color(0xFF888888)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Not yet',
                style: TextStyle(color: Color(0xFF888888))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF6B00),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Yes, complete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await JobService.completeJob(job['id']);
      await _loadJobs();

      if (!mounted) return;

      // Switch to Done tab
      _tabController.animateTo(2);

      // Navigate to payment
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PaymentScreen(
            jobId: job['id'],
            workerId: job['accepted_worker_id'] ?? '',
            workerName: job['worker_name'] ?? 'Worker',
            jobTitle: job['title'] ?? '',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Failed to complete job. Try again.'),
          backgroundColor: const Color(0xFFE53935),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
        ),
      );
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
        title: const Text('My Jobs',
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 20)),
        actions: [
          IconButton(
            onPressed: _loadJobs,
            icon: const Icon(Icons.refresh, color: Color(0xFFFF6B00)),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFFFF6B00),
          indicatorWeight: 3,
          labelColor: const Color(0xFFFF6B00),
          unselectedLabelColor: const Color(0xFF555555),
          labelStyle:
              const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          tabs: [
            Tab(text: 'Open (${_openJobs.length})'),
            Tab(text: 'Active (${_activeJobs.length})'),
            Tab(text: 'Done (${_completedJobs.length})'),
            Tab(text: 'Expired (${_expiredJobs.length})'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFFF6B00)))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildList(_openJobs, 'open'),
                _buildList(_activeJobs, 'accepted'),
                _buildList(_completedJobs, 'completed'),
                _buildList(_expiredJobs, 'expired'),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const PostJobScreen()),
          );
          _loadJobs();
        },
        backgroundColor: const Color(0xFFFF6B00),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Post Job',
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _buildList(List<Map<String, dynamic>> jobs, String type) {
    if (jobs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              type == 'open'
                  ? Icons.work_outline
                  : type == 'accepted'
                      ? Icons.handyman_outlined
                      : Icons.check_circle_outline,
              color: const Color(0xFF555555),
              size: 48,
            ),
            const SizedBox(height: 12),
            Text(
              type == 'open'
                  ? 'No open jobs'
                  : type == 'accepted'
                      ? 'No active jobs'
                      : type == 'expired'
                          ? 'No expired jobs'
                          : 'No completed jobs yet',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              type == 'open'
                  ? 'Post a job to get started'
                  : type == 'accepted'
                      ? 'Accept a worker from Open jobs'
                      : type == 'expired'
                          ? 'Jobs expire after 72 hours with no worker'
                          : 'Completed jobs appear here',
              style: const TextStyle(
                  color: Color(0xFF888888), fontSize: 13),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: const Color(0xFFFF6B00),
      backgroundColor: const Color(0xFF1A1A1A),
      onRefresh: _loadJobs,
      child: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: jobs.length,
        itemBuilder: (context, i) => _buildCard(jobs[i], type),
      ),
    );
  }

  Widget _buildCard(Map<String, dynamic> job, String type) {
    final status = job['status'] ?? 'open';
    final urgency = job['urgency'] ?? 'normal';
    final budget = (job['budget'] as num?)?.toDouble() ?? 0;

    Color statusColor = const Color(0xFFFF6B00);
    if (status == 'accepted') statusColor = const Color(0xFF4CAF50);
    if (status == 'completed') statusColor = const Color(0xFF888888);

    Color urgencyColor = const Color(0xFF4CAF50);
    if (urgency == 'urgent') urgencyColor = const Color(0xFFFF9800);
    if (urgency == 'emergency') urgencyColor = const Color(0xFFF44336);

    int applicants = 0;
    final appData = job['job_applications'];
    if (appData is List && appData.isNotEmpty) {
      applicants = appData[0]['count'] ?? 0;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: status == 'accepted'
              ? const Color(0xFF4CAF50).withOpacity(0.4)
              : status == 'open'
                  ? const Color(0xFFFF6B00).withOpacity(0.3)
                  : const Color(0xFF2A2A2A),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Status + urgency row
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        status == 'open'
                            ? '📋 Open'
                            : status == 'accepted'
                                ? '🔨 Active'
                                : '✅ Done',
                        style: TextStyle(
                            color: statusColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: urgencyColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(urgency,
                          style: TextStyle(
                              color: urgencyColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w600)),
                    ),
                    const Spacer(),
                    Text(_timeAgo(job['created_at']),
                        style: const TextStyle(
                            color: Color(0xFF555555), fontSize: 11)),
                  ],
                ),
                const SizedBox(height: 10),

                // Title
                Text(job['title'] ?? '',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),

                // Chips row
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _chip(Icons.build_outlined,
                        job['skill_needed'] ?? '', const Color(0xFFFF6B00)),
                    if (budget > 0)
                      _chip(Icons.payments_outlined,
                          'GHS ${budget.toStringAsFixed(2)}',
                          const Color(0xFF4CAF50)),
                    if (status == 'open')
                      _chip(Icons.people_outline, '$applicants applied',
                          const Color(0xFF888888)),
                  ],
                ),
              ],
            ),
          ),

          // Action footer
          Container(
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Color(0xFF2A2A2A))),
            ),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: _buildActions(job, status, applicants),
          ),
        ],
      ),
    );
  }

  Widget _buildActions(
      Map<String, dynamic> job, String status, int applicants) {
    if (status == 'open') {
      // Show View Applicants button
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () async {
            final accepted = await Navigator.push<bool>(
              context,
              MaterialPageRoute(
                builder: (_) => JobApplicantsScreen(
                  jobId: job['id'],
                  jobTitle: job['title'] ?? '',
                ),
              ),
            );
            if (accepted == true) _loadJobs();
          },
          icon: const Icon(Icons.people, size: 18),
          label: Text(applicants == 0
              ? 'Waiting for applicants...'
              : 'Review $applicants Applicant${applicants == 1 ? '' : 's'}'),
          style: ElevatedButton.styleFrom(
            backgroundColor: applicants == 0
                ? const Color(0xFF252525)
                : const Color(0xFFFF6B00),
            foregroundColor:
                applicants == 0 ? const Color(0xFF888888) : Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(vertical: 12),
            elevation: 0,
          ),
        ),
      );
    }

    if (status == 'accepted') {
      // Show Job Complete button
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () => _markComplete(job),
          icon: const Icon(Icons.check_circle_outline, size: 18),
          label: const Text('Mark Job as Complete'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF4CAF50),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(vertical: 12),
            elevation: 0,
            textStyle: const TextStyle(
                fontWeight: FontWeight.w700, fontSize: 14),
          ),
        ),
      );
    }

    if (status == 'completed') {
      // Show Pay + Rate buttons
      return Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PaymentScreen(
                    jobId: job['id'],
                    workerId: job['accepted_worker_id'] ?? '',
                    workerName: job['worker_name'] ?? 'Worker',
                    jobTitle: job['title'] ?? '',
                  ),
                ),
              ),
              icon: const Icon(Icons.payment, size: 16),
              label: const Text('Pay'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF4CAF50),
                side: const BorderSide(color: Color(0xFF4CAF50)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => RateWorkerScreen(
                    jobId: job['id'],
                    workerId: job['accepted_worker_id'] ?? '',
                    workerName: job['worker_name'] ?? 'Worker',
                    jobTitle: job['title'] ?? '',
                  ),
                ),
              ),
              icon: const Icon(Icons.star, size: 16),
              label: const Text('Rate'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF6B00),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 10),
                elevation: 0,
              ),
            ),
          ),
        ],
      );
    }

    return const SizedBox.shrink();
  }

  Widget _chip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 13),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
