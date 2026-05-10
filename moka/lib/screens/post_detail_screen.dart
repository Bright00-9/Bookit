import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/portfolio_service.dart';
import 'public_profile_screen.dart';

class PostDetailScreen extends StatefulWidget {
  final Map<String, dynamic> post;

  const PostDetailScreen({super.key, required this.post});

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  List<Map<String, dynamic>> _comments = [];
  bool _isLiked = false;
  int _likesCount = 0;
  int _commentsCount = 0;
  bool _isLoadingComments = true;
  bool _isSubmittingComment = false;
  final _commentController = TextEditingController();
  final _currentUserId =
      Supabase.instance.client.auth.currentUser?.id;
  RealtimeChannel? _realtimeChannel;

  @override
  void initState() {
    super.initState();
    _likesCount = widget.post['likes_count'] ?? 0;
    _commentsCount = widget.post['comments_count'] ?? 0;
    _loadData();
    // Subscribe to realtime updates for this post
    _realtimeChannel = PortfolioService.subscribeToPost(
      postId: widget.post['id'],
      onUpdate: (updated) {
        if (mounted) {
          setState(() {
            _likesCount = updated['likes_count'] ?? _likesCount;
            _commentsCount = updated['comments_count'] ?? _commentsCount;
          });
        }
      },
    );
  }

