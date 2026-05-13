import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';
import '../services/job_service.dart';
import '../services/portfolio_service.dart';
import 'job_detail_screen.dart';
import 'messages_screen.dart';
import 'profile_screen.dart';
import 'worker_my_jobs_screen.dart';
import 'create_portfolio_post_screen.dart';
import 'post_detail_screen.dart';

class WorkerHomeScreen extends StatefulWidget {
  const WorkerHomeScreen({super.key});

  @override
  State<WorkerHomeScreen> createState() => _WorkerHomeScreenState();
}

class _WorkerHomeScreenState extends State<WorkerHomeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isOnline = false;
  int _currentIndex = 0;
  List<Map<String, dynamic>> _nearbyJobs = [];
  List<Map<String, dynamic>> _feedPosts = [];
  List<Map<String, dynamic>> _myPosts = [];
  Map<String, dynamic>? _profile;
  bool _isLoadingJobs = false;
  bool _isLoadingFeed = false;
  double? _lat;
  double? _lng;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadProfile();
    _loadFeed();
    // Auto-refresh every 15 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (!mounted) return;
      _loadFeed();
      if (_isOnline) _loadNearbyJobs(silent: true);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _refreshTimer?.cancel();
    _jobsChannel?.unsubscribe();
    super.dispose();
  }

  Future<void> _loadFeed() async {
    setState(() => _isLoadingFeed = true);
    try {
      final posts = await PortfolioService.getFeedPosts();
      if (mounted) setState(() => _feedPosts = posts);
    } catch (e) {
      debugPrint('Error loading feed: $e');
    } finally {
      if (mounted) setState(() => _isLoadingFeed = false);
    }
  }

  Future<void> _loadMyPosts() async {
    try {
      final userId = _profile?['id'];
      if (userId == null) return;
      final posts = await PortfolioService.getWorkerPosts(userId);
      if (mounted) setState(() => _myPosts = posts);
    } catch (e) {
      debugPrint('Error loading my posts: $e');
    }
  }

  RealtimeChannel? _jobsChannel;

  Future<void> _loadProfile() async {
    final profile = await AuthService.getCurrentProfile();
    if (mounted) setState(() => _profile = profile);
    _loadMyPosts();
    // Subscribe to new open jobs in realtime
    _jobsChannel = Supabase.instance.client
        .channel('new_open_jobs')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'jobs',
          callback: (_) {
            if (_isOnline && mounted) _loadNearbyJobs(silent: true);
          },
        )
        .subscribe();
  }

  Future<void> _toggleOnline(bool value) async {
    setState(() => _isOnline = value);
    if (value) {
      try {
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
        _lat = position.latitude;
        _lng = position.longitude;

        await AuthService.updateWorkerStatus(
          isOnline: true,
          lat: _lat,
          lng: _lng,
        );
        await _loadNearbyJobs();
      } catch (e) {
        setState(() => _isOnline = false);
      }
    } else {
      await AuthService.updateWorkerStatus(isOnline: false);
      setState(() => _nearbyJobs = []);
    }
  }

  Future<void> _loadNearbyJobs({bool silent = false}) async {
    if (_lat == null || _lng == null || _profile == null) return;
    if (!silent) setState(() => _isLoadingJobs = true);
    try {
      final jobs = await JobService.getNearbyJobs(
        skill: _profile!['skill'] ?? '',
        lat: _lat!,
        lng: _lng!,
      );
      if (mounted) setState(() => _nearbyJobs = jobs);
    } catch (e) {
      debugPrint('Error loading jobs: $e');
    } finally {
      if (mounted) setState(() => _isLoadingJobs = false);
    }
  }

  Future<void> _applyToJob(String jobId) async {
    try {
      await JobService.applyToJob(jobId);
      setState(() => _nearbyJobs.removeWhere((j) => j['id'] == jobId));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Applied! Wait for the customer to accept you.'),
          backgroundColor: const Color(0xFF4CAF50),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Could not apply to job. Try again.'),
          backgroundColor: const Color(0xFFE53935),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  String _timeAgo(String? createdAt) {
    if (createdAt == null) return '';
    final diff = DateTime.now().difference(DateTime.parse(createdAt));
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} mins ago';
    if (diff.inHours < 24) return '${diff.inHours} hrs ago';
    return '${diff.inDays} days ago';
  }

  String _distanceLabel(Map<String, dynamic> job) {
    if (_lat == null || _lng == null) return '';
    final d = JobService.distanceBetween(
      _lat!, _lng!,
      (job['lat'] as num).toDouble(),
      (job['lng'] as num).toDouble(),
    );
    return '${d.toStringAsFixed(1)} km';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      drawer: _buildDrawer(),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildOnlineToggle(),
            // Tab bar
            Container(
              decoration: const BoxDecoration(
                border: Border(
                    bottom: BorderSide(color: Color(0xFF1F1F1F))),
              ),
              child: TabBar(
                controller: _tabController,
                indicatorColor: const Color(0xFFFF6B00),
                indicatorWeight: 3,
                labelColor: const Color(0xFFFF6B00),
                unselectedLabelColor: const Color(0xFF555555),
                labelStyle: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 13),
                tabs: [
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.work_outline, size: 16),
                        const SizedBox(width: 5),
                        Text('Jobs (${_nearbyJobs.length})'),
                      ],
                    ),
                  ),
                  const Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.photo_library_outlined, size: 16),
                        SizedBox(width: 5),
                        Text('Feed'),
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.grid_on, size: 16),
                        const SizedBox(width: 5),
                        Text('My Posts (${_myPosts.length})'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Tab 1: Nearby Jobs
                  _isOnline ? _buildJobList() : _buildOfflineState(),
                  // Tab 2: Feed
                  _buildFeedTab(),
                  // Tab 3: My Posts
                  _buildMyPostsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final posted = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
                builder: (_) => const CreatePortfolioPostScreen()),
          );
          if (posted == true) {
            _loadFeed();
            _loadMyPosts();
          }
        },
        backgroundColor: const Color(0xFFFF6B00),
        icon: const Icon(Icons.add_photo_alternate, color: Colors.white),
        label: const Text('Share Work',
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.w700)),
      ),
    );
  }

  // ─── Feed Tab ──────────────────────────────────────────────────────────────
  Widget _buildFeedTab() {
    if (_isLoadingFeed) {
      return const Center(
          child: CircularProgressIndicator(color: Color(0xFFFF6B00)));
    }
    if (_feedPosts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.photo_library_outlined,
                color: Color(0xFF555555), size: 48),
            const SizedBox(height: 12),
            const Text('No posts yet',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            const Text('Be the first to share your work!',
                style: TextStyle(color: Color(0xFF888888), fontSize: 13)),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: _loadFeed,
              icon: const Icon(Icons.refresh, color: Color(0xFFFF6B00)),
              label: const Text('Refresh',
                  style: TextStyle(color: Color(0xFFFF6B00))),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      color: const Color(0xFFFF6B00),
      backgroundColor: const Color(0xFF1A1A1A),
      onRefresh: _loadFeed,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _feedPosts.length,
        itemBuilder: (context, i) => _buildFeedCard(_feedPosts[i]),
      ),
    );
  }

  Widget _buildFeedCard(Map<String, dynamic> post) {
    final worker = post['profiles'] as Map<String, dynamic>?;
    final workerName = worker?['name'] ?? 'Worker';
    final workerSkill = worker?['skill'] ?? '';
    final avatarUrl = worker?['avatar_url'];
    final likesCount = post['likes_count'] ?? 0;
    final commentsCount = post['comments_count'] ?? 0;
    final isMyPost = worker?['id'] == _profile?['id'];

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => PostDetailScreen(post: post)),
      ).then((_) => _loadFeed()),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isMyPost
                ? const Color(0xFFFF6B00).withOpacity(0.3)
                : const Color(0xFF2A2A2A),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor:
                        const Color(0xFFFF6B00).withOpacity(0.15),
                    backgroundImage: avatarUrl != null
                        ? NetworkImage(avatarUrl)
                        : null,
                    child: avatarUrl == null
                        ? Text(workerName[0].toUpperCase(),
                            style: const TextStyle(
                                color: Color(0xFFFF6B00),
                                fontWeight: FontWeight.w700))
                        : null,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(workerName,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13)),
                            if (isMyPost) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFF6B00)
                                      .withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text('You',
                                    style: TextStyle(
                                        color: Color(0xFFFF6B00),
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700)),
                              ),
                            ],
                          ],
                        ),
                        Text(workerSkill,
                            style: const TextStyle(
                                color: Color(0xFF888888), fontSize: 11)),
                      ],
                    ),
                  ),
                  if (post['skill'] != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF6B00).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(post['skill'],
                          style: const TextStyle(
                              color: Color(0xFFFF6B00),
                              fontSize: 10,
                              fontWeight: FontWeight.w600)),
                    ),
                ],
              ),
            ),

            // Image
            ClipRRect(
              child: Image.network(
                post['image_url'],
                width: double.infinity,
                height: 200,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  height: 200,
                  color: const Color(0xFF252525),
                  child: const Icon(Icons.image_not_supported,
                      color: Color(0xFF555555), size: 40),
                ),
              ),
            ),

            // Caption + actions
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (post['caption'] != null)
                    Text(post['caption'],
                        style: const TextStyle(
                            color: Color(0xFFCCCCCC), fontSize: 13),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.favorite_border_rounded,
                          color: Color(0xFF888888), size: 18),
                      const SizedBox(width: 4),
                      Text('$likesCount',
                          style: const TextStyle(
                              color: Color(0xFF888888), fontSize: 12)),
                      const SizedBox(width: 12),
                      const Icon(Icons.chat_bubble_outline,
                          color: Color(0xFF888888), size: 16),
                      const SizedBox(width: 4),
                      Text('$commentsCount',
                          style: const TextStyle(
                              color: Color(0xFF888888), fontSize: 12)),
                      const Spacer(),
                      const Text('Tap to view',
                          style: TextStyle(
                              color: Color(0xFF555555), fontSize: 11)),
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

  // ─── My Posts Tab ──────────────────────────────────────────────────────────
  Widget _buildMyPostsTab() {
    if (_myPosts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.grid_on,
                color: Color(0xFF555555), size: 48),
            const SizedBox(height: 12),
            const Text("You haven't posted yet",
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            const Text('Tap Share Work to post your first photo!',
                style: TextStyle(color: Color(0xFF888888), fontSize: 13)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: const Color(0xFFFF6B00),
      backgroundColor: const Color(0xFF1A1A1A),
      onRefresh: _loadMyPosts,
      child: CustomScrollView(
        slivers: [
          // Stats bar
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF2A2A2A)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildMiniStat(
                      '${_myPosts.length}', 'Posts'),
                  _buildStatDivider(),
                  _buildMiniStat(
                    '${_myPosts.fold(0, (sum, p) => sum + (p['likes_count'] as int? ?? 0))}',
                    'Total Likes',
                  ),
                  _buildStatDivider(),
                  _buildMiniStat(
                    '${_myPosts.fold(0, (sum, p) => sum + (p['comments_count'] as int? ?? 0))}',
                    'Comments',
                  ),
                ],
              ),
            ),
          ),

          // Grid
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverGrid(
              delegate: SliverChildBuilderDelegate(
                (context, i) => _buildMyPostThumbnail(_myPosts[i]),
                childCount: _myPosts.length,
              ),
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 3,
                mainAxisSpacing: 3,
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  Widget _buildMyPostThumbnail(Map<String, dynamic> post) {
    final likesCount = post['likes_count'] ?? 0;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => PostDetailScreen(post: post)),
      ).then((_) => _loadMyPosts()),
      onLongPress: () => _showDeleteDialog(post),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            post['image_url'],
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              color: const Color(0xFF1A1A1A),
              child: const Icon(Icons.image_not_supported,
                  color: Color(0xFF555555)),
            ),
          ),
          // Likes overlay
          Positioned(
            bottom: 4,
            left: 4,
            child: Row(
              children: [
                const Icon(Icons.favorite_rounded,
                    color: Colors.white, size: 12),
                const SizedBox(width: 2),
                Text('$likesCount',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        shadows: [
                          Shadow(color: Colors.black, blurRadius: 4)
                        ])),
              ],
            ),
          ),
          // Long press hint
          Positioned(
            top: 4,
            right: 4,
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: Colors.black45,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Icon(Icons.more_vert,
                  color: Colors.white, size: 13),
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(Map<String, dynamic> post) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFF2A2A2A),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            // Post preview
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(post['image_url'],
                  height: 80, width: 80, fit: BoxFit.cover),
            ),
            const SizedBox(height: 12),
            Text(
              post['caption'] ?? 'This post',
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 20),
            // View option
            ListTile(
              leading: const Icon(Icons.visibility_outlined,
                  color: Colors.white),
              title: const Text('View Post',
                  style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => PostDetailScreen(post: post)),
                ).then((_) => _loadMyPosts());
              },
            ),
            // Delete option
            ListTile(
              leading: const Icon(Icons.delete_outline,
                  color: Color(0xFFE53935)),
              title: const Text('Delete Post',
                  style: TextStyle(color: Color(0xFFE53935))),
              onTap: () async {
                Navigator.pop(ctx);
                await _deletePost(post['id']);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _deletePost(String postId) async {
    try {
      await PortfolioService.deletePost(postId);
      _loadMyPosts();
      _loadFeed();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Post deleted'),
          backgroundColor: const Color(0xFF4CAF50),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Failed to delete post'),
          backgroundColor: const Color(0xFFE53935),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  Widget _buildMiniStat(String value, String label) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800)),
        const SizedBox(height: 2),
        Text(label,
            style: const TextStyle(
                color: Color(0xFF888888), fontSize: 11)),
      ],
    );
  }

  Widget _buildStatDivider() =>
      Container(width: 1, height: 32, color: const Color(0xFF2A2A2A));

  Widget _buildHeader() {
    final name = _profile?['name'] ?? 'Worker';
    final skill = _profile?['skill'] ?? '';
    final rating = _profile?['rating'] ?? 0.0;
    final avatarUrl = _profile?['avatar_url'];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 20, 0),
      child: Row(
        children: [
          // Menu button
          GestureDetector(
            onTap: () => Scaffold.of(context).openDrawer(),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF2A2A2A)),
              ),
              child: const Icon(Icons.menu_rounded,
                  color: Colors.white, size: 20),
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFF6B00),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                  const Text('MoKa',
                      style: TextStyle(
                          color: Color(0xFFFF6B00),
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1)),
                ],
              ),
              Text(
                'Hey, $name 👷',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const Spacer(),
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProfileScreen()),
            ),
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: const Color(0xFF1A1A1A),
                  backgroundImage: avatarUrl != null
                      ? NetworkImage(avatarUrl)
                      : null,
                  child: avatarUrl == null
                      ? const Icon(Icons.person,
                          color: Color(0xFF888888), size: 20)
                      : null,
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: _isOnline
                          ? const Color(0xFF4CAF50)
                          : const Color(0xFF555555),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: const Color(0xFF0D0D0D), width: 2),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawer() {
    final name = _profile?['name'] ?? '';
    final email = AuthService.currentEmail ?? '';
    final skill = _profile?['skill'] ?? '';
    final rating = (_profile?['rating'] ?? 0.0).toDouble();
    final avatarUrl = _profile?['avatar_url'];

    return Drawer(
      backgroundColor: const Color(0xFF111111),
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                border: Border(
                    bottom: BorderSide(color: Color(0xFF1F1F1F))),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor:
                        const Color(0xFFFF6B00).withOpacity(0.15),
                    backgroundImage: avatarUrl != null
                        ? NetworkImage(avatarUrl)
                        : null,
                    child: avatarUrl == null
                        ? Text(
                            name.isNotEmpty ? name[0].toUpperCase() : '?',
                            style: const TextStyle(
                                color: Color(0xFFFF6B00),
                                fontSize: 22,
                                fontWeight: FontWeight.w800))
                        : null,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 16)),
                        Text(email,
                            style: const TextStyle(
                                color: Color(0xFF888888), fontSize: 12),
                            overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF6B00)
                                    .withOpacity(0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                skill.isNotEmpty ? skill : 'Worker',
                                style: const TextStyle(
                                    color: Color(0xFFFF6B00),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700),
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Icon(Icons.star_rounded,
                                color: Color(0xFFFF6B00), size: 12),
                            const SizedBox(width: 2),
                            Text(rating.toStringAsFixed(1),
                                style: const TextStyle(
                                    color: Color(0xFFFF6B00),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // App branding
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF6B00),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.handyman_rounded,
                        color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 10),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('MoKa',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 16)),
                      Text('Workers On Demand',
                          style: TextStyle(
                              color: Color(0xFF888888), fontSize: 10)),
                    ],
                  ),
                ],
              ),
            ),

            const Divider(color: Color(0xFF1F1F1F)),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  _drawerItem(Icons.home_outlined, 'Home',
                      () => Navigator.pop(context)),
                  _drawerItem(Icons.work_outline, 'My Jobs', () {
                    Navigator.pop(context);
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const WorkerMyJobsScreen()));
                  }),
                  _drawerItem(Icons.chat_bubble_outline, 'Messages', () {
                    Navigator.pop(context);
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const MessagesScreen()));
                  }),
                  _drawerItem(Icons.photo_library_outlined, 'My Posts', () {
                    Navigator.pop(context);
                    _tabController.animateTo(2);
                  }),
                  _drawerItem(Icons.person_outline, 'My Profile', () {
                    Navigator.pop(context);
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const ProfileScreen()));
                  }),
                  const Divider(color: Color(0xFF1F1F1F)),
                  _drawerItem(
                      Icons.add_photo_alternate_outlined, 'Share Work', () {
                    Navigator.pop(context);
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                const CreatePortfolioPostScreen()));
                  }),
                  const Divider(color: Color(0xFF1F1F1F)),
                  _drawerItem(Icons.help_outline, 'Help & Support',
                      () => Navigator.pop(context)),
                  _drawerItem(Icons.description_outlined, 'Terms & Conditions',
                      () => Navigator.pop(context)),
                  _drawerItem(Icons.info_outline, 'About MoKa', () {
                    Navigator.pop(context);
                    showAboutDialog(
                      context: context,
                      applicationName: 'MoKa',
                      applicationVersion: '1.0.0',
                      applicationIcon: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF6B00),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.handyman_rounded,
                            color: Colors.white, size: 26),
                      ),
                    );
                  }),
                ],
              ),
            ),

            // Logout
            Container(
              decoration: const BoxDecoration(
                border:
                    Border(top: BorderSide(color: Color(0xFF1F1F1F))),
              ),
              child: _drawerItem(
                Icons.logout,
                'Log Out',
                () async {
                  Navigator.pop(context);
                  await AuthService.updateWorkerStatus(isOnline: false);
                  await AuthService.logout();
                  if (!mounted) return;
                  Navigator.pushReplacementNamed(context, '/login');
                },
                color: const Color(0xFFE53935),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _drawerItem(IconData icon, String label, VoidCallback onTap,
      {Color color = const Color(0xFFCCCCCC)}) {
    return ListTile(
      leading: Icon(icon, color: color, size: 20),
      title: Text(label,
          style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.w500)),
      onTap: onTap,
      dense: true,
      horizontalTitleGap: 8,
    );
  }

  Widget _buildOnlineToggle() {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isOnline
              ? const Color(0xFF4CAF50).withOpacity(0.4)
              : const Color(0xFF2A2A2A),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: _isOnline
                  ? const Color(0xFF4CAF50)
                  : const Color(0xFF555555),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isOnline ? 'You are Online' : 'You are Offline',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                Text(
                  _isOnline
                      ? 'Receiving job alerts nearby'
                      : 'Toggle on to receive job alerts',
                  style: const TextStyle(
                      color: Color(0xFF888888), fontSize: 12),
                ),
              ],
            ),
          ),
          Switch(
            value: _isOnline,
            onChanged: _toggleOnline,
            activeColor: const Color(0xFF4CAF50),
            inactiveThumbColor: const Color(0xFF555555),
            inactiveTrackColor: const Color(0xFF2A2A2A),
          ),
        ],
      ),
    );
  }

  Widget _buildJobList() {
    if (_isLoadingJobs) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFFF6B00)),
      );
    }

    if (_nearbyJobs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search_off_rounded,
                color: Color(0xFF555555), size: 48),
            const SizedBox(height: 12),
            const Text('No nearby jobs right now',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            const Text('Check back soon or wait for new alerts',
                style: TextStyle(color: Color(0xFF888888), fontSize: 13)),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: _loadNearbyJobs,
              icon: const Icon(Icons.refresh, color: Color(0xFFFF6B00)),
              label: const Text('Refresh',
                  style: TextStyle(color: Color(0xFFFF6B00))),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              const Text(
                'Nearby Jobs',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF6B00).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${_nearbyJobs.length} new',
                  style: const TextStyle(
                    color: Color(0xFFFF6B00),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: _nearbyJobs.length,
            itemBuilder: (context, i) {
              final job = _nearbyJobs[i];
              return GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => JobDetailScreen(job: job),
                  ),
                ),
                child: _buildJobAlert(job),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildJobAlert(Map<String, dynamic> job) {
    final urgency = job['urgency'] ?? 'normal';
    Color urgencyColor = const Color(0xFF4CAF50);
    String urgencyLabel = 'Normal';
    if (urgency == 'urgent') {
      urgencyColor = const Color(0xFFFF9800);
      urgencyLabel = 'Urgent';
    }
    if (urgency == 'emergency') {
      urgencyColor = const Color(0xFFF44336);
      urgencyLabel = 'Emergency';
    }

    final customer = job['profiles'];
    final customerName = customer?['name'] ?? 'Customer';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: urgency == 'emergency'
              ? const Color(0xFFF44336).withOpacity(0.4)
              : const Color(0xFF2A2A2A),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: urgencyColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(urgencyLabel,
                    style: TextStyle(
                        color: urgencyColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF252525),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(job['skill_needed'] ?? '',
                    style: const TextStyle(
                        color: Color(0xFF888888), fontSize: 11)),
              ),
              const Spacer(),
              Text(_timeAgo(job['created_at']),
                  style: const TextStyle(
                      color: Color(0xFF555555), fontSize: 11)),
            ],
          ),
          const SizedBox(height: 10),
          Text(job['title'] ?? '',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.location_on_outlined,
                  color: Color(0xFF888888), size: 14),
              const SizedBox(width: 4),
              Text('${_distanceLabel(job)} away',
                  style: const TextStyle(
                      color: Color(0xFF888888), fontSize: 12)),
              const SizedBox(width: 12),
              const Icon(Icons.person_outline,
                  color: Color(0xFF888888), size: 14),
              const SizedBox(width: 4),
              Text(customerName,
                  style: const TextStyle(
                      color: Color(0xFF888888), fontSize: 12)),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () =>
                      setState(() => _nearbyJobs.remove(job)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF888888),
                    side: const BorderSide(color: Color(0xFF2A2A2A)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  child: const Text('Decline',
                      style: TextStyle(fontSize: 13)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: () => _applyToJob(job['id']),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF6B00),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    elevation: 0,
                  ),
                  child: const Text('Apply for Job',
                      style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOfflineState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: const BoxDecoration(
              color: Color(0xFF1A1A1A),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.wifi_off_rounded,
                color: Color(0xFF555555), size: 36),
          ),
          const SizedBox(height: 16),
          const Text(
            'You\'re Offline',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Toggle online to start\nreceiving job alerts',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF888888), fontSize: 14),
          ),
        ],
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
              MaterialPageRoute(
                  builder: (_) => const WorkerMyJobsScreen()),
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
