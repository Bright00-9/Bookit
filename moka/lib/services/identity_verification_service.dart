import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

enum IdentityStatus {
  unverified,
  pending,
  autoPassed,
  verified,
  rejected,
}

extension IdentityStatusExtension on IdentityStatus {
  String get value {
    switch (this) {
      case IdentityStatus.unverified:
        return 'unverified';
      case IdentityStatus.pending:
        return 'pending';
      case IdentityStatus.autoPassed:
        return 'auto_passed';
      case IdentityStatus.verified:
        return 'verified';
      case IdentityStatus.rejected:
        return 'rejected';
    }
  }

  static IdentityStatus fromString(String? s) {
    switch (s) {
      case 'pending':
        return IdentityStatus.pending;
      case 'auto_passed':
        return IdentityStatus.autoPassed;
      case 'verified':
        return IdentityStatus.verified;
      case 'rejected':
        return IdentityStatus.rejected;
      default:
        return IdentityStatus.unverified;
    }
  }

  String get label {
    switch (this) {
      case IdentityStatus.unverified:
        return 'Not Verified';
      case IdentityStatus.pending:
        return 'Pending Review';
      case IdentityStatus.autoPassed:
        return 'Auto Check Passed';
      case IdentityStatus.verified:
        return 'Verified';
      case IdentityStatus.rejected:
        return 'Rejected';
    }
  }

  String get emoji {
    switch (this) {
      case IdentityStatus.unverified:
        return '🔒';
      case IdentityStatus.pending:
        return '⏳';
      case IdentityStatus.autoPassed:
        return '🔄';
      case IdentityStatus.verified:
        return '✅';
      case IdentityStatus.rejected:
        return '❌';
    }
  }

  // ID check alone is not enough —
  // video must also be approved
  bool get idCheckPassed =>
      this == IdentityStatus.verified ||
      this == IdentityStatus.autoPassed;
}

class IdentityVerificationService {
  String get _userId => supabase.auth.currentUser!.id;

  // ── Fetch full verification record ─────────────────────
  Future<Map<String, dynamic>?> fetchVerification() async {
    return await supabase
        .from('worker_verifications')
        .select()
        .eq('user_id', _userId)
        .maybeSingle();
  }

  // ── Fetch ID status only (lightweight) ────────────────
  Future<IdentityStatus> fetchStatus() async {
    final data = await supabase
        .from('profiles')
        .select('identity_status')
        .eq('id', _userId)
        .maybeSingle();
    return IdentityStatusExtension.fromString(
        data?['identity_status']);
  }

  // ── Fetch video status ─────────────────────────────────
  Future<String?> fetchVideoStatus() async {
    final data = await supabase
        .from('worker_verifications')
        .select(
            'work_video_status, work_video_rejection_reason')
        .eq('user_id', _userId)
        .maybeSingle();
    return data?['work_video_status'];
  }

  // ── Check if video already submitted ──────────────────
  Future<bool> hasSubmittedVideo() async {
    final data = await supabase
        .from('worker_verifications')
        .select('work_video_url')
        .eq('user_id', _userId)
        .maybeSingle();
    return data?['work_video_url'] != null;
  }

  // ── Check if user can post/accept jobs ─────────────────
  // Requires BOTH ID check passed AND video approved
  Future<bool> canPerformActions() async {
    try {
      final data = await supabase
          .from('worker_verifications')
          .select('status, work_video_status')
          .eq('user_id', _userId)
          .maybeSingle();

      if (data == null) return false;

      final idOk =
          data['status'] == 'verified' ||
          data['status'] == 'auto_passed';

      final videoOk =
          data['work_video_status'] == 'approved';

      return idOk && videoOk;
    } catch (_) {
      return false;
    }
  }

  // ── Upload ID photo or selfie to Supabase Storage ──────
  Future<String> uploadVerificationPhoto(
    Uint8List bytes,
    String type, // 'selfie' or 'id_photo'
  ) async {
    final fileName =
        'verifications/$_userId/${type}_'
        '${DateTime.now().millisecondsSinceEpoch}.jpg';

    await supabase.storage
        .from('verifications')
        .uploadBinary(fileName, bytes);

    return supabase.storage
        .from('verifications')
        .getPublicUrl(fileName);
  }

  // ── Upload work video to Backblaze B2
  // via Supabase Edge Function ───────────────────────────
  Future<Map<String, dynamic>> uploadWorkVideo(
      File videoFile) async {
    final bytes = await videoFile.readAsBytes();
    final fileName =
        videoFile.path.split('/').last;

    final uri = Uri.parse(
      '${supabase.rest.url}'
      '/functions/v1/upload-worker-video',
    );

    final request =
        http.MultipartRequest('POST', uri);

    // Auth header
    final token = supabase
        .auth.currentSession?.accessToken;
    if (token != null) {
      request.headers['Authorization'] =
          'Bearer $token';
    }

    request.fields['user_id'] = _userId;
    request.files.add(
      http.MultipartFile.fromBytes(
        'video',
        bytes,
        filename: fileName,
      ),
    );

    final streamed = await request.send();
    final response =
        await http.Response.fromStream(streamed);
    final data =
        jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode != 200) {
      throw Exception(
          data['error'] ?? 'Video upload failed');
    }

