import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ChatScreen extends StatefulWidget {
  final String conversationId;
  final String jobTitle;

  const ChatScreen({
    super.key,
    required this.conversationId,
    required this.jobTitle,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final _supabase = Supabase.instance.client;

  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  late RealtimeChannel _channel;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _currentUserId = _supabase.auth.currentUser?.id;
    _loadMessages();
    _subscribeToMessages();
  }

  @override
  void dispose() {
    _supabase.removeChannel(_channel);
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    setState(() => _isLoading = true);
    try {
      final data = await _supabase
          .from('messages')
          .select('*, profiles!sender_id(name)')
          .eq('conversation_id', widget.conversationId)
          .order('created_at', ascending: true);

      if (mounted) {
        setState(() => _messages = List<Map<String, dynamic>>.from(data));
      }
      _scrollToBottom();
    } catch (e) {
      debugPrint('Error loading messages: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _subscribeToMessages() {
    _channel = _supabase
        .channel('messages:${widget.conversationId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'conversation_id',
            value: widget.conversationId,
          ),
          callback: (payload) async {
            final newMsg = payload.newRecord;
            // Fetch sender name
            final profile = await _supabase
                .from('profiles')
                .select('name')
                .eq('id', newMsg['sender_id'])
                .single();
            newMsg['profiles'] = profile;
            if (mounted) {
              setState(() => _messages.add(newMsg));
              _scrollToBottom();
            }
          },
        )
        .subscribe();
  }

  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();
    if (content.isEmpty || _isSending) return;

    _messageController.clear();
    setState(() => _isSending = true);

    try {
      await _supabase.from('messages').insert({
        'conversation_id': widget.conversationId,
        'sender_id': _currentUserId,
        'content': content,
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Failed to send message'),
          backgroundColor: const Color(0xFFE53935),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _formatTime(String? timestamp) {
    if (timestamp == null) return '';
    final dt = DateTime.parse(timestamp).toLocal();
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  bool _isSameDay(String? a, String? b) {
    if (a == null || b == null) return false;
    final da = DateTime.parse(a).toLocal();
    final db = DateTime.parse(b).toLocal();
    return da.year == db.year && da.month == db.month && da.day == db.day;
  }

  String _dayLabel(String? timestamp) {
    if (timestamp == null) return '';
    final dt = DateTime.parse(timestamp).toLocal();
    final now = DateTime.now();
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      return 'Today';
    }
    final yesterday = now.subtract(const Duration(days: 1));
    if (dt.year == yesterday.year &&
        dt.month == yesterday.month &&
        dt.day == yesterday.day) {
      return 'Yesterday';
    }
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: Color(0xFFFF6B00)))
                  : _messages.isEmpty
                      ? _buildEmptyChat()
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          itemCount: _messages.length,
                          itemBuilder: (context, i) {
                            final msg = _messages[i];
                            final prevMsg = i > 0 ? _messages[i - 1] : null;
                            final showDay = prevMsg == null ||
                                !_isSameDay(
                                  prevMsg['created_at'],
                                  msg['created_at'],
                                );
                            return Column(
                              children: [
                                if (showDay) _buildDayDivider(msg['created_at']),
                                _buildMessageBubble(msg),
                              ],
                            );
                          },
                        ),
            ),
            _buildInputBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 12, 16, 12),
      decoration: const BoxDecoration(
        color: Color(0xFF111111),
        border: Border(bottom: BorderSide(color: Color(0xFF1F1F1F))),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_ios_new,
                color: Colors.white, size: 20),
          ),
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFFFF6B00).withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.work_outline,
                color: Color(0xFFFF6B00), size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.jobTitle,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const Text(
                  'Job Chat',
                  style:
                      TextStyle(color: Color(0xFF888888), fontSize: 11),
                ),
              ],
            ),
          ),
          // Online indicator
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Color(0xFF4CAF50),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          const Text('Live',
              style: TextStyle(color: Color(0xFF4CAF50), fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildDayDivider(String? timestamp) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          const Expanded(
              child: Divider(color: Color(0xFF2A2A2A), thickness: 1)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              _dayLabel(timestamp),
              style: const TextStyle(color: Color(0xFF555555), fontSize: 12),
            ),
          ),
          const Expanded(
              child: Divider(color: Color(0xFF2A2A2A), thickness: 1)),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> msg) {
    final isMe = msg['sender_id'] == _currentUserId;
    final content = msg['content'] ?? '';
    final time = _formatTime(msg['created_at']);
    final senderName = (msg['profiles'] as Map<String, dynamic>?)?['name'] ?? '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              radius: 14,
              backgroundColor: const Color(0xFF1A1A1A),
              child: Text(
                senderName.isNotEmpty ? senderName[0].toUpperCase() : '?',
                style: const TextStyle(
                    color: Color(0xFFFF6B00),
                    fontSize: 11,
                    fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (!isMe)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4, left: 4),
                    child: Text(senderName,
                        style: const TextStyle(
                            color: Color(0xFF888888), fontSize: 11)),
                  ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.68,
                  ),
                  decoration: BoxDecoration(
                    color: isMe
                        ? const Color(0xFFFF6B00)
                        : const Color(0xFF1A1A1A),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isMe ? 16 : 4),
                      bottomRight: Radius.circular(isMe ? 4 : 16),
                    ),
                    border: isMe
                        ? null
                        : Border.all(color: const Color(0xFF2A2A2A)),
                  ),
                  child: Text(
                    content,
                    style: TextStyle(
                      color: isMe ? Colors.white : const Color(0xFFDDDDDD),
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                ),
                Padding(
                  padding:
                      const EdgeInsets.only(top: 4, left: 4, right: 4),
                  child: Text(
                    time,
                    style: const TextStyle(
                        color: Color(0xFF555555), fontSize: 10),
                  ),
                ),
              ],
            ),
          ),
          if (isMe) const SizedBox(width: 4),
        ],
      ),
    );
  }

  Widget _buildEmptyChat() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.chat_bubble_outline,
              color: Color(0xFF555555), size: 40),
          const SizedBox(height: 12),
          const Text('No messages yet',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          const Text('Say hi to get started!',
              style:
                  TextStyle(color: Color(0xFF888888), fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 12, 16),
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
                controller: _messageController,
                style: const TextStyle(color: Colors.white, fontSize: 15),
                maxLines: null,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: 'Type a message...',
                  hintStyle: TextStyle(color: Color(0xFF555555)),
                  border: InputBorder.none,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: _sendMessage,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: const Color(0xFFFF6B00),
                shape: BoxShape.circle,
              ),
              child: _isSending
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    )
                  : const Icon(Icons.send_rounded,
                      color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}
