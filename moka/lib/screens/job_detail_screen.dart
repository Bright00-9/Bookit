import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/job_service.dart';
import 'job_map_screen.dart';

class JobDetailScreen extends StatefulWidget {
  final Map<String, dynamic> job;

  const JobDetailScreen({super.key, required this.job});

  @override
  State<JobDetailScreen> createState() => _JobDetailScreenState();
}

class _JobDetailScreenState extends State<JobDetailScreen> {
  bool _isAccepting = false;
  bool _isAccepted = false;

  String get _urgency => widget.job['urgency'] ?? 'normal';
  String get _title => widget.job['title'] ?? '';
  String get _description => widget.job['description'] ?? 'No description provided.';
  String get _skill => widget.job['skill_needed'] ?? '';
  String get _status => widget.job['status'] ?? 'open';
  double? get _lat => (widget.job['lat'] as num?)?.toDouble();
  double? get _lng => (widget.job['lng'] as num?)?.toDouble();

  Map<String, dynamic>? get _customer => widget.job['profiles'];
  String get _customerName => _customer?['name'] ?? 'Customer';
  String get _customerPhone => _customer?['phone'] ?? '';

  Color get _urgencyColor {
    if (_urgency == 'emergency') return const Color(0xFFF44336);
    if (_urgency == 'urgent') return const Color(0xFFFF9800);
    return const Color(0xFF4CAF50);
  }

  String get _urgencyLabel {
    if (_urgency == 'emergency') return '🚨 Emergency';
    if (_urgency == 'urgent') return '⚡ Urgent';
    return '🔔 Normal';
  }

  String _timeAgo(String? createdAt) {
    if (createdAt == null) return '';
    final diff = DateTime.now().difference(DateTime.parse(createdAt));
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} mins ago';
    if (diff.inHours < 24) return '${diff.inHours} hrs ago';
    return '${diff.inDays} days ago';
  }

  Future<void> _acceptJob() async {
    setState(() => _isAccepting = true);
    try {
      await JobService.applyToJob(widget.job['id']);
      setState(() => _isAccepted = true);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Job accepted! Head to the customer location.'),
          backgroundColor: const Color(0xFF4CAF50),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Could not accept job. Try again.'),
          backgroundColor: const Color(0xFFE53935),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } finally {
      if (mounted) setState(() => _isAccepting = false);
    }


  Future<void> _callCustomer() async {
    if (_customerPhone.isEmpty) return;
    final uri = Uri(scheme: 'tel', path: _customerPhone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
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
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildUrgencyBadge(),
                    const SizedBox(height: 16),
                    _buildJobTitle(),
                    const SizedBox(height: 24),
                    _buildInfoCards(),
                    const SizedBox(height: 24),
                    _buildDescription(),
                    const SizedBox(height: 24),
                    _buildCustomerCard(),
                    const SizedBox(height: 24),
                    _buildLocationCard(),
                    const SizedBox(height: 100), // space for bottom button
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomSheet: _buildBottomActions(),
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 20, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_ios_new,
                color: Colors.white, size: 20),
          ),
          const Text(
            'Job Details',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          Text(
            _timeAgo(widget.job['created_at']),
            style: const TextStyle(color: Color(0xFF888888), fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildUrgencyBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _urgencyColor.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _urgencyColor.withOpacity(0.4)),
      ),
      child: Text(
        _urgencyLabel,
        style: TextStyle(
          color: _urgencyColor,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildJobTitle() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 26,
            fontWeight: FontWeight.w800,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF2A2A2A)),
          ),
          child: Text(
            _skill,
            style: const TextStyle(
              color: Color(0xFFFF6B00),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCards() {
    return Row(
      children: [
        _buildInfoTile(
          icon: Icons.circle,
          iconColor: _status == 'open'
              ? const Color(0xFF4CAF50)
              : const Color(0xFFFF9800),
          label: 'Status',
          value: _status == 'open' ? 'Open' : 'Accepted',
        ),
        const SizedBox(width: 12),
        _buildInfoTile(
          icon: Icons.location_on_outlined,
          iconColor: const Color(0xFFFF6B00),
          label: 'Location',
          value: _lat != null
              ? '${_lat!.toStringAsFixed(3)}, ${_lng!.toStringAsFixed(3)}'
              : 'Unknown',
        ),
      ],
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF2A2A2A)),
        ),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          color: Color(0xFF888888), fontSize: 11)),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDescription() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Job Description',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF2A2A2A)),
          ),
          child: Text(
            _description,
            style: const TextStyle(
              color: Color(0xFFCCCCCC),
              fontSize: 14,
              height: 1.6,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCustomerCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Posted By',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF2A2A2A)),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: const Color(0xFF252525),
                child: Text(
                  _customerName.isNotEmpty
                      ? _customerName[0].toUpperCase()
                      : 'C',
                  style: const TextStyle(
                    color: Color(0xFFFF6B00),
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _customerName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (_customerPhone.isNotEmpty)
                      Text(
                        _customerPhone,
                        style: const TextStyle(
                            color: Color(0xFF888888), fontSize: 13),
                      ),
                  ],
                ),
              ),
              if (_isAccepted && _customerPhone.isNotEmpty)
                GestureDetector(
                  onTap: _callCustomer,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFF4CAF50).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: const Color(0xFF4CAF50).withOpacity(0.4)),
                    ),
                    child: const Icon(Icons.phone,
                        color: Color(0xFF4CAF50), size: 20),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLocationCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Job Location',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: _isAccepted
              ? () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => JobMapScreen(
                        job: widget.job,
                        isWorker: true,
                      ),
                    ),
                  )
              : null,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _isAccepted
                    ? const Color(0xFFFF6B00).withOpacity(0.4)
                    : const Color(0xFF2A2A2A),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF6B00).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.map_outlined,
                      color: Color(0xFFFF6B00), size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isAccepted
                            ? 'Tap to open live map'
                            : 'Accept job to see full location',
                        style: TextStyle(
                          color: _isAccepted
                              ? Colors.white
                              : const Color(0xFF888888),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (_lat != null)
                        Text(
                          _isAccepted
                              ? '${_lat?.toStringAsFixed(4)}, ${_lng?.toStringAsFixed(4)}'
                              : '📍 Location hidden until accepted',
                          style: const TextStyle(
                              color: Color(0xFF888888), fontSize: 12),
                        ),
                    ],
                  ),
                ),
                if (_isAccepted)
                  const Icon(Icons.arrow_forward_ios,
                      color: Color(0xFFFF6B00), size: 16),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomActions() {
    if (_isAccepted) {
      return Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        decoration: const BoxDecoration(
          color: Color(0xFF111111),
          border: Border(top: BorderSide(color: Color(0xFF1F1F1F))),
        ),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _callCustomer,
                icon: const Icon(Icons.phone, size: 18),
                label: const Text('Call Customer'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF4CAF50),
                  side: const BorderSide(color: Color(0xFF4CAF50)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => JobMapScreen(
                      job: widget.job,
                      isWorker: true,
                    ),
                  ),
                ),
                icon: const Icon(Icons.navigation, size: 18),
                label: const Text('Navigate'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF6B00),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      decoration: const BoxDecoration(
        color: Color(0xFF111111),
        border: Border(top: BorderSide(color: Color(0xFF1F1F1F))),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF888888),
                side: const BorderSide(color: Color(0xFF2A2A2A)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('Decline',
                  style: TextStyle(fontSize: 15)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: _isAccepting ? null : _acceptJob,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF6B00),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                elevation: 0,
              ),
              child: _isAccepting
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2.5),
                    )
                  : const Text(
                      'Accept Job',
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
