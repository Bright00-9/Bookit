import 'package:flutter/material.dart';
import '../services/job_service.dart';
import 'post_job_screen.dart';
import 'payment_screen.dart';
import 'rate_worker_screen.dart';

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
    _tabController = TabController(length: 3, vsync: this);
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
      debugPrint('Error loading jobs: $e');
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

  String _timeAgo(String? ts) {
    if (ts == null) return '';
    final diff = DateTime.now().difference(DateTime.parse(ts));
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} mins ago';
    if (diff.inHours < 24) return '${diff.inHours} hrs ago';
    if (diff.inDays == 1) return 'Yesterday';
    return '${diff.inDays} days ago';
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
        title: const Text(
          'My Jobs',
          style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 20),
        ),
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
          labelStyle: const TextStyle(
              fontWeight: FontWeight.w700, fontSize: 13),
          tabs: [
            Tab(text: 'Open (${_openJobs.length})'),
            Tab(text: 'Active (${_activeJobs.length})'),
            Tab(text: 'Done (${_completedJobs.length})'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFFF6B00)))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildJobList(_openJobs, 'open'),
                _buildJobList(_activeJobs, 'accepted'),
                _buildJobList(_completedJobs, 'completed'),
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

  Widget _buildJobList(List<Map<String, dynamic>> jobs, String status) {
    if (jobs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              status == 'open'
                  ? Icons.work_outline
                  : status == 'accepted'
                      ? Icons.handyman_outlined
                      : Icons.check_circle_outline,
              color: const Color(0xFF555555),
              size: 48,
            ),
            const SizedBox(height: 12),
            Text(
              status == 'open'
                  ? 'No open jobs'
                  : status == 'accepted'
                      ? 'No active jobs'
                      : 'No completed jobs',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              status == 'open'
                  ? 'Post a job to get started'
                  : status == 'accepted'
                      ? 'Accept a worker to get started'
                      : 'Completed jobs will appear here',
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
        itemBuilder: (context, i) => _buildJobCard(jobs[i]),
      ),
    );
  }

  Widget _buildJobCard(Map<String, dynamic> job) {
    final status = job['status'] ?? 'open';
    final urgency = job['urgency'] ?? 'normal';

    Color urgencyColor = const Color(0xFF4CAF50);
    if (urgency == 'urgent') urgencyColor = const Color(0xFFFF9800);
    if (urgency == 'emergency') urgencyColor = const Color(0xFFF44336);

    Color statusColor = const Color(0xFFFF6B00);
    if (status == 'accepted') statusColor = const Color(0xFF4CAF50);
    if (status == 'completed') statusColor = const Color(0xFF888888);

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
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.work_outline,
                      color: statusColor, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        job['title'] ?? '',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _timeAgo(job['created_at']),
                        style: const TextStyle(
                            color: Color(0xFF555555), fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    status == 'open'
                        ? 'Open'
                        : status == 'accepted'
                            ? 'Active'
                            : 'Done',
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Details
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildChip(Icons.build_outlined,
                    job['skill_needed'] ?? '', const Color(0xFFFF6B00)),
                _buildChip(Icons.flash_on_outlined, urgency,
                    urgencyColor),
                if (job['budget'] != null && job['budget'] > 0)
                  _buildChip(Icons.payments_outlined,
                      'GHS ${(job['budget'] as num).toStringAsFixed(2)}',
                      const Color(0xFF4CAF50)),
                _buildChip(Icons.people_outline,
                    '$applicants applied', const Color(0xFF888888)),
              ],
            ),
          ),

          // Action buttons for completed jobs
          if (status == 'completed') ...[
            const SizedBox(height: 14),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Divider(color: Color(0xFF2A2A2A)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PaymentScreen(
                            jobId: job['id'],
                            workerId: job['worker_id'] ?? '',
                            workerName: job['worker_name'] ?? 'Worker',
                            jobTitle: job['title'] ?? '',
                            amount: (job['budget'] as num?)
                                    ?.toDouble() ??
                                0,
                          ),
                        ),
                      ),
                      icon: const Icon(Icons.payment, size: 16),
                      label: const Text('Pay'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF4CAF50),
                        side: const BorderSide(
                            color: Color(0xFF4CAF50)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        padding:
                            const EdgeInsets.symmetric(vertical: 10),
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
                            workerId: job['worker_id'] ?? '',
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
                        padding:
                            const EdgeInsets.symmetric(vertical: 10),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else
            const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildChip(IconData icon, String label, Color color) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
