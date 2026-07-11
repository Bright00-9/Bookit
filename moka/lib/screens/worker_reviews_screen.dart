import 'package:flutter/material.dart';
import '../services/rating_service.dart';

class WorkerReviewsScreen extends StatefulWidget {
  final String workerId;
  final String workerName;
  final double rating;

  const WorkerReviewsScreen({
    super.key,
    required this.workerId,
    required this.workerName,
    required this.rating,
  });

  @override
  State<WorkerReviewsScreen> createState() => _WorkerReviewsScreenState();
}

class _WorkerReviewsScreenState extends State<WorkerReviewsScreen> {
  List<Map<String, dynamic>> _ratings = [];
  bool _isLoading = true;
  Map<int, int> _starCounts = {5: 0, 4: 0, 3: 0, 2: 0, 1: 0};

  @override
  void initState() {
    super.initState();
    _loadRatings();
  }

  Future<void> _loadRatings() async {
    setState(() => _isLoading = true);
    try {
      final ratings =
          await RatingService.getWorkerRatings(widget.workerId);
      final counts = {5: 0, 4: 0, 3: 0, 2: 0, 1: 0};
      for (final r in ratings) {
        final star = r['stars'] as int;
        counts[star] = (counts[star] ?? 0) + 1;
      }
      if (mounted) {
        setState(() {
          _ratings = ratings;
          _starCounts = counts;
        });
      }
    } catch (e) {
      debugPrint('Error loading ratings: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _timeAgo(String? ts) {
    if (ts == null) return '';
    final diff = DateTime.now().difference(DateTime.parse(ts));
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 30) return '${diff.inDays} days ago';
    if (diff.inDays < 365) return '${(diff.inDays / 30).floor()} months ago';
    return '${(diff.inDays / 365).floor()} years ago';
  }

  @override
  Widget build(BuildContext context) {
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
        title: Text(
          '${widget.workerName}\'s Reviews',
          style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 18),
        ),
      ),
      body: _isLoading
          ? const Center(
              child:
                  CircularProgressIndicator(color: Color(0xFFFF6B00)))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSummaryCard(),
                  const SizedBox(height: 24),
                  _buildReviewsList(),
                ],
              ),
            ),
    );
  }

  Widget _buildSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: Row(
        children: [
          // Big rating number
          Column(
            children: [
              Text(
                widget.rating.toStringAsFixed(1),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 52,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: List.generate(
                  5,
                  (i) => Icon(
                    Icons.star_rounded,
                    color: i < widget.rating.round()
                        ? const Color(0xFFFF6B00)
                        : const Color(0xFF333333),
                    size: 16,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${_ratings.length} reviews',
                style: const TextStyle(
                    color: Color(0xFF888888), fontSize: 12),
              ),
            ],
          ),

          const SizedBox(width: 24),

          // Star breakdown bars
          Expanded(
            child: Column(
              children: [5, 4, 3, 2, 1].map((star) {
                final count = _starCounts[star] ?? 0;
                final total = _ratings.length;
                final percent = total > 0 ? count / total : 0.0;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Text('$star',
                          style: const TextStyle(
                              color: Color(0xFF888888),
                              fontSize: 11)),
                      const SizedBox(width: 4),
                      const Icon(Icons.star_rounded,
                          color: Color(0xFFFF6B00), size: 11),
                      const SizedBox(width: 6),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: percent,
                            backgroundColor: const Color(0xFF2A2A2A),
                            valueColor:
                                const AlwaysStoppedAnimation<Color>(
                                    Color(0xFFFF6B00)),
                            minHeight: 6,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      SizedBox(
                        width: 20,
                        child: Text(
                          '$count',
                          style: const TextStyle(
                              color: Color(0xFF888888),
                              fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewsList() {
    if (_ratings.isEmpty) {
      return Center(
        child: Column(
          children: [
            const Icon(Icons.star_outline_rounded,
                color: Color(0xFF555555), size: 48),
            const SizedBox(height: 12),
            const Text('No reviews yet',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            const Text('Reviews will appear after completed jobs',
                style:
                    TextStyle(color: Color(0xFF888888), fontSize: 13)),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${_ratings.length} Review${_ratings.length == 1 ? '' : 's'}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        ..._ratings.map((r) => _buildReviewCard(r)),
      ],
    );
  }

  Widget _buildReviewCard(Map<String, dynamic> r) {
    final stars = r['stars'] as int;
    final review = r['review'] ?? '';
    final customerName =
        (r['profiles'] as Map<String, dynamic>?)?['name'] ?? 'Customer';
    final time = _timeAgo(r['created_at']);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor:
                    const Color(0xFFFF6B00).withOpacity(0.15),
                child: Text(
                  customerName[0].toUpperCase(),
                  style: const TextStyle(
                    color: Color(0xFFFF6B00),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      customerName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    Text(time,
                        style: const TextStyle(
                            color: Color(0xFF555555), fontSize: 11)),
                  ],
                ),
              ),
              // Stars
              Row(
                children: List.generate(
                  5,
                  (i) => Icon(
                    Icons.star_rounded,
                    color: i < stars
                        ? const Color(0xFFFF6B00)
                        : const Color(0xFF333333),
                    size: 14,
                  ),
                ),
              ),
            ],
          ),
          if (review.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              review,
              style: const TextStyle(
                color: Color(0xFFCCCCCC),
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
