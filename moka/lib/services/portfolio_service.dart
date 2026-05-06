import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

class PortfolioService {

  // Get public profile for any user
  static Future<Map<String, dynamic>> getPublicProfile(String userId) async {
    final data = await supabase
        .from('profiles')
        .select('id, name, phone, role, skill, rating, avatar_url, is_online')
        .eq('id', userId)
        .single();
    return data;
  }
  // ─── Posts ──────────────────────────────────────────────────────────────────

  // Upload image and create post
  static Future<void> createPost({
    required File imageFile,
    required String caption,
    required String skill,
  }) async {
    final user = supabase.auth.currentUser;
    if (user == null) throw Exception('Not logged in');

    // Upload image to Supabase Storage
    final fileName =
        '${user.id}/${DateTime.now().millisecondsSinceEpoch}.jpg';
    await supabase.storage.from('portfolio').upload(fileName, imageFile,
        fileOptions: const FileOptions(upsert: true));

    final imageUrl =
        supabase.storage.from('portfolio').getPublicUrl(fileName);

    // Insert post
    await supabase.from('portfolio_posts').insert({
      'worker_id': user.id,
      'image_url': imageUrl,
      'caption': caption,
      'skill': skill,
    });
  }

  // Get all posts for feed (all workers)
  static Future<List<Map<String, dynamic>>> getFeedPosts() async {
    final data = await supabase
        .from('portfolio_posts')
        .select('*, profiles!worker_id(id, name, skill, avatar_url, rating)')
        .order('created_at', ascending: false)
        .limit(50);
    return List<Map<String, dynamic>>.from(data);
  }

  // Get posts by a specific worker
  static Future<List<Map<String, dynamic>>> getWorkerPosts(
      String workerId) async {
    final data = await supabase
        .from('portfolio_posts')
        .select('*, profiles!worker_id(id, name, skill, avatar_url, rating)')
        .eq('worker_id', workerId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(data);
  }

  // Delete a post
  static Future<void> deletePost(String postId) async {
    await supabase.from('portfolio_posts').delete().eq('id', postId);
  }

  // ─── Likes ──────────────────────────────────────────────────────────────────

  // Toggle like
  static Future<bool> toggleLike(String postId) async {
    final user = supabase.auth.currentUser;
    if (user == null) throw Exception('Not logged in');

    final existing = await supabase
        .from('post_likes')
        .select('id')
        .eq('post_id', postId)
        .eq('user_id', user.id)
        .maybeSingle();

    if (existing != null) {
      // Unlike
      await supabase
          .from('post_likes')
          .delete()
          .eq('post_id', postId)
          .eq('user_id', user.id);
      return false;
    } else {
      // Like
      await supabase.from('post_likes').insert({
        'post_id': postId,
        'user_id': user.id,
      });
      return true;
    }
  }

  // Check if current user liked a post
  static Future<bool> hasLiked(String postId) async {
    final user = supabase.auth.currentUser;
    if (user == null) return false;

    final data = await supabase
        .from('post_likes')
        .select('id')
        .eq('post_id', postId)
        .eq('user_id', user.id)
        .maybeSingle();
    return data != null;
  }

  // Get liked post IDs for current user (batch check)
  static Future<Set<String>> getLikedPostIds(
      List<String> postIds) async {
    final user = supabase.auth.currentUser;
    if (user == null) return {};

    final data = await supabase
        .from('post_likes')
        .select('post_id')
        .eq('user_id', user.id)
        .inFilter('post_id', postIds);

    return (data as List).map((e) => e['post_id'] as String).toSet();
  }

  // ─── Comments ───────────────────────────────────────────────────────────────

  // Get comments for a post
  static Future<List<Map<String, dynamic>>> getComments(
      String postId) async {
    final data = await supabase
        .from('post_comments')
        .select('*, profiles!user_id(name, avatar_url)')
        .eq('post_id', postId)
        .order('created_at', ascending: true);
    return List<Map<String, dynamic>>.from(data);
  }

  // Add comment
  static Future<void> addComment({
    required String postId,
    required String content,
  }) async {
    final user = supabase.auth.currentUser;
    if (user == null) throw Exception('Not logged in');

    await supabase.from('post_comments').insert({
      'post_id': postId,
      'user_id': user.id,
      'content': content,
    });
  }

  // Delete comment
  static Future<void> deleteComment(String commentId) async {
    await supabase.from('post_comments').delete().eq('id', commentId);
  }
}
