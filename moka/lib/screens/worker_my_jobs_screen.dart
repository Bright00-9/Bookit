import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'job_detail_screen.dart';
import 'worker_reviews_screen.dart';
import '../services/auth_service.dart';

class WorkerMyJobsScreen extends StatefulWidget {
  const WorkerMyJobsScreen({super.key});

  @override
  State<WorkerMyJobsScreen> createState() => _WorkerMyJobsScreenState();
}

class _WorkerMyJobsScreenState extends State<WorkerMyJobsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _jobs = [];
  Map<String, dynamic>? _profile;
  bool _isLoading = true;
  final _supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      final profile = await AuthService.getCurrentProfile();

      // Get all job applications for this worker
      final data = await _supabase
          .from('job_applications')
          .select('''
            id,
            status,
            job_id,
            jobs(
              id, title, description, skill_needed,
              urgency, status, budget, lat, lng, created_at,
              profiles!customer_id(id, name, phone)
            )
          ''')
          .eq('worker_id', userId)
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _profile = profile;
          _jobs = List<Map<String, dynamic>>.from(data);
        });
      }
    } catch (e) {
      debugPrint('Error loading worker jobs: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> get _activeJobs => _jobs
      .where((j) => (j['jobs']?['status'] == 'accepted'))
      .toList();

  List<Map<String, dynamic>> get _completedJobs => _jobs
      .where((j) => (j['jobs']?['status'] == 'completed'))
      .toList();

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
          // View my reviews button
          if (_profile != null)
            TextButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => WorkerReviewsScreen(
                    workerId: _profile!['id'],
                    workerName: _profile!['name'] ?? 'Worker',
                    rating: (_profile!['rating'] ?? 0.0).toDouble(),
                  ),
                ),
              ),
              icon: const Icon(Icons.star,
                  color: Color(0xFFFF6B00), size: 18),
              label: const Text('Reviews',
                  style: TextStyle(
                      color: Color(0xFFFF6B00),
                      fontWeight: FontWeight.w600)),
            ),
          IconButton(
            onPressed: _loadJobs,
            icon: const Icon(Icons.refresh, color: Color(0xFF888888)),
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
            Tab(text: 'Active (${_activeJobs.length})'),
            Tab(text: 'Completed (${_completedJobs.length})'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFFF6B00)))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildJobList(_activeJobs, 'active'),
                _buildJobList(_completedJobs, 'completed'),
              ],
            ),
    );
  }

  Widget _buildJobList(
      List<Map<String, dynamic>> applications, String type) {
    if (applications.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              type == 'active'
                  ? Icons.handyman_outlined
                  : Icons.check_circle_outline,
              color: const Color(0xFF555555),
              size: 48,
            ),
            const SizedBox(height: 12),
            Text(
              type == 'active'
                  ? 'No active jobs'
                  : 'No completed jobs yet',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              type == 'active'
                  ? 'Accept a job to see it here'
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
        itemCount: applications.length,
        itemBuilder: (context, i) =>
            _buildJobCard(applications[i], type),
      ),
    );
  }

  Widget _buildJobCard(
      Map<String, dynamic> application, String type) {
    final job = application['jobs'] as Map<String, dynamic>?;
    if (job == null) return const SizedBox.shrink();

    final customer =
        job['profiles'] as Map<String, dynamic>?;
    final customerName = customer?['name'] ?? 'Customer';
    final budget = (job['budget'] as num?)?.toDouble() ?? 0;
    final urgency = job['urgency'] ?? 'normal';

    Color urgencyColor = const Color(0xFF4CAF50);
    if (urgency == 'urgent') urgencyColor = const Color(0xFFFF9800);
    if (urgency == 'emergency') urgencyColor = const Color(0xFFF44336);

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => JobDetailScreen(job: {
            ...job,
            'profiles': customer,
          }),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: type == 'active'
                ? const Color(0xFF4CAF50).withOpacity(0.4)
                : const Color(0xFF2A2A2A),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                          color: (type == 'active'
                                  ? const Color(0xFF4CAF50)
                                  : const Color(0xFF888888))
                              .withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          type == 'active' ? '🔨 Active' : '✅ Completed',
                          style: TextStyle(
                            color: type == 'active'
                                ? const Color(0xFF4CAF50)
                                : const Color(0xFF888888),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
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
                        child: Text(
                          urgency,
                          style: TextStyle(
                              color: urgencyColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        _timeAgo(job['created_at']),
                        style: const TextStyle(
                            color: Color(0xFF555555), fontSize: 11),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Job title
                  Text(
                    job['title'] ?? '',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Customer + budget
                  Row(
                    children: [
                      const Icon(Icons.person_outline,
                          color: Color(0xFF888888), size: 14),
                      const SizedBox(width: 4),
                      Text(customerName,
                          style: const TextStyle(
                              color: Color(0xFF888888), fontSize: 13)),
                      if (budget > 0) ...[
                        const SizedBox(width: 12),
                        const Icon(Icons.payments_outlined,
                            color: Color(0xFF4CAF50), size: 14),
                        const SizedBox(width: 4),
                        Text(
                          'GHS ${budget.toStringAsFixed(2)}',
                          style: const TextStyle(
                              color: Color(0xFF4CAF50),
                              fontSize: 13,
                              fontWeight: FontWeight.w600),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            // View details footer
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                border: Border(
                    top: BorderSide(color: Color(0xFF2A2A2A))),
              ),
              child: Row(
                children: [
                  const Text('Tap to view details',
                      style: TextStyle(
                          color: Color(0xFF888888), fontSize: 12)),
                  const Spacer(),
                  const Icon(Icons.arrow_forward_ios,
                      color: Color(0xFF444444), size: 14),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
