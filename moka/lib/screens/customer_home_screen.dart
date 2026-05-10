import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';
import '../services/job_service.dart';
import '../services/portfolio_service.dart';
import 'profile_screen.dart';
import 'messages_screen.dart';
import 'post_job_screen.dart';
import 'my_jobs_screen.dart';
import 'post_detail_screen.dart';
import 'public_profile_screen.dart';

class CustomerHomeScreen extends StatefulWidget {
  const CustomerHomeScreen({super.key});

  @override
  State<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen> {
  int _currentIndex = 0;
  Map<String, dynamic>? _profile;
  List<Map<String, dynamic>> _recentJobs = [];
  List<Map<String, dynamic>> _feedPosts = [];
  List<Map<String, dynamic>> _topWorkers = [];
  bool _isLoadingJobs = true;
  RealtimeChannel? _feedChannel;
  RealtimeChannel? _jobsChannel;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadData();
    // Subscribe to realtime feed updates
    _feedChannel = PortfolioService.subscribeToFeed(
      onPostChange: _loadFeedOnly,
    );
    // Subscribe to new job applications (so customer sees applicants instantly)
    _jobsChannel = Supabase.instance.client
        .channel('my_job_applications')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'job_applications',
          callback: (_) {
            if (mounted) _loadJobsOnly();
          },
        )
        .subscribe();
    // Auto-refresh every 15 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) _loadData();
    });
  }

  @override
  void dispose() {
    _feedChannel?.unsubscribe();
    _jobsChannel?.unsubscribe();
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadJobsOnly() async {
    try {
      final jobs = await JobService.getMyJobs();
      if (mounted) setState(() => _recentJobs = jobs);
    } catch (e) {
      debugPrint('Jobs update error: $e');
    }
  }

  Future<void> _loadFeedOnly() async {
    try {
      final posts = await PortfolioService.getFeedPosts();
      if (mounted) setState(() => _feedPosts = posts);
    } catch (e) {
      debugPrint('Feed update error: $e');
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoadingJobs = true);
    try {
      final profile = await AuthService.getCurrentProfile();
      final jobs = await JobService.getMyJobs();
      final posts = await PortfolioService.getFeedPosts();
      final workers = await PortfolioService.getTopWorkers();
      if (mounted) {
        setState(() {
          _profile = profile;
          _recentJobs = jobs;
          _feedPosts = posts;
          _topWorkers = workers;
        });
      }
    } catch (e) {
      debugPrint('Error loading data: $e');
    } finally {
      if (mounted) setState(() => _isLoadingJobs = false);
    }
  }

  String _timeAgo(String? createdAt) {
    if (createdAt == null) return '';
    final diff = DateTime.now().difference(DateTime.parse(createdAt));
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
      body: SafeArea(
        child: NestedScrollView(
          headerSliverBuilder: (context, innerScrolled) => [
            SliverToBoxAdapter(child: _buildHeader()),
            SliverToBoxAdapter(child: _buildStatsBar()),
          ],
          body: RefreshIndicator(
            color: const Color(0xFFFF6B00),
            backgroundColor: const Color(0xFF1A1A1A),
            onRefresh: _loadData,
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: _buildPostJobBanner(),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                    child: _buildSkillCategories(),
                  ),
                ),
                // Top Rated Workers
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                    child: _buildSectionHeader('Top Rated Workers',
                        onTap: null),
                  ),
                ),
                SliverToBoxAdapter(
                  child: _topWorkers.isEmpty
                      ? const SizedBox.shrink()
                      : SizedBox(
                          height: 140,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            padding:
                                const EdgeInsets.symmetric(horizontal: 20),
                            itemCount: _topWorkers.length,
                            itemBuilder: (context, i) =>
                                _buildTopWorkerCard(_topWorkers[i]),
                          ),
                        ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                    child: _buildSectionHeader('My Jobs', onTap: () async {
                      await Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const MyJobsScreen()));
                      _loadData();
                    }),
                  ),
                ),
                _isLoadingJobs
                    ? const SliverToBoxAdapter(
                        child: Center(
                          child: Padding(
                            padding: EdgeInsets.all(20),
                            child: CircularProgressIndicator(
                                color: Color(0xFFFF6B00)),
                          ),
                        ),
                      )
                    : _recentJobs.isEmpty
                        ? SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 20),
                              child: _buildEmptyJobs(),
                            ),
                          )
                        : SliverToBoxAdapter(
                            child: SizedBox(
                              height: 160,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                padding: const EdgeInsets.symmetric(horizontal: 20),
                                itemCount: _recentJobs.length,
                                itemBuilder: (context, i) =>
                                    _buildJobCardHorizontal(_recentJobs[i]),
                              ),
                            ),
                          ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                    child: _buildSectionHeader('Workers\' Feed', onTap: null),
                  ),
                ),
                _feedPosts.isEmpty
                    ? SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: _buildEmptyFeed(),
                        ),
                      )
                    : SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, i) => Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: _buildFeedCard(_feedPosts[i]),
                          ),
                          childCount: _feedPosts.length,
                        ),
                      ),
                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const PostJobScreen()),
          );
          _loadData();
        },
        backgroundColor: const Color(0xFFFF6B00),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Post Job',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _buildSectionHeader(String title, {VoidCallback? onTap}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700)),
        if (onTap != null)
          GestureDetector(
            onTap: onTap,
            child: const Text('See all',
                style: TextStyle(color: Color(0xFFFF6B00), fontSize: 13)),
          ),
      ],
    );
  }

  Widget _buildStatsBar() {
    final open = _recentJobs.where((j) => j['status'] == 'open').length;
    final active = _recentJobs.where((j) => j['status'] == 'accepted').length;
    final done = _recentJobs.where((j) => j['status'] == 'completed').length;

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 0),
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _miniStat('$open', 'Open', const Color(0xFFFF6B00)),
          _statDiv(),
          _miniStat('$active', 'Active', const Color(0xFF4CAF50)),
          _statDiv(),
          _miniStat('$done', 'Done', const Color(0xFF888888)),
          _statDiv(),
          _miniStat('${_feedPosts.length}', 'Posts', const Color(0xFF2196F3)),
        ],
      ),
    );
  }

  Widget _miniStat(String value, String label, Color color) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                color: color, fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 2),
        Text(label,
            style: const TextStyle(
                color: Color(0xFF888888), fontSize: 10)),
      ],
    );
  }

  Widget _statDiv() =>
      Container(width: 1, height: 28, color: const Color(0xFF2A2A2A));

  Widget _buildJobCardHorizontal(Map<String, dynamic> job) {
    final status = job['status'] ?? 'open';
    Color statusColor = const Color(0xFFFF6B00);
    if (status == 'accepted') statusColor = const Color(0xFF4CAF50);
    if (status == 'completed') statusColor = const Color(0xFF888888);
    if (status == 'expired') statusColor = const Color(0xFFE53935);

    int applicants = 0;
    final appData = job['job_applications'];
    if (appData is List && appData.isNotEmpty) {
      applicants = appData[0]['count'] ?? 0;
    }

    return GestureDetector(
      onTap: () async {
        await Navigator.push(context,
            MaterialPageRoute(builder: (_) => const MyJobsScreen()));
        _loadData();
      },
      child: Container(
        width: 220,
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: statusColor.withOpacity(0.4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    status == 'open'
                        ? '📋 Open'
                        : status == 'accepted'
                            ? '🔨 Active'
                            : status == 'expired'
                                ? '⏰ Expired'
                                : '✅ Done',
                    style: TextStyle(
                        color: statusColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w700),
                  ),
                ),
                const Spacer(),
                Text(_timeAgo(job['created_at']),
                    style: const TextStyle(
                        color: Color(0xFF555555), fontSize: 10)),
              ],
            ),
            const SizedBox(height: 8),
            Text(job['title'] ?? '',
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
            const Spacer(),
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF252525),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(job['skill_needed'] ?? '',
                      style: const TextStyle(
                          color: Color(0xFF888888), fontSize: 10)),
                ),
                const Spacer(),
                Text('$applicants applied',
                    style: const TextStyle(
                        color: Color(0xFF555555), fontSize: 10)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyFeed() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: const Column(
        children: [
          Icon(Icons.photo_library_outlined,
              color: Color(0xFF555555), size: 40),
          SizedBox(height: 10),
          Text('No worker posts yet',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14)),
          SizedBox(height: 4),
          Text('Workers will share their work here',
              style: TextStyle(color: Color(0xFF888888), fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final name = _profile?['name'] ?? 'there';
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hello, $name 👋',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                'What do you need help with?',
                style: TextStyle(color: Color(0xFF888888), fontSize: 13),
              ),
            ],
          ),
          const Spacer(),
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProfileScreen()),
            ),
            child: const CircleAvatar(
              radius: 22,
              backgroundColor: Color(0xFF1A1A1A),
              child: Icon(Icons.person, color: Color(0xFF888888)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostJobBanner() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF6B00), Color(0xFFFF8C00)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Need a worker?',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Post a job and get\nalerts from nearby workers',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 14),
                ElevatedButton(
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const PostJobScreen()),
                    );
                    _loadData();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFFFF6B00),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    elevation: 0,
                  ),
                  child: const Text('Post Now',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
          const Icon(Icons.handyman_rounded, color: Colors.white30, size: 80),
        ],
      ),
    );
  }

  Widget _buildSkillCategories() {
    final categories = [
      {'icon': Icons.plumbing, 'label': 'Plumber'},
      {'icon': Icons.electric_bolt, 'label': 'Electrician'},
      {'icon': Icons.cleaning_services, 'label': 'Cleaner'},
      {'icon': Icons.format_paint, 'label': 'Painter'},
      {'icon': Icons.carpenter, 'label': 'Carpenter'},
      {'icon': Icons.more_horiz, 'label': 'More'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Browse by Skill',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 14),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.1,
          ),
          itemCount: categories.length,
          itemBuilder: (context, i) {
            return GestureDetector(
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PostJobScreen()),
                );
                _loadData();
              },
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF2A2A2A)),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(categories[i]['icon'] as IconData,
                        color: const Color(0xFFFF6B00), size: 28),
                    const SizedBox(height: 6),
                    Text(
                      categories[i]['label'] as String,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildTopWorkerCard(Map<String, dynamic> worker) {
    final name = worker['name'] ?? '';
    final skill = worker['skill'] ?? '';
    final rating = (worker['rating'] ?? 0.0).toDouble();
    final avatarUrl = worker['avatar_url'];
    final isOnline = worker['is_online'] == true;
    final workerId = worker['id'];

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PublicProfileScreen(userId: workerId),
        ),
      ),
      child: Container(
        width: 110,
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isOnline
                ? const Color(0xFF4CAF50).withOpacity(0.4)
                : const Color(0xFF2A2A2A),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Avatar with online indicator
            Stack(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor:
                      const Color(0xFFFF6B00).withOpacity(0.15),
                  backgroundImage:
                      avatarUrl != null ? NetworkImage(avatarUrl) : null,
                  child: avatarUrl == null
                      ? Text(
                          name.isNotEmpty ? name[0].toUpperCase() : '?',
                          style: const TextStyle(
                            color: Color(0xFFFF6B00),
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        )
                      : null,
                ),
                if (isOnline)
                  Positioned(
                    bottom: 1,
                    right: 1,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: const Color(0xFF4CAF50),
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: const Color(0xFF1A1A1A), width: 2),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            // Name
            Text(
              name,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 2),
            // Skill
            Text(
              skill,
              style: const TextStyle(
                  color: Color(0xFF888888), fontSize: 10),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            // Rating
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.star_rounded,
                    color: Color(0xFFFF6B00), size: 12),
                const SizedBox(width: 2),
                Text(
                  rating.toStringAsFixed(1),
                  style: const TextStyle(
                    color: Color(0xFFFF6B00),
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyJobs() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: Column(
        children: [
          const Icon(Icons.work_off_outlined, color: Color(0xFF555555), size: 40),
          const SizedBox(height: 10),
          const Text('No jobs posted yet',
              style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          const Text('Tap Post Job to get started',
              style: TextStyle(color: Color(0xFF888888), fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildFeedCard(Map<String, dynamic> post) {
    final worker = post['profiles'] as Map<String, dynamic>?;
    final workerName = worker?['name'] ?? 'Worker';
    final workerSkill = worker?['skill'] ?? '';
    final workerId = worker?['id'];
    final avatarUrl = worker?['avatar_url'];
    final likesCount = post['likes_count'] ?? 0;
    final commentsCount = post['comments_count'] ?? 0;

    return GestureDetector(
      onTap: () => Navigator.push(context,
        MaterialPageRoute(builder: (_) => PostDetailScreen(post: post)),
      ).then((_) => _loadFeedOnly()),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF2A2A2A)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Worker header
            GestureDetector(
              onTap: () {
                if (workerId != null) {
                  Navigator.push(context, MaterialPageRoute(
                    builder: (_) => PublicProfileScreen(userId: workerId),
                  ));
                }
              },
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: const Color(0xFFFF6B00).withOpacity(0.15),
                      backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                      child: avatarUrl == null
                          ? Text(workerName[0].toUpperCase(),
                              style: const TextStyle(color: Color(0xFFFF6B00), fontWeight: FontWeight.w700))
                          : null,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(workerName,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                          Text(workerSkill,
                              style: const TextStyle(color: Color(0xFF888888), fontSize: 11)),
                        ],
                      ),
                    ),
                    if (post['skill'] != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF6B00).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(post['skill'],
                            style: const TextStyle(color: Color(0xFFFF6B00), fontSize: 10, fontWeight: FontWeight.w600)),
                      ),
                  ],
                ),
              ),
            ),
            // Image
            ClipRRect(
              child: Image.network(
                post['image_url'],
                width: double.infinity,
                height: 220,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  height: 220,
                  color: const Color(0xFF252525),
                  child: const Icon(Icons.image_not_supported, color: Color(0xFF555555), size: 40),
                ),
              ),
            ),
            // Caption + stats
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (post['caption'] != null)
                    Text(post['caption'],
                        style: const TextStyle(color: Color(0xFFCCCCCC), fontSize: 13),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(Icons.favorite_border_rounded, color: Color(0xFF888888), size: 18),
                      const SizedBox(width: 4),
                      Text('$likesCount', style: const TextStyle(color: Color(0xFF888888), fontSize: 12)),
                      const SizedBox(width: 14),
                      const Icon(Icons.chat_bubble_outline, color: Color(0xFF888888), size: 16),
                      const SizedBox(width: 4),
                      Text('$commentsCount', style: const TextStyle(color: Color(0xFF888888), fontSize: 12)),
                      const Spacer(),
                      const Text('Tap to view & like',
                          style: TextStyle(color: Color(0xFF555555), fontSize: 11)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF111111),
        border: Border(top: BorderSide(color: Color(0xFF1F1F1F))),
      ),
      child: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) {
          setState(() => _currentIndex = i);
          if (i == 1) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MyJobsScreen()),
            );
          } else if (i == 2) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MessagesScreen()),
            );
          } else if (i == 3) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProfileScreen()),
            );
          }
        },
        backgroundColor: Colors.transparent,
        selectedItemColor: const Color(0xFFFF6B00),
        unselectedItemColor: const Color(0xFF555555),
        elevation: 0,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'Home'),
          BottomNavigationBarItem(
              icon: Icon(Icons.work_outline),
              activeIcon: Icon(Icons.work),
              label: 'My Jobs'),
          BottomNavigationBarItem(
              icon: Icon(Icons.chat_bubble_outline),
              activeIcon: Icon(Icons.chat_bubble),
              label: 'Messages'),
          BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'Profile'),
        ],
      ),
    );
  }
}
