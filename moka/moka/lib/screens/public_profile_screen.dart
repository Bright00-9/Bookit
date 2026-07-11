 import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/portfolio_service.dart';
import '../services/resume_service.dart';
import '../models/resume_model.dart';
import '../models/worker_medal.dart';
import '../widgets/resume_view_widget.dart';
import 'worker_reviews_screen.dart';
import 'post_detail_screen.dart';
import 'chat_screen.dart';

class PublicProfileScreen extends StatefulWidget {
  final String userId;

  const PublicProfileScreen({super.key, required this.userId});

  @override
  State<PublicProfileScreen> createState() => _PublicProfileScreenState();
}

class _PublicProfileScreenState extends State<PublicProfileScreen> {
  Map<String, dynamic>? _profile;
  List<Map<String, dynamic>> _posts = [];
  ResumeModel? _resume;
  bool _isLoading = true;
  bool _showResume = false;

  final _supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _startChat() async {
    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId == null) return;
      if (currentUserId == widget.userId) return;

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Opening chat...'),
          duration: Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
        ),
      );

      final existing = await _supabase
          .from('conversations')
          .select('id')
          .or(
            'and(customer_id.eq.$currentUserId,worker_id.eq.${widget.userId}),'
            'and(customer_id.eq.${widget.userId},worker_id.eq.$currentUserId)',
          )
          .maybeSingle();

      if (existing != null) {
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatScreen(
              conversationId: existing['id'],
              jobTitle: 'Direct Message',
            ),
          ),
        );
        return;
      }

      final myProfile = await _supabase
          .from('profiles')
          .select('role')
          .eq('id', currentUserId)
          .single();

      final myRole = myProfile['role'];
      final isCustomer = myRole == 'customer';

      final conv = await _supabase
          .from('conversations')
          .insert({
            'job_id': null,
            'customer_id': isCustomer ? currentUserId : widget.userId,
            'worker_id': isCustomer ? widget.userId : currentUserId,
          })
          .select('id')
          .single();

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            conversationId: conv['id'],
            jobTitle: 'Direct Message',
          ),
        ),
      );
    } catch (e) {
      debugPrint('Chat error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().contains('null')
                ? 'Run direct_message_update.sql in Supabase first'
                : 'Could not start chat. Try again.',
          ),
          backgroundColor: const Color(0xFFE53935),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    try {
      final profileData =
          await PortfolioService.getPublicProfile(widget.userId);
      final posts = profileData['role'] == 'worker'
          ? await PortfolioService.getWorkerPosts(widget.userId)
          : [];

      // Load resume for workers
      ResumeModel? resume;
      if (profileData['role'] == 'worker') {
        try {
          resume =
              await ResumeService().fetchResumeByUserId(widget.userId);
        } catch (_) {}
      }

      if (mounted) {
        setState(() {
          _profile = profileData;
          _posts = List<Map<String, dynamic>>.from(posts);
          _resume = resume;
        });
      }
    } catch (e) {
      debugPrint('Error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWorker = _profile?['role'] == 'worker';

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: _isLoading
          ? const Center(
              child:
                  CircularProgressIndicator(color: Color(0xFFFF6B00)))
          : CustomScrollView(
              slivers: [
                _buildSliverAppBar(),
                SliverToBoxAdapter(
                    child: _buildProfileInfo(isWorker)),
                if (isWorker) ...[
                  SliverToBoxAdapter(child: _buildStatsRow()),
                  // Medal section
                  SliverToBoxAdapter(child: _buildMedalSection()),
                  // Resume section
                  SliverToBoxAdapter(child: _buildResumeSection()),
                  SliverToBoxAdapter(
                      child: _buildPortfolioHeader()),
                  _posts.isEmpty
                      ? SliverToBoxAdapter(
                          child: _buildEmptyPortfolio())
                      : SliverGrid(
                          delegate: SliverChildBuilderDelegate(
                            (context, i) =>
                                _buildPostThumbnail(_posts[i]),
                            childCount: _posts.length,
                          ),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 2,
                            mainAxisSpacing: 2,
                          ),
                        ),
                ],
              ],
            ),
    );
  }

  // ─── Sliver App Bar ───────────────────────────────────────────
  Widget _buildSliverAppBar() {
    final name = _profile?['name'] ?? '';
    final avatarUrl = _profile?['avatar_url'];
    final rating = (_profile?['rating'] ?? 0.0).toDouble();
    final isWorker = _profile?['role'] == 'worker';
    final medal =
        isWorker && rating > 0 ? getMedal(rating) : null;

    return SliverAppBar(
      backgroundColor: const Color(0xFF0D0D0D),
      expandedHeight: 200,
      pinned: true,
      leading: IconButton(
        onPressed: () => Navigator.pop(context),
        icon: const Icon(Icons.arrow_back_ios_new,
            color: Colors.white, size: 20),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1A1A1A), Color(0xFF0D0D0D)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 40),
              Stack(
                clipBehavior: Clip.none,
                children: [
                  // Avatar with medal ring color
                  CircleAvatar(
                    radius: 42,
                    backgroundColor: medal != null
                        ? medal.accentColor.withOpacity(0.2)
                        : const Color(0xFFFF6B00).withOpacity(0.15),
                    backgroundImage: avatarUrl != null
                        ? NetworkImage(avatarUrl)
                        : null,
                    child: avatarUrl == null
                        ? Text(
                            name.isNotEmpty
                                ? name[0].toUpperCase()
                                : '?',
                            style: TextStyle(
                              color: medal?.accentColor ??
                                  const Color(0xFFFF6B00),
                              fontSize: 32,
                              fontWeight: FontWeight.w800,
                            ),
                          )
                        : null,
                  ),

                  // Medal badge on avatar
                  if (medal != null)
                    Positioned(
                      bottom: -4,
                      right: -4,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0D0D0D),
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: medal.accentColor, width: 1.5),
                        ),
                        child: Text(medal.emoji,
                            style: const TextStyle(fontSize: 14)),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Profile Info ─────────────────────────────────────────────
  Widget _buildProfileInfo(bool isWorker) {
    final name = _profile?['name'] ?? '';
    final skill = _profile?['skill'] ?? '';
    final rating = (_profile?['rating'] ?? 0.0).toDouble();
    final phone = _profile?['phone'] ?? '';
    final medal = isWorker && rating > 0 ? getMedal(rating) : null;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Text(name,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF6B00).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isWorker ? '👷 Worker' : '👤 Customer',
                  style: const TextStyle(
                      color: Color(0xFFFF6B00),
                      fontSize: 12,
                      fontWeight: FontWeight.w600),
                ),
              ),
              if (isWorker && skill.isNotEmpty) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A1A),
                    borderRadius: BorderRadius.circular(8),
                    border:
                        Border.all(color: const Color(0xFF2A2A2A)),
                  ),
                  child: Text(skill,
                      style: const TextStyle(
                          color: Color(0xFF888888), fontSize: 12)),
                ),
              ],

              // Medal badge next to role
              if (medal != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: medal.backgroundColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: medal.accentColor.withOpacity(0.5)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(medal.emoji,
                          style: const TextStyle(fontSize: 11)),
                      const SizedBox(width: 4),
                      Text(
                        medal.label,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: medal.accentColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          if (isWorker) ...[
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => WorkerReviewsScreen(
                    workerId: widget.userId,
                    workerName: name,
                    rating: rating,
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ...List.generate(
                    5,
                    (i) => Icon(
                      Icons.star_rounded,
                      color: i < rating.round()
                          ? (medal?.starColor ??
                              const Color(0xFFFF6B00))
                          : const Color(0xFF333333),
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    rating.toStringAsFixed(1),
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14),
                  ),
                  const SizedBox(width: 4),
                  const Text('· See reviews',
                      style: TextStyle(
                          color: Color(0xFFFF6B00), fontSize: 13)),
                ],
              ),
            ),
          ],
          if (phone.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.phone_outlined,
                    color: Color(0xFF888888), size: 14),
                const SizedBox(width: 4),
                Text(phone,
                    style: const TextStyle(
                        color: Color(0xFF888888), fontSize: 13)),
              ],
            ),
          ],
          const SizedBox(height: 16),
          if (_supabase.auth.currentUser?.id != widget.userId)
            SizedBox(
              width: 180,
              child: ElevatedButton.icon(
                onPressed: _startChat,
                icon: const Icon(Icons.chat_bubble_outline,
                    size: 16),
                label: const Text('Send Message'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF6B00),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  elevation: 0,
                  textStyle: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 13),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ─── Medal Section ────────────────────────────────────────────
  Widget _buildMedalSection() {
    final rating = (_profile?['rating'] ?? 0.0).toDouble();
    if (rating <= 0) return const SizedBox.shrink();

    final medal = getMedal(rating);

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        // Subtle dark tint using medal background color
        color: Color.lerp(
            const Color(0xFF1A1A1A), medal.backgroundColor, 0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: medal.accentColor.withOpacity(0.3), width: 1.5),
      ),
      child: Row(
        children: [
          // Large medal emoji
          Text(medal.emoji, style: const TextStyle(fontSize: 36)),
          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${medal.label} Worker',
                  style: TextStyle(
                    color: medal.accentColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _medalDescription(medal),
                  style: const TextStyle(
                      color: Color(0xFF888888),
                      fontSize: 12,
                      height: 1.4),
                ),
              ],
            ),
          ),

          // Rating pill
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: medal.accentColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: medal.accentColor.withOpacity(0.4)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.star_rounded,
                    color: medal.starColor, size: 14),
                const SizedBox(width: 3),
                Text(
                  rating.toStringAsFixed(1),
                  style: TextStyle(
                    color: medal.accentColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _medalDescription(WorkerMedal medal) {
    switch (medal) {
      case WorkerMedal.gold:
        return 'Top-rated worker with consistently excellent service and outstanding customer satisfaction.';
      case WorkerMedal.silver:
        return 'Reliable worker with a good track record and positive customer feedback.';
      case WorkerMedal.bronze:
        return 'Worker is building their reputation. Check reviews before hiring.';
    }
  }

  // ─── Resume Section ───────────────────────────────────────────
  Widget _buildResumeSection() {
    // Don't show if no resume and viewing own profile
    if (_resume == null &&
        _supabase.auth.currentUser?.id == widget.userId) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row with toggle
          GestureDetector(
            onTap: () =>
                setState(() => _showResume = !_showResume),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Resume',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700)),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _resume != null
                            ? const Color(0xFF4CAF50).withOpacity(0.15)
                            : const Color(0xFF888888).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _resume != null ? 'Available' : 'Not added',
                        style: TextStyle(
                          fontSize: 11,
                          color: _resume != null
                              ? const Color(0xFF4CAF50)
                              : const Color(0xFF888888),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      _showResume
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      color: const Color(0xFF888888),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Resume content — collapsible
          if (_showResume) ...[
            const SizedBox(height: 12),
            if (_resume == null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: const Color(0xFF2A2A2A)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline,
                        color: Color(0xFF888888), size: 16),
                    SizedBox(width: 8),
                    Text('No resume added yet.',
                        style: TextStyle(
                            color: Color(0xFF888888),
                            fontSize: 13)),
                  ],
                ),
              )
            else
              // Dark-themed wrapper for ResumeViewWidget
              Theme(
                data: Theme.of(context).copyWith(
                  colorScheme: Theme.of(context).colorScheme.copyWith(
                        primary: const Color(0xFFFF6B00),
                      ),
                  cardColor: const Color(0xFF1A1A1A),
                  textTheme: Theme.of(context).textTheme.apply(
                        bodyColor: Colors.white,
                        displayColor: Colors.white,
                      ),
                  chipTheme: ChipThemeData(
                    backgroundColor: const Color(0xFF2A2A2A),
                    labelStyle:
                        const TextStyle(color: Colors.white),
                    side: const BorderSide(
                        color: Color(0xFF3A3A3A)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  iconTheme: const IconThemeData(
                      color: Color(0xFF888888)),
                  dividerColor: const Color(0xFF2A2A2A),
                ),
                child: ResumeViewWidget(userId: widget.userId),
              ),
          ],
        ],
      ),
    );
  }

  // ─── Stats Row ────────────────────────────────────────────────
  Widget _buildStatsRow() {
    final jobsDone = _profile?['job_applications_count'] ?? 0;
    final postsCount = _posts.length;
    final rating = (_profile?['rating'] ?? 0.0).toDouble();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStat('$postsCount', 'Posts'),
          _buildStatDivider(),
          _buildStat('$jobsDone', 'Jobs Done'),
          _buildStatDivider(),
          _buildStat(rating.toStringAsFixed(1), 'Rating'),
        ],
      ),
    );
  }

  Widget _buildStat(String value, String label) {
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
                color: Color(0xFF888888), fontSize: 12)),
      ],
    );
  }

  Widget _buildStatDivider() {
    return Container(
        width: 1, height: 32, color: const Color(0xFF2A2A2A));
  }

  Widget _buildPortfolioHeader() {
    return const Padding(
      padding: EdgeInsets.fromLTRB(20, 24, 20, 12),
      child: Text('Portfolio',
          style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700)),
    );
  }

  Widget _buildPostThumbnail(Map<String, dynamic> post) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => PostDetailScreen(post: post)),
      ),
      child: Image.network(
        post['image_url'],
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          color: const Color(0xFF1A1A1A),
          child: const Icon(Icons.image_not_supported,
              color: Color(0xFF555555)),
        ),
      ),
    );
  }

  Widget _buildEmptyPortfolio() {
    return const Padding(
      padding: EdgeInsets.all(40),
      child: Column(
        children: [
          Icon(Icons.photo_library_outlined,
              color: Color(0xFF555555), size: 48),
          SizedBox(height: 12),
          Text('No posts yet',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600)),
          SizedBox(height: 6),
          Text('This worker hasn\'t shared any work yet',
              style: TextStyle(
                  color: Color(0xFF888888), fontSize: 13)),
        ],
      ),
    );
  }
}