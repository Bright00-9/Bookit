import 'package:supabase_flutter/supabase_flutter.dart';
import 'worker_medal.dart';

class LeaderboardWorker {
  final String workerId;
  final String name;
  final String? avatarUrl;
  final String? jobTitle;
  final bool isVerified;
  final double rating;
  final int completedJobs;
  final WorkerMedal medal;
  final int rank;

  LeaderboardWorker({
    required this.workerId,
    required this.name,
    this.avatarUrl,
    this.jobTitle,
    required this.isVerified,
    required this.rating,
    required this.completedJobs,
    required this.medal,
    required this.rank,
  });
}

class LeaderboardService {
  final _supabase = Supabase.instance.client;

  Future<List<LeaderboardWorker>> fetchLeaderboard() async {
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
          ),
          jobs_completed
        ''')
        .eq('user_role', 'worker')
        .not('ratings', 'is', null)
        .order('created_at', ascending: false);

    final workers = <LeaderboardWorker>[];

    for (final row in data) {
      final ratings = row['ratings'];
      double? rating;

      if (ratings is List && ratings.isNotEmpty) {
        rating = (ratings.first['average_rating'] as num?)?.toDouble();
      } else if (ratings is Map) {
        rating = (ratings['average_rating'] as num?)?.toDouble();
      }

      if (rating == null) continue;

      workers.add(LeaderboardWorker(
        workerId: row['id'],
        name: row['display_name'] ?? 'Unknown',
        avatarUrl: row['avatar_url'],
        jobTitle: row['job_title'],
        isVerified: row['is_verified'] ?? false,
        rating: rating,
        completedJobs: row['jobs_completed'] ?? 0,
        medal: getMedal(rating),
        rank: 0, // assigned below after sorting
      ));
    }

    // Sort: gold first, then silver, then bronze, then by rating desc
    workers.sort((a, b) {
      final medalOrder = {
        WorkerMedal.gold: 0,
        WorkerMedal.silver: 1,
        WorkerMedal.bronze: 2,
      };
      final medalCompare =
          medalOrder[a.medal]!.compareTo(medalOrder[b.medal]!);
      if (medalCompare != 0) return medalCompare;
      return b.rating.compareTo(a.rating);
    });

    // Assign ranks
    return workers
        .asMap()
        .entries
        .map((e) => LeaderboardWorker(
              workerId: e.value.workerId,
              name: e.value.name,
              avatarUrl: e.value.avatarUrl,
              jobTitle: e.value.jobTitle,
              isVerified: e.value.isVerified,
              rating: e.value.rating,
              completedJobs: e.value.completedJobs,
              medal: e.value.medal,
              rank: e.key + 1,
            ))
        .toList();
  }
}