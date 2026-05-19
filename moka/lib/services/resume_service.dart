import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '/resume_model.dart';
import 'dart:typed_data';

class ResumeService {
  final _supabase = Supabase.instance.client;

  String get _userId => _supabase.auth.currentUser!.id;

  Future<ResumeModel?> fetchResume() async {
    final data = await _supabase
        .from('resumes')
        .select()
        .eq('user_id', _userId)
        .maybeSingle();

    if (data == null) return null;
    return ResumeModel.fromJson(data);
  }

  Future<ResumeModel?> fetchResumeByUserId(String userId) async {
    final data = await _supabase
        .from('resumes')
        .select()
        .eq('user_id', userId)
        .maybeSingle();

    if (data == null) return null;
    return ResumeModel.fromJson(data);
  }

  Future<void> saveResume(ResumeModel resume) async {
    await _supabase.from('resumes').upsert({
      'user_id': _userId,
      ...resume.toJson(),
    });
  }

  // Upload PDF bytes to Supabase Storage, returns public URL
  Future<String> uploadResumePdf({
    required List<int> bytes,
    required String fileName,
  }) async {
    final storagePath =
        'resumes/${DateTime.now().millisecondsSinceEpoch}_$fileName';

    await _supabase.storage
        .from('resumes')
        .uploadBinary(storagePath, Uint8List.fromList(bytes));

    return _supabase.storage.from('resumes').getPublicUrl(storagePath);
  }

  Future<void> deleteResume() async {
    final data = await _supabase
        .from('resumes')
        .select('file_url')
        .eq('user_id', _userId)
        .maybeSingle();

    if (data != null && data['file_url'] != null) {
      final uri = Uri.parse(data['file_url']);
      final pathSegments = uri.pathSegments;
      final bucketIndex = pathSegments.indexOf('resumes');
      if (bucketIndex != -1) {
        final filePath =
            pathSegments.sublist(bucketIndex + 1).join('/');
        await _supabase.storage.from('resumes').remove([filePath]);
      }
    }

    await _supabase.from('resumes').delete().eq('user_id', _userId);
  }
}