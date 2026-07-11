 import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

class JobService {
  // ── Post a new job ────────────────────────────────────────────
  // Updated to support category, address, radius, and photos
  static Future<Map<String, dynamic>> postJob({
    required String title,
    required String description,
    required String skillNeeded,
    required String urgency,
    required double lat,
    required double lng,
    double budget = 0,
    String? categoryId,
    String? address,
    double radiusKm = 10,
    List<String> photoUrls = const [],
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
      'budget': budget,
      'status': 'open',
      if (categoryId != null) 'category_id': categoryId,
      if (address != null) 'address': address,
      'radius_km': radiusKm,
      if (photoUrls.isNotEmpty) 'photos': photoUrls,
    }).select().single();

    return response;
  }

  // ── Get nearby jobs by skill within radius ────────────────────
  static Future<List<Map<String, dynamic>>> getNearbyJobs({
    required String skill,
    required double lat,
    required double lng,
    double radiusKm = 10,
  }) async {
    final response = await supabase
        .from('jobs')
        .select('*, profiles!customer_id(name, phone)')
        .eq('status', 'open')
        .eq('skill_needed', skill)
        .order('created_at', ascending: false);

    final jobs = List<Map<String, dynamic>>.from(response);

    return jobs.where((job) {
      final jobLat = job['lat'];
      final jobLng = job['lng'];
      if (jobLat == null || jobLng == null) return false;

      final distance = _calculateDistance(
        lat,
        lng,
        (jobLat as num).toDouble(),
        (jobLng as num).toDouble(),
      );

      // Use job's own radius if available, else use passed radiusKm
      final jobRadius =
          (job['radius_km'] as num?)?.toDouble() ?? radiusKm;
      return distance <= jobRadius;
    }).toList();
  }

  // ── Get customer's own jobs ───────────────────────────────────
  static Future<List<Map<String, dynamic>>> getMyJobs() async {
    final user = supabase.auth.currentUser;
    if (user == null) return [];

    final response = await supabase
        .from('jobs')
        .select('*, job_applications(count)')
        .eq('customer_id', user.id)
        .inFilter('status',
            ['open', 'accepted', 'completed', 'expired'])
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  // ── Get applicants for a job ──────────────────────────────────
  // Updated to include ratings table for medal calculation
  static Future<List<Map<String, dynamic>>> getJobApplicants(
      String jobId) async {
    final response = await supabase
        .from('job_applications')
        .select('''
          id,
          status,
          created_at,
          worker_id,
          profiles!worker_id(
            id,
            name,
            phone,
            skill,
            rating,
            avatar_url,
            is_online,
            jobs_completed,
            is_verified
          ),
          ratings!worker_id(
            average_rating
          )
        ''')
        .eq('job_id', jobId)
        .order('created_at', ascending: true);

    final applicants =
        List<Map<String, dynamic>>.from(response);

    // Merge average_rating into profiles for easy access
    return applicants.map((app) {
      final ratings = app['ratings'];
      double? avgRating;

      if (ratings is List && ratings.isNotEmpty) {
        avgRating =
            (ratings.first['average_rating'] as num?)?.toDouble();
      } else if (ratings is Map) {
        avgRating =
            (ratings['average_rating'] as num?)?.toDouble();
      }

      // Merge rating into profiles map
      final profile =
          Map<String, dynamic>.from(app['profiles'] ?? {});
      if (avgRating != null) {
        profile['rating'] = avgRating;
      }

      return {
        ...app,
        'profiles': profile,
      };
    }).toList();
  }

  // ── Worker applies to a job ───────────────────────────────────
  static Future<void> applyToJob(String jobId) async {
    final user = supabase.auth.currentUser;
    if (user == null) throw Exception('Not logged in');

    // Check duplicate
    final existing = await supabase
        .from('job_applications')
        .select('id')
        .eq('job_id', jobId)
        .eq('worker_id', user.id)
        .maybeSingle();

    if (existing != null) {
      throw Exception('You have already applied to this job');
    }

    // Check job is still open
    final job = await supabase
        .from('jobs')
        .select('status')
        .eq('id', jobId)
        .single();

    if (job['status'] != 'open') {
      throw Exception('This job is no longer available');
    }

    await supabase.from('job_applications').insert({
      'job_id': jobId,
      'worker_id': user.id,
      'status': 'pending',
    });
  }

  // ── Customer accepts a specific worker ────────────────────────
  // Updated to work with acceptance fee flow —
  // actual status update now handled by AcceptanceFeeService
  // after payment is confirmed. This method is kept for
  // direct acceptance without payment (e.g. admin override).
  static Future<void> acceptWorker({
    required String jobId,
    required String workerId,
    required String applicationId,
  }) async {
    final user = supabase.auth.currentUser;
    if (user == null) throw Exception('Not logged in');

    // Mark this application as accepted
    await supabase
        .from('job_applications')
        .update({'status': 'accepted'})
        .eq('id', applicationId);

    // Decline all other applications for this job
    await supabase
        .from('job_applications')
        .update({'status': 'declined'})
        .eq('job_id', jobId)
        .neq('id', applicationId);

    // Update job to active + store accepted worker
    await supabase.from('jobs').update({
      'status': 'accepted',
      'accepted_worker_id': workerId,
    }).eq('id', jobId);

    // Create conversation between customer and worker
    await supabase.from('conversations').insert({
      'job_id': jobId,
      'customer_id': user.id,
      'worker_id': workerId,
    });
  }

  // ── Customer marks job as complete ────────────────────────────
  static Future<void> completeJob(String jobId) async {
    await supabase
        .from('jobs')
        .update({'status': 'completed'}).eq('id', jobId);

    // Increment jobs_completed for the accepted worker
    final job = await supabase
        .from('jobs')
        .select('accepted_worker_id')
        .eq('id', jobId)
        .maybeSingle();

    final workerId = job?['accepted_worker_id'];
    if (workerId != null) {
      await supabase.rpc('increment_jobs_completed',
          params: {'worker_id': workerId});
    }
  }

  // ── Fetch customer's job radius from settings ─────────────────
  static Future<double> getCustomerRadius() async {
    final user = supabase.auth.currentUser;
    if (user == null) return 10.0;

    final data = await supabase
        .from('user_settings')
        .select('job_radius_km')
        .eq('user_id', user.id)
        .maybeSingle();

    return (data?['job_radius_km'] ?? 10.0).toDouble();
  }

  // ── Public distance helper ────────────────────────────────────
  static double distanceBetween(
      double lat1, double lng1, double lat2, double lng2) {
    return _calculateDistance(lat1, lng1, lat2, lng2);
  }

  // ── Haversine formula ─────────────────────────────────────────
  static double _calculateDistance(
      double lat1, double lng1, double lat2, double lng2) {
    const earthRadius = 6371.0;
    final dLat = _toRad(lat2 - lat1);
    final dLng = _toRad(lng2 - lng1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRad(lat1)) *
            cos(_toRad(lat2)) *
            sin(dLng / 2) *
            sin(dLng / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  static double _toRad(double deg) =>
      deg * 3.141592653589793 / 180;
}