  @override
  void dispose() {
    _commentController.dispose();
    _realtimeChannel?.unsubscribe();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoadingComments = true);
    try {
      final comments =
          await PortfolioService.getComments(widget.post['id']);
      final liked = await PortfolioService.hasLiked(widget.post['id']);
      if (mounted) {
        setState(() {
          _comments = comments;
          _isLiked = liked;
        });
      }
    } catch (e) {
      debugPrint('Error loading post data: $e');
    } finally {
      if (mounted) setState(() => _isLoadingComments = false);
    }
  }

  Future<void> _toggleLike() async {
    try {
      final isNowLiked =
          await PortfolioService.toggleLike(widget.post['id']);
      setState(() {
        _isLiked = isNowLiked;
        _likesCount += isNowLiked ? 1 : -1;
      });
    } catch (e) {
      debugPrint('Error toggling like: $e');
    }
  }

  Future<void> _submitComment() async {
    final content = _commentController.text.trim();
    if (content.isEmpty) return;

    setState(() => _isSubmittingComment = true);
    try {
      await PortfolioService.addComment(
        postId: widget.post['id'],
        content: content,
      );
      _commentController.clear();
      await _loadData();
      if (mounted) setState(() => _commentsCount = _comments.length);
    } catch (e) {
      debugPrint('Error submitting comment: $e');
    } finally {
      if (mounted) setState(() => _isSubmittingComment = false);
    }
  }

  Future<void> _deleteComment(String commentId) async {
    try {
      await PortfolioService.deleteComment(commentId);
      setState(() =>
          _comments.removeWhere((c) => c['id'] == commentId));
    } catch (e) {
      debugPrint('Error deleting comment: $e');
    }
  }

  String _timeAgo(String? ts) {
    if (ts == null) return '';
    final diff = DateTime.now().difference(DateTime.parse(ts));
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${(diff.inDays / 7).floor()}w ago';
  }

  @override
  Widget build(BuildContext context) {
    final worker = widget.post['profiles'] as Map<String, dynamic>?;
    final workerName = worker?['name'] ?? 'Worker';
    final workerSkill = worker?['skill'] ?? '';
    final avatarUrl = worker?['avatar_url'];
    final workerId = worker?['id'];

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D0D),
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_new,
              color: Colors.white, size: 20),
        ),
        title: const Text('Post',
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 18)),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Worker header
                  GestureDetector(
                    onTap: () {
                      if (workerId != null) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                PublicProfileScreen(userId: workerId),
                          ),
                        );
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: const Color(0xFFFF6B00)
                                .withOpacity(0.15),
                            backgroundImage: avatarUrl != null
                                ? NetworkImage(avatarUrl)
                                : null,
                            child: avatarUrl == null
                                ? Text(
                                    workerName[0].toUpperCase(),
                                    style: const TextStyle(
                                      color: Color(0xFFFF6B00),
                                      fontWeight: FontWeight.w700,
                                    ),
                                  )
                                : null,
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(workerName,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14)),
                              Text(workerSkill,
                                  style: const TextStyle(
                                      color: Color(0xFF888888),
                                      fontSize: 12)),
                            ],
                          ),
                          const Spacer(),
                          Text(
                            _timeAgo(widget.post['created_at']),
                            style: const TextStyle(
                                color: Color(0xFF555555), fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Post image
                  Image.network(
                    widget.post['image_url'],
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      height: 200,
                      color: const Color(0xFF1A1A1A),
                      child: const Icon(Icons.image_not_supported,
                          color: Color(0xFF555555), size: 40),
                    ),
                  ),

                  // Like + comment actions
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: _toggleLike,
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            child: Icon(
                              _isLiked
                                  ? Icons.favorite_rounded
                                  : Icons.favorite_border_rounded,
                              key: ValueKey(_isLiked),
                              color: _isLiked
                                  ? const Color(0xFFE53935)
                                  : const Color(0xFF888888),
                              size: 28,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '$_likesCount',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 14),
                        ),
                        const SizedBox(width: 16),
                        const Icon(Icons.chat_bubble_outline,
                            color: Color(0xFF888888), size: 26),
                        const SizedBox(width: 6),
                        Text(
                          '$_commentsCount',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 14),
                        ),
                        const Spacer(),
                        if (widget.post['skill'] != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF6B00)
                                  .withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              widget.post['skill'],
                              style: const TextStyle(
                                  color: Color(0xFFFF6B00),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                      ],
                    ),
                  ),

                  // Caption
                  if (widget.post['caption'] != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                      child: RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: '$workerName ',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14),
                            ),
                            TextSpan(
                              text: widget.post['caption'],
                              style: const TextStyle(
                                  color: Color(0xFFCCCCCC), fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Comments
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 20, 16, 8),
                    child: Text('Comments',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 15)),
                  ),

                  if (_isLoadingComments)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: CircularProgressIndicator(
                            color: Color(0xFFFF6B00)),
                      ),
                    )
                  else if (_comments.isEmpty)
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Text('No comments yet. Be the first!',
                          style: TextStyle(
                              color: Color(0xFF888888), fontSize: 13)),
                    )
                  else
                    ..._comments.map((c) => _buildComment(c)),

                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),

          // Comment input
          _buildCommentInput(),
        ],
      ),
    );
  }

  Widget _buildComment(Map<String, dynamic> comment) {
    final user =
        comment['profiles'] as Map<String, dynamic>?;
    final name = user?['name'] ?? 'User';
    final avatarUrl = user?['avatar_url'];
    final isMyComment = comment['user_id'] == _currentUserId;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor:
                const Color(0xFFFF6B00).withOpacity(0.15),
            backgroundImage:
                avatarUrl != null ? NetworkImage(avatarUrl) : null,
            child: avatarUrl == null
                ? Text(name[0].toUpperCase(),
                    style: const TextStyle(
                        color: Color(0xFFFF6B00),
                        fontSize: 12,
                        fontWeight: FontWeight.w700))
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(name,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 13)),
                    const SizedBox(width: 6),
                    Text(_timeAgo(comment['created_at']),
                        style: const TextStyle(
                            color: Color(0xFF555555), fontSize: 11)),
                  ],
                ),
                const SizedBox(height: 2),
                Text(comment['content'] ?? '',
                    style: const TextStyle(
                        color: Color(0xFFCCCCCC), fontSize: 13)),
              ],
            ),
          ),
          if (isMyComment)
            GestureDetector(
              onTap: () => _deleteComment(comment['id']),
              child: const Padding(
                padding: EdgeInsets.only(left: 8),
                child: Icon(Icons.delete_outline,
                    color: Color(0xFF555555), size: 16),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCommentInput() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 12, 24),
      decoration: const BoxDecoration(
        color: Color(0xFF111111),
        border: Border(top: BorderSide(color: Color(0xFF1F1F1F))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFF2A2A2A)),
              ),
              child: TextField(
                controller: _commentController,
                style:
                    const TextStyle(color: Colors.white, fontSize: 14),
                maxLines: null,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: 'Add a comment...',
                  hintStyle: TextStyle(color: Color(0xFF555555)),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                      horizontal: 18, vertical: 10),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: _isSubmittingComment ? null : _submitComment,
            child: Container(
              width: 42,
              height: 42,
              decoration: const BoxDecoration(
                color: Color(0xFFFF6B00),
                shape: BoxShape.circle,
              ),
              child: _isSubmittingComment
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.send_rounded,
                      color: Colors.white, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}
