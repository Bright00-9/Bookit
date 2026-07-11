import 'dart:io';
import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';

class JobCategory {
  final String id;
  final String name;
  final String? icon;

  JobCategory({required this.id, required this.name, this.icon});

  factory JobCategory.fromJson(Map<String, dynamic> json) => JobCategory(
        id: json['id'],
        name: json['name'],
        icon: json['icon'],
      );
}

class JobPostService {
  final _supabase = Supabase.instance.client;

  String get _userId => _supabase.auth.currentUser!.id;

  // ── Fetch categories ─────────────────────────────────────────
  Future<List<JobCategory>> fetchCategories() async {
    final data = await _supabase
        .from('categories')
        .select()
        .order('name', ascending: true);

    return data.map<JobCategory>((row) => JobCategory.fromJson(row)).toList();
  }

  // ── Upload job photo ─────────────────────────────────────────
  Future<String> uploadJobPhoto(Uint8List bytes, String fileName) async {
    final path =
        'jobs/${DateTime.now().millisecondsSinceEpoch}_$fileName';

    await _supabase.storage
        .from('job_photos')
        .uploadBinary(path, bytes);

    return _supabase.storage.from('job_photos').getPublicUrl(path);
  }

  // ── Post job ─────────────────────────────────────────────────
  Future<String> postJob({
    required String title,
    required String description,
    required double budget,
    required String categoryId,
    required double latitude,
    required double longitude,
    required String address,
    required double radiusKm,
    required List<String> photoUrls,
  }) async {
    final data = await _supabase
        .from('jobs')
        .insert({
          'customer_id': _userId,
          'title': title,
          'description': description,
          'budget': budget,
          'category_id': categoryId,
          'latitude': latitude,
          'longitude': longitude,
          'address': address,
          'radius_km': radiusKm,
          'photos': photoUrls,
          'status': 'open',
        })
        .select('id')
        .single();

    return data['id'];
  }

  // ── Fetch customer radius from settings ──────────────────────
  Future<double> fetchCustomerRadius() async {
    final data = await _supabase
        .from('user_settings')
        .select('job_radius_km')
        .eq('user_id', _userId)
        .maybeSingle();

    return (data?['job_radius_km'] ?? 10).toDouble();
  }

  // ── Reverse geocode using Nominatim (OpenStreetMap) ──────────
  Future<String> reverseGeocode(
      double lat, double lng) async {
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse'
        '?lat=$lat&lon=$lng&format=json',
      );

      final response = await _supabase.functions.invoke(
        'reverse-geocode',
        body: {'lat': lat, 'lng': lng},
      );

      return response.data?['display_name'] ?? 'Unknown location';
    } catch (_) {
      return 'Unknown location';
    }
  }
}