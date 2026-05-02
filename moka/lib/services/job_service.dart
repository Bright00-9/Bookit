import 'supabase_service.dart';

class JobService {
  // Post a new job
  static Future<Map<String, dynamic>> postJob({
    required String title,
    required String description,
    required String skillNeeded,
    required String urgency,
    required double lat,
    required double lng,
  }) async {
    final user = supabase.auth.currentUser;
    if (user == null) throw Exception('Not logged in');

    final response = await supabase.from('jobs').insert({
      'customer_id': user.id,
      'title': title,
      'description': description,
      'skill_needed': skillNeeded,
      'urgency': urgency,
      'lat': lat,
      'lng': lng,
      'status': 'open',
    }).select().single();

    return response;
  }

  // Get all open jobs (for workers)
  static Future<List<Map<String, dynamic>>> getOpenJobs() async {
    final response = await supabase
        .from('jobs')
        .select('*, profiles!customer_id(name, phone)')
        .eq('status', 'open')
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  // Get nearby jobs by skill within radius (km)
  static Future<List<Map<String, dynamic>>> getNearbyJobs({
    required String skill,
    required double lat,
    required double lng,
    double radiusKm = 10,
  }) async {
    // Fetch open jobs matching skill
    final response = await supabase
        .from('jobs')
        .select('*, profiles!customer_id(name, phone)')
        .eq('status', 'open')
        .eq('skill_needed', skill)
        .order('created_at', ascending: false);

    final jobs = List<Map<String, dynamic>>.from(response);

    // Filter by distance
    return jobs.where((job) {
      final distance = _calculateDistance(
        lat, lng,
        job['lat'] as double,
        job['lng'] as double,
      );
      return distance <= radiusKm;
    }).toList();
  }

  // Get customer's own jobs
  static Future<List<Map<String, dynamic>>> getMyJobs() async {
    final user = supabase.auth.currentUser;
    if (user == null) return [];

    final response = await supabase
        .from('jobs')
        .select('*, job_applications(count)')
        .eq('customer_id', user.id)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  // Apply to a job (worker accepts)
  static Future<void> applyToJob(String jobId) async {
    final user = supabase.auth.currentUser;
    if (user == null) throw Exception('Not logged in');

    await supabase.from('job_applications').insert({
      'job_id': jobId,
      'worker_id': user.id,
      'status': 'pending',
    });

    // Update job status to accepted
    await supabase
        .from('jobs')
        .update({'status': 'accepted'}).eq('id', jobId);
  }

  // Complete a job
  static Future<void> completeJob(String jobId) async {
    await supabase
        .from('jobs')
        .update({'status': 'completed'}).eq('id', jobId);
  }

  // Public distance helper (used by UI)
  static double distanceBetween(
      double lat1, double lng1, double lat2, double lng2) {
    return _calculateDistance(lat1, lng1, lat2, lng2);
  }

  // Haversine distance formula (returns km)
  static double _calculateDistance(
      double lat1, double lng1, double lat2, double lng2) {
    const earthRadius = 6371.0;
    final dLat = _toRad(lat2 - lat1);
    final dLng = _toRad(lng2 - lng1);
    final a = (dLat / 2) * (dLat / 2) +
        _toRad(lat1) *
            _toRad(lat2) *
            (dLng / 2) *
            (dLng / 2);
    final c = 2 * (a < 1 ? a : 1);
    return earthRadius * c;
  }

  static double _toRad(double deg) => deg * 3.141592653589793 / 180;
}
