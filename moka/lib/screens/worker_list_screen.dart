import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'worker_profile_card.dart';
import 'worker_medal.dart';

class WorkerListScreen extends StatefulWidget {
  const WorkerListScreen({super.key});

  @override
  State<WorkerListScreen> createState() => _WorkerListScreenState();
}

class _WorkerListScreenState extends State<WorkerListScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _workers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadWorkers();
  }

  Future<void> _loadWorkers() async {
    try {
      // Join users with ratings in one query
      final data = await _supabase
          .from('users')
          .select('''
            id,
            display_name,
            avatar_url,
            job_title,
            is_verified,
            ratings (
              average_rating
            )
          ''')
          .eq('user_role', 'worker')
          .order('created_at', ascending: false);

      if (mounted) setState(() => _workers = List<Map<String, dynamic>>.from(data));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load workers: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  double? _extractRating(Map<String, dynamic> worker) {
    final ratings = worker['ratings'];
    if (ratings == null) return null;
    if (ratings is List && ratings.isNotEmpty) {
      return (ratings.first['average_rating'] as num?)?.toDouble();
    }
    if (ratings is Map) {
      return (ratings['average_rating'] as num?)?.toDouble();
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Workers'),
        actions: [
          // Medal legend button
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => _showMedalLegend(context),
          ),
        ],
      ),
      body: _workers.isEmpty
          ? const Center(child: Text('No workers found.'))
          : RefreshIndicator(
              onRefresh: _loadWorkers,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: _workers.length,
                itemBuilder: (context, index) {
                  final worker = _workers[index];
                  final rating = _extractRating(worker);

                  return WorkerProfileCard(
                    workerId: worker['id'],
                    name: worker['display_name'] ?? 'Unknown',
                    avatarUrl: worker['avatar_url'],
                    jobTitle: worker['job_title'],
                    rating: rating,
                    isVerified: worker['is_verified'] ?? false,
                    onTap: () {
                      // Navigate to worker profile
                      // Navigator.push(context, MaterialPageRoute(
                      //   builder: (_) => WorkerProfileScreen(userId: worker['id']),
                      // ));
                    },
                  );
                },
              ),
            ),
    );
  }

  void _showMedalLegend(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Worker Medal System',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text(
              'Medals are awarded based on a worker\'s average star rating.',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 20),
            _legendRow(WorkerMedal.gold, '4.4 and above', '⭐⭐⭐⭐⭐'),
            const SizedBox(height: 12),
            _legendRow(WorkerMedal.silver, '2.6 — 4.3', '⭐⭐⭐'),
            const SizedBox(height: 12),
            _legendRow(WorkerMedal.bronze, '2.5 and below', '⭐'),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _legendRow(WorkerMedal medal, String range, String stars) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: medal.backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: medal.accentColor.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          Text(medal.emoji, style: const TextStyle(fontSize: 28)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${medal.label} Medal',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: medal.accentColor,
                  ),
                ),
                Text(
                  range,
                  style:
                      const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ),
          Text(stars),
        ],
      ),
    );
  }
}