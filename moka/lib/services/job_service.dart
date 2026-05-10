import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';
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
    double budget = 0,
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
    }).select().single();

    return response;
  }

  // Get nearby jobs by skill within radius (km)
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
      final distance = _calculateDistance(
        lat, lng,
        (job['lat'] as num).toDouble(),
        (job['lng'] as num).toDouble(),
      );
      return distance <= radiusKm;
    }).toList();
  }

  // Get customer's own jobs (all statuses including expired)
  static Future<List<Map<String, dynamic>>> getMyJobs() async {
    final user = supabase.auth.currentUser;
    if (user == null) return [];

    final response = await supabase
        .from('jobs')
        .select('*, job_applications(count)')
        .eq('customer_id', user.id)
        .inFilter('status', ['open', 'accepted', 'completed', 'expired'])
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  // Get applicants for a job (customer reviews who applied)
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
            id, name, phone, skill, rating, avatar_url, is_online
          )
        ''')
        .eq('job_id', jobId)
        .order('created_at', ascending: true);

    return List<Map<String, dynamic>>.from(response);
  }

  // Worker applies to a job (status stays 'open', application is 'pending')
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

    // Insert application — job stays 'open' until customer accepts
    await supabase.from('job_applications').insert({
      'job_id': jobId,
      'worker_id': user.id,
      'status': 'pending',
    });
  }

  // Customer accepts a specific worker → job goes ACTIVE
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

  // Customer marks job as complete → triggers payment flow
  static Future<void> completeJob(String jobId) async {
    await supabase
        .from('jobs')
        .update({'status': 'completed'}).eq('id', jobId);
  }

  // Public distance helper
  static double distanceBetween(
      double lat1, double lng1, double lat2, double lng2) {
    return _calculateDistance(lat1, lng1, lat2, lng2);
  }

  // Haversine formula
  static double _calculateDistance(
      double lat1, double lng1, double lat2, double lng2) {
    const earthRadius = 6371.0;
    final dLat = _toRad(lat2 - lat1);
    final dLng = _toRad(lng2 - lng1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRad(lat1)) * cos(_toRad(lat2)) *
            sin(dLng / 2) * sin(dLng / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  static double _toRad(double deg) => deg * 3.141592653589793 / 180;
}
