import 'package:flutter/material.dart';
import '../services/leaderboard_service.dart';
import '../models/worker_medal.dart';
import '../widgets/worker_medal_badge.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen>
    with SingleTickerProviderStateMixin {
  final _service = LeaderboardService();

  List<LeaderboardWorker> _all = [];
  List<LeaderboardWorker> _filtered = [];
  bool _isLoading = true;
  late TabController _tabController;

  final List<_Tab> _tabs = [
    _Tab(label: 'All', medal: null),
    _Tab(label: 'Gold', medal: WorkerMedal.gold),
    _Tab(label: 'Silver', medal: WorkerMedal.silver),
    _Tab(label: 'Bronze', medal: WorkerMedal.bronze),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(_onTabChanged);
    _loadLeaderboard();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    _applyFilter(_tabs[_tabController.index].medal);
  }

  void _applyFilter(WorkerMedal? medal) {
    setState(() {
      _filtered = medal == null
          ? List.from(_all)
          : _all.where((w) => w.medal == medal).toList();
    });
  }

  Future<void> _loadLeaderboard() async {
    try {
      final workers = await _service.fetchLeaderboard();
      if (mounted) {
        setState(() {
          _all = workers;
          _filtered = List.from(workers);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load leaderboard: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      body: NestedScrollView(
        headerSliverBuilder: (context, _) => [
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              background: _buildHeader(),
            ),
            bottom: TabBar(
              controller: _tabController,
              isScrollable: true,
              indicatorColor: Theme.of(context).colorScheme.primary,
              labelColor: Theme.of(context).colorScheme.primary,
              unselectedLabelColor: Colors.grey,
              tabs: _tabs
                  .map((t) => Tab(text: t.label))
                  .toList(),
            ),
          ),
        ],
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _loadLeaderboard,
                child: _filtered.isEmpty
                    ? const Center(
                        child: Text('No workers in this category yet.'),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.only(top: 12, bottom: 24),
                        itemCount: _filtered.length,
                        itemBuilder: (context, index) {
                          final worker = _filtered[index];

                          // Top 3 get special podium cards
                          if (worker.rank <= 3 &&
                              _tabController.index == 0) {
                            return _PodiumCard(worker: worker);
                          }

                          return _LeaderboardRow(
                            worker: worker,
                            isCurrentUser: false,
                          );
                        },
                      ),
              ),
      ),
    );
  }

  Widget _buildHeader() {
    final goldCount =
        _all.where((w) => w.medal == WorkerMedal.gold).length;
    final silverCount =
        _all.where((w) => w.medal == WorkerMedal.silver).length;
    final bronzeCount =
        _all.where((w) => w.medal == WorkerMedal.bronze).length;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).colorScheme.primary,
            Theme.of(context).colorScheme.primary.withOpacity(0.7),
          ],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 48),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Leaderboard',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${_all.length} workers ranked',
                style: const TextStyle(
                    color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 16),

              // Medal counts row
              Row(
                children: [
                  _headerMedalStat('Gold', goldCount, 'Gold'),
                  const SizedBox(width: 12),
                  _headerMedalStat('Silver', silverCount, 'Silver'),
                  const SizedBox(width: 12),
                  _headerMedalStat('Bronze', bronzeCount, 'Bronze'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _headerMedalStat(String label, int count, String description) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$count',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              Text(
                description,
                style: const TextStyle(
                    color: Colors.white70, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Podium card for top 3 ─────────────────────────────────────
class _PodiumCard extends StatelessWidget {
  final LeaderboardWorker worker;

  const _PodiumCard({required this.worker});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            worker.medal.backgroundColor,
            worker.medal.accentColor.withOpacity(0.15),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: worker.medal.accentColor.withOpacity(0.5),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: worker.medal.accentColor.withOpacity(0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [

            // Rank number
            SizedBox(
              width: 32,
              child: Text(
                '#${worker.rank}',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: worker.medal.accentColor,
                ),
              ),
            ),
            const SizedBox(width: 8),

            // Avatar
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: worker.medal.accentColor,
                      width: 2.5,
                    ),
                  ),
                  child: ClipOval(
                    child: worker.avatarUrl != null
                        ? Image.network(worker.avatarUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                _defaultAvatar())
                        : _defaultAvatar(),
                  ),
                ),
                Positioned(
                  bottom: -4,
                  right: -4,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: worker.medal.accentColor, width: 1),
                    ),
                    child: Text(worker.medal.emoji,
                        style: const TextStyle(fontSize: 12)),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          worker.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (worker.isVerified) ...[
                        const SizedBox(width: 4),
                        const Icon(Icons.verified,
                            color: Colors.blue, size: 15),
                      ],
                    ],
                  ),
                  if (worker.jobTitle != null)
                    Text(
                      worker.jobTitle!,
                      style: const TextStyle(
                          color: Colors.grey, fontSize: 12),
                    ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.star_rounded,
                          size: 15, color: worker.medal.starColor),
                      const SizedBox(width: 3),
                      Text(
                        worker.rating.toStringAsFixed(1),
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: worker.medal.accentColor,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${worker.completedJobs} jobs',
                        style: const TextStyle(
                            color: Colors.grey, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Medal badge
            WorkerMedalBadge(medal: worker.medal, showLabel: true),
          ],
        ),
      ),
    );
  }

  Widget _defaultAvatar() => Container(
        color: Colors.grey.shade200,
        child: const Icon(Icons.person, color: Colors.grey, size: 28),
      );
}

