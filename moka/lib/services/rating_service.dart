import 'supabase_service.dart';

class RatingService {
  // Submit a rating
  static Future<void> submitRating({
    required String jobId,
    required String workerId,
    required int stars,
    required String review,
  }) async {
    final user = supabase.auth.currentUser;
    if (user == null) throw Exception('Not logged in');

    await supabase.from('ratings').insert({
      'job_id': jobId,
      'customer_id': user.id,
      'worker_id': workerId,
      'stars': stars,
      'review': review,
    });

    // Mark job as completed
    await supabase
        .from('jobs')
        .update({'status': 'completed'})
        .eq('id', jobId);
  }

  // Check if a job has already been rated
  static Future<bool> hasRated(String jobId) async {
    final data = await supabase
        .from('ratings')
        .select('id')
        .eq('job_id', jobId)
        .maybeSingle();
    return data != null;
  }

  // Get all ratings for a worker
  static Future<List<Map<String, dynamic>>> getWorkerRatings(
      String workerId) async {
    final data = await supabase
        .from('ratings')
        .select('*, profiles!customer_id(name)')
        .eq('worker_id', workerId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(data);
  }

  // Get rating for a specific job
  static Future<Map<String, dynamic>?> getJobRating(String jobId) async {
    final data = await supabase
        .from('ratings')
        .select('*')
        .eq('job_id', jobId)
        .maybeSingle();
    return data;
  }
}
