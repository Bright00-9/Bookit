import 'package:flutter/material.dart';
import '../services/rating_service.dart';

class RateWorkerScreen extends StatefulWidget {
  final String jobId;
  final String workerId;
  final String workerName;
  final String jobTitle;

  const RateWorkerScreen({
    super.key,
    required this.jobId,
    required this.workerId,
    required this.workerName,
    required this.jobTitle,
  });

  @override
  State<RateWorkerScreen> createState() => _RateWorkerScreenState();
}

class _RateWorkerScreenState extends State<RateWorkerScreen> {
  int _selectedStars = 0;
  final _reviewController = TextEditingController();
  bool _isSubmitting = false;
  bool _isAlreadyRated = false;
  bool _isChecking = true;

  @override
  void initState() {
    super.initState();
    _checkIfRated();
  }

  @override
  void dispose() {
    _reviewController.dispose();
    super.dispose();
  }

  Future<void> _checkIfRated() async {
    final rated = await RatingService.hasRated(widget.jobId);
    if (mounted) {
      setState(() {
        _isAlreadyRated = rated;
        _isChecking = false;
      });
    }
  }

  Future<void> _submitRating() async {
    if (_selectedStars == 0) {
      _showError('Please select a star rating');
      return;
    }
    if (_reviewController.text.trim().isEmpty) {
      _showError('Please write a short review');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await RatingService.submitRating(
        jobId: widget.jobId,
        workerId: widget.workerId,
        stars: _selectedStars,
        review: _reviewController.text.trim(),
      );

      if (!mounted) return;
      _showSuccess();
    } catch (e) {
      if (!mounted) return;
      _showError('Failed to submit rating. Please try again.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFE53935),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showSuccess() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: const Color(0xFF4CAF50).withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle,
                  color: Color(0xFF4CAF50), size: 36),
            ),
            const SizedBox(height: 16),
            const Text(
              'Rating Submitted!',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Thank you for rating ${widget.workerName}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Color(0xFF888888), fontSize: 14),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF6B00),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: const Text('Done',
                    style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
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
        title: const Text(
          'Rate Worker',
          style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 18),
        ),
      ),
      body: _isChecking
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFFF6B00)))
          : _isAlreadyRated
              ? _buildAlreadyRated()
              : _buildRatingForm(),
    );
  }

  Widget _buildAlreadyRated() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: const Color(0xFFFF6B00).withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.star,
                color: Color(0xFFFF6B00), size: 36),
          ),
          const SizedBox(height: 16),
          const Text(
            'Already Rated',
            style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          const Text(
            'You have already submitted\na rating for this job',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF888888), fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildRatingForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Worker info card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF2A2A2A)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor:
                      const Color(0xFFFF6B00).withOpacity(0.15),
                  child: Text(
                    widget.workerName[0].toUpperCase(),
                    style: const TextStyle(
                      color: Color(0xFFFF6B00),
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.workerName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.jobTitle,
                        style: const TextStyle(
                            color: Color(0xFF888888), fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // Star rating
          const Text(
            'How was the job?',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Tap a star to rate',
            style: TextStyle(color: Color(0xFF888888), fontSize: 13),
          ),
          const SizedBox(height: 20),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) {
              final star = i + 1;
              return GestureDetector(
                onTap: () => setState(() => _selectedStars = star),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Icon(
                    _selectedStars >= star
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    color: _selectedStars >= star
                        ? const Color(0xFFFF6B00)
                        : const Color(0xFF444444),
                    size: 52,
                  ),
                ),
              );
            }),
          ),

          const SizedBox(height: 8),

          // Star label
          Center(
            child: Text(
              _selectedStars == 0
                  ? ''
                  : _selectedStars == 1
                      ? 'Poor 😞'
                      : _selectedStars == 2
                          ? 'Fair 😐'
                          : _selectedStars == 3
                              ? 'Good 🙂'
                              : _selectedStars == 4
                                  ? 'Great'
                                  : 'Excellent! 🤩',
              style: const TextStyle(
                color: Color(0xFFFF6B00),
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

          const SizedBox(height: 32),

          // Written review
          const Text(
            'Write a Review',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _reviewController,
            maxLines: 4,
            maxLength: 300,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText:
                  'Describe your experience with ${widget.workerName}...',
              hintStyle: const TextStyle(
                  color: Color(0xFF555555), fontSize: 13),
              filled: true,
              fillColor: const Color(0xFF1A1A1A),
              counterStyle:
                  const TextStyle(color: Color(0xFF555555)),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide:
                    const BorderSide(color: Color(0xFF2A2A2A)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide:
                    const BorderSide(color: Color(0xFF2A2A2A)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(
                    color: Color(0xFFFF6B00), width: 1.5),
              ),
              contentPadding: const EdgeInsets.all(16),
            ),
          ),

          const SizedBox(height: 32),

          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _submitRating,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF6B00),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2.5),
                    )
                  : const Text(
                      'Submit Rating',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