// ── Regular leaderboard row ───────────────────────────────────
class _LeaderboardRow extends StatelessWidget {
  final LeaderboardWorker worker;
  final bool isCurrentUser;

  const _LeaderboardRow({
    required this.worker,
    required this.isCurrentUser,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 3, 16, 3),
      decoration: BoxDecoration(
        color: isCurrentUser
            ? Theme.of(context).colorScheme.primary.withOpacity(0.05)
            : worker.medal.backgroundColor.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCurrentUser
              ? Theme.of(context).colorScheme.primary.withOpacity(0.3)
              : worker.medal.accentColor.withOpacity(0.2),
        ),
      ),
      child: Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [

            // Rank
            SizedBox(
              width: 32,
              child: Text(
                '#${worker.rank}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: worker.medal.accentColor,
                ),
              ),
            ),

            // Avatar
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                    color: worker.medal.accentColor.withOpacity(0.5),
                    width: 1.5),
              ),
              child: ClipOval(
                child: worker.avatarUrl != null
                    ? Image.network(worker.avatarUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _defaultAvatar())
                    : _defaultAvatar(),
              ),
            ),
            const SizedBox(width: 12),

            // Name + rating
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          worker.name,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (worker.isVerified) ...[
                        const SizedBox(width: 4),
                        const Icon(Icons.verified,
                            color: Colors.blue, size: 14),
                      ],
                    ],
                  ),
                  Row(
                    children: [
                      Icon(Icons.star_rounded,
                          size: 13, color: worker.medal.starColor),
                      const SizedBox(width: 2),
                      Text(
                        worker.rating.toStringAsFixed(1),
                        style: TextStyle(
                          fontSize: 12,
                          color: worker.medal.accentColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '· ${worker.completedJobs} jobs',
                        style: const TextStyle(
                            color: Colors.grey, fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Medal badge
            Text(worker.medal.emoji,
                style: const TextStyle(fontSize: 20)),
          ],
        ),
      ),
    );
  }

  Widget _defaultAvatar() => Container(
        color: Colors.grey.shade200,
        child:
            const Icon(Icons.person, color: Colors.grey, size: 22),
      );
}

// ── Internal tab model ────────────────────────────────────────
class _Tab {
  final String label;
  final WorkerMedal? medal;

  const _Tab({required this.label, required this.medal});
}