    return data;
  }

  // ── Save video record to Supabase after B2 upload ──────
  Future<void> saveVideoRecord({
    required String videoUrl,
    required String b2FileId,
  }) async {
    await supabase
        .from('worker_verifications')
        .upsert({
      'user_id': _userId,
      'work_video_url': videoUrl,
      'work_video_b2_file_id': b2FileId,
      'work_video_status': 'pending',
      'work_video_submitted_at':
          DateTime.now().toIso8601String(),
    });
  }

  // ── Submit ID for verification ─────────────────────────
  // Step 1: Save pending record
  // Step 2: Call Smile Identity via Edge Function
  // Step 3: Auto-passed or stays pending for admin
  Future<Map<String, dynamic>> submitVerification({
    required String idType,   // 'GHANA_CARD', 'NIN', etc.
    required String idNumber,
    required String country,  // 'GH', 'NG', 'KE'
    required String selfieUrl,
    required String idPhotoUrl,
  }) async {
    // Save pending record
    await supabase
        .from('worker_verifications')
        .upsert({
      'user_id': _userId,
      'id_type': idType.toLowerCase(),
      'id_number': idNumber,
      'country': country,
      'selfie_url': selfieUrl,
      'id_photo_url': idPhotoUrl,
      'status': 'pending',
      'submitted_at':
          DateTime.now().toIso8601String(),
    });

    // Update profile status
    await supabase
        .from('profiles')
        .update({'identity_status': 'pending'})
        .eq('id', _userId);

    // Call Smile Identity via Edge Function
    try {
      final response =
          await supabase.functions.invoke(
        'verify-worker',
        body: {
          'user_id': _userId,
          'id_type': idType,
          'id_number': idNumber,
          'country': country,
          'selfie_url': selfieUrl,
          'id_photo_url': idPhotoUrl,
        },
      );

      final result =
          response.data as Map<String, dynamic>;
      final autoCheckPassed =
          result['status'] == 'verified';

      // Update verification record with auto result
      await supabase
          .from('worker_verifications')
          .update({
            'auto_check_passed': autoCheckPassed,
            'smile_result_code': result['resultCode'],
            'smile_result_text': result['resultText'],
            'smile_job_id': result['smileJobId'],
            'status': autoCheckPassed
                ? 'auto_passed'
                : 'pending',
          })
          .eq('user_id', _userId);

      // Update profile
      await supabase.from('profiles').update({
        'identity_status': autoCheckPassed
            ? 'auto_passed'
            : 'pending',
        'is_identity_verified': autoCheckPassed,
      }).eq('id', _userId);

      return {
        'auto_passed': autoCheckPassed,
        'status': autoCheckPassed
            ? 'auto_passed'
            : 'pending',
        'message': autoCheckPassed
            ? 'Auto check passed. Pending admin review.'
            : 'Submitted for review.',
      };
    } catch (e) {
      // Smile Identity failed — goes to manual review
      return {
        'auto_passed': false,
        'status': 'pending',
        'message': 'Submitted for manual review.',
      };
    }
  }

  // ── Clear rejection so worker can resubmit ─────────────
  Future<void> clearRejection() async {
    await supabase
        .from('worker_verifications')
        .delete()
        .eq('user_id', _userId);

    await supabase.from('profiles').update({
      'identity_status': 'unverified',
      'is_identity_verified': false,
    }).eq('id', _userId);
  }

  // ── Delete video so worker can resubmit video only ──────
  Future<void> clearVideoRejection() async {
    await supabase
        .from('worker_verifications')
        .update({
          'work_video_url': null,
          'work_video_b2_file_id': null,
          'work_video_status': null,
          'work_video_rejection_reason': null,
          'work_video_submitted_at': null,
        })
        .eq('user_id', _userId);
  }

  // ── Fetch full status summary ──────────────────────────
  // Returns both ID and video status in one call
  // Use this for the verification screen to avoid
  // multiple separate fetches
  Future<Map<String, dynamic>> fetchFullStatus() async {
    final verification = await fetchVerification();
    final profileData = await supabase
        .from('profiles')
        .select('identity_status, is_identity_verified')
        .eq('id', _userId)
        .maybeSingle();

    return {
      'id_status': verification?['status'] ?? 'unverified',
      'video_status':
          verification?['work_video_status'],
      'video_url': verification?['work_video_url'],
      'video_rejection_reason':
          verification?['work_video_rejection_reason'],
      'profile_status':
          profileData?['identity_status'] ?? 'unverified',
      'is_verified':
          profileData?['is_identity_verified'] ?? false,
      'selfie_url': verification?['selfie_url'],
      'id_photo_url': verification?['id_photo_url'],
      'smile_result':
          verification?['smile_result_text'],
      'submitted_at': verification?['submitted_at'],
      'auto_check_passed':
          verification?['auto_check_passed'] ?? false,
      'rejection_reason':
          verification?['rejection_reason'],
    };
  }
}