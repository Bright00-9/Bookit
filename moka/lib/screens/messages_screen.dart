import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'chat_screen.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _conversations = [];
  List<Map<String, dynamic>> _activeJobs = [];
  bool _isLoading = true;
  final _supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      // Load existing conversations
      final convData = await _supabase
          .from('conversations')
          .select('''
            id,
            job_id,
            customer_id,
            worker_id,
            created_at,
            jobs(title, skill_needed),
            messages(content, created_at, sender_id)
          ''')
          .or('customer_id.eq.$userId,worker_id.eq.$userId')
          .order('created_at', ascending: false);

      // Load accepted jobs with no conversation yet (for customers)
      final profile = await _supabase
          .from('profiles')
          .select('role')
          .eq('id', userId)
          .single();

      List<Map<String, dynamic>> activeJobs = [];

      if (profile['role'] == 'customer') {
        final jobsData = await _supabase
            .from('jobs')
            .select('''
              id, title, skill_needed, status,
              job_applications(worker_id, profiles!worker_id(name, skill))
            ''')
            .eq('customer_id', userId)
            .eq('status', 'accepted');

        // Filter jobs that don't have a conversation yet
        final existingJobIds = (convData as List)
            .map((c) => c['job_id'])
            .toSet();

        activeJobs = (jobsData as List)
            .where((j) => !existingJobIds.contains(j['id']))
            .map((j) => Map<String, dynamic>.from(j))
            .toList();
      }

      if (mounted) {
        setState(() {
          _conversations = List<Map<String, dynamic>>.from(convData);
          _activeJobs = activeJobs;
        });
      }
    } catch (e) {
      debugPrint('Error loading messages: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Create conversation and open chat
  Future<void> _startChat(Map<String, dynamic> job) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      final applications = job['job_applications'] as List?;
      if (applications == null || applications.isEmpty) {
        _showError('No worker assigned to this job yet');
        return;
      }

      final workerId = applications[0]['worker_id'];

      // Check if conversation already exists
      final existing = await _supabase
          .from('conversations')
          .select('id')
          .eq('job_id', job['id'])
          .maybeSingle();

      String conversationId;

      if (existing != null) {
        conversationId = existing['id'];
      } else {
        // Create new conversation
        final newConv = await _supabase
            .from('conversations')
            .insert({
              'job_id': job['id'],
              'customer_id': userId,
              'worker_id': workerId,
            })
            .select()
            .single();
        conversationId = newConv['id'];
      }

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            conversationId: conversationId,
            jobTitle: job['title'] ?? 'Job Chat',
          ),
        ),
      ).then((_) => _loadData());
    } catch (e) {
      _showError('Could not start chat. Try again.');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFE53935),
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  String _timeAgo(String? timestamp) {
    if (timestamp == null) return '';
    final diff = DateTime.now().difference(DateTime.parse(timestamp));
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            // Tabs
            TabBar(
              controller: _tabController,
              indicatorColor: const Color(0xFFFF6B00),
              indicatorWeight: 3,
              labelColor: const Color(0xFFFF6B00),
              unselectedLabelColor: const Color(0xFF555555),
              labelStyle: const TextStyle(
                  fontWeight: FontWeight.w700, fontSize: 13),
              tabs: [
                Tab(text: 'Chats (${_conversations.length})'),
                Tab(text: 'Start Chat (${_activeJobs.length})'),
              ],
            ),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: Color(0xFFFF6B00)))
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildConversationsList(),
                        _buildActiveJobsList(),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Messages',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          IconButton(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh,
                color: Color(0xFF888888), size: 22),
          ),
        ],
      ),
    );
  }

  Widget _buildConversationsList() {
    if (_conversations.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: Color(0xFF1A1A1A),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.chat_bubble_outline,
                  color: Color(0xFF555555), size: 32),
            ),
            const SizedBox(height: 16),
            const Text(
              'No chats yet',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text(
              'Go to "Start Chat" tab to message\na worker on your active jobs',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF888888), fontSize: 14),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: const Color(0xFFFF6B00),
      backgroundColor: const Color(0xFF1A1A1A),
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        itemCount: _conversations.length,
        itemBuilder: (context, i) =>
            _buildConversationTile(_conversations[i]),
      ),
    );
  }

  Widget _buildActiveJobsList() {
    if (_activeJobs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.work_outline,
                color: Color(0xFF555555), size: 48),
            const SizedBox(height: 16),
            const Text(
              'No active jobs',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text(
              'Jobs with an accepted worker\nwill appear here to start a chat',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF888888), fontSize: 14),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      itemCount: _activeJobs.length,
      itemBuilder: (context, i) => _buildActiveJobTile(_activeJobs[i]),
    );
  }

  Widget _buildActiveJobTile(Map<String, dynamic> job) {
    final applications = job['job_applications'] as List?;
    final worker = applications != null && applications.isNotEmpty
        ? applications[0]['profiles'] as Map<String, dynamic>?
        : null;
    final workerName = worker?['name'] ?? 'Worker';
    final workerSkill = worker?['skill'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: const Color(0xFF4CAF50).withOpacity(0.3)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor:
                const Color(0xFF4CAF50).withOpacity(0.15),
            child: Text(
              workerName[0].toUpperCase(),
              style: const TextStyle(
                color: Color(0xFF4CAF50),
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  workerName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${job['title']} • $workerSkill',
                  style: const TextStyle(
                      color: Color(0xFF888888), fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: () => _startChat(job),
            icon: const Icon(Icons.chat_bubble_outline, size: 15),
            label: const Text('Chat'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF6B00),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              elevation: 0,
              textStyle: const TextStyle(
                  fontWeight: FontWeight.w700, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConversationTile(Map<String, dynamic> conversation) {
    final job = conversation['jobs'] as Map<String, dynamic>?;
    final messages = conversation['messages'] as List<dynamic>?;
    final lastMessage = messages != null && messages.isNotEmpty
        ? messages.last as Map<String, dynamic>
        : null;
    final jobTitle = job?['title'] ?? 'Job Chat';
    final skill = job?['skill_needed'] ?? '';
    final lastContent = lastMessage?['content'] ?? 'Tap to start chatting';
    final lastTime =
        lastMessage?['created_at'] ?? conversation['created_at'];
    final currentUserId = _supabase.auth.currentUser?.id;
    final isMyMessage = lastMessage?['sender_id'] == currentUserId;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatScreen(
              conversationId: conversation['id'],
              jobTitle: jobTitle,
            ),
          ),
        ).then((_) => _loadData());
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF2A2A2A)),
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: const Color(0xFFFF6B00).withOpacity(0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.work_outline,
                  color: Color(0xFFFF6B00), size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          jobTitle,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        _timeAgo(lastTime),
                        style: const TextStyle(
                            color: Color(0xFF555555), fontSize: 11),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (skill.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF252525),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(skill,
                          style: const TextStyle(
                              color: Color(0xFF888888), fontSize: 10)),
                    ),
                  const SizedBox(height: 4),
                  Text(
                    lastMessage == null
                        ? 'Tap to start chatting'
                        : isMyMessage
                            ? 'You: $lastContent'
                            : lastContent,
                    style: TextStyle(
                      color: lastMessage == null
                          ? const Color(0xFFFF6B00)
                          : const Color(0xFF888888),
                      fontSize: 13,
                      fontStyle: lastMessage == null
                          ? FontStyle.italic
                          : FontStyle.normal,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right,
                color: Color(0xFF444444), size: 20),
          ],
        ),
      ),
    );
  }
}
