import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../services/auth_service.dart';
import '../services/job_service.dart';
import 'job_detail_screen.dart';
import 'messages_screen.dart';
import 'profile_screen.dart';
import 'worker_my_jobs_screen.dart';
import 'create_portfolio_post_screen.dart';

class WorkerHomeScreen extends StatefulWidget {
  const WorkerHomeScreen({super.key});

  @override
  State<WorkerHomeScreen> createState() => _WorkerHomeScreenState();
}

class _WorkerHomeScreenState extends State<WorkerHomeScreen> {
  bool _isOnline = false;
  int _currentIndex = 0;
  List<Map<String, dynamic>> _nearbyJobs = [];
  Map<String, dynamic>? _profile;
  bool _isLoadingJobs = false;
  double? _lat;
  double? _lng;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final profile = await AuthService.getCurrentProfile();
    setState(() => _profile = profile);
  }

  Future<void> _toggleOnline(bool value) async {
    setState(() => _isOnline = value);
    if (value) {
      try {
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
        _lat = position.latitude;
        _lng = position.longitude;

        await AuthService.updateWorkerStatus(
          isOnline: true,
          lat: _lat,
          lng: _lng,
        );
        await _loadNearbyJobs();
      } catch (e) {
        setState(() => _isOnline = false);
      }
    } else {
      await AuthService.updateWorkerStatus(isOnline: false);
      setState(() => _nearbyJobs = []);
    }
  }

  Future<void> _loadNearbyJobs() async {
    if (_lat == null || _lng == null || _profile == null) return;
    setState(() => _isLoadingJobs = true);
    try {
      final jobs = await JobService.getNearbyJobs(
        skill: _profile!['skill'] ?? '',
        lat: _lat!,
        lng: _lng!,
      );
      setState(() => _nearbyJobs = jobs);
    } catch (e) {
      debugPrint('Error loading jobs: $e');
    } finally {
      setState(() => _isLoadingJobs = false);
    }
  }

  Future<void> _acceptJob(String jobId) async {
    try {
      await JobService.applyToJob(jobId);
      setState(() => _nearbyJobs.removeWhere((j) => j['id'] == jobId));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Job accepted! Head to the customer location.'),
          backgroundColor: const Color(0xFF4CAF50),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Could not accept job. Try again.'),
          backgroundColor: const Color(0xFFE53935),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  String _timeAgo(String? createdAt) {
    if (createdAt == null) return '';
    final diff = DateTime.now().difference(DateTime.parse(createdAt));
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} mins ago';
    if (diff.inHours < 24) return '${diff.inHours} hrs ago';
    return '${diff.inDays} days ago';
  }

  String _distanceLabel(Map<String, dynamic> job) {
    if (_lat == null || _lng == null) return '';
    final d = JobService.distanceBetween(
      _lat!, _lng!,
      (job['lat'] as num).toDouble(),
      (job['lng'] as num).toDouble(),
    );
    return '${d.toStringAsFixed(1)} km';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildOnlineToggle(),
            Expanded(
              child: _isOnline ? _buildJobList() : _buildOfflineState(),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => const CreatePortfolioPostScreen()),
        ),
        backgroundColor: const Color(0xFFFF6B00),
        icon: const Icon(Icons.add_photo_alternate, color: Colors.white),
        label: const Text('Share Work',
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _buildHeader() {
    final name = _profile?['name'] ?? 'Worker';
    final skill = _profile?['skill'] ?? '';
    final rating = _profile?['rating'] ?? 0.0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hey, $name 👷',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '$skill • ⭐ $rating',
                style: const TextStyle(
                    color: Color(0xFF888888), fontSize: 13),
              ),
            ],
          ),
          const Spacer(),
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProfileScreen()),
            ),
            child: Stack(
              children: [
                const CircleAvatar(
                  radius: 22,
                  backgroundColor: Color(0xFF1A1A1A),
                  child: Icon(Icons.person, color: Color(0xFF888888)),
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: _isOnline
                          ? const Color(0xFF4CAF50)
                          : const Color(0xFF555555),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: const Color(0xFF0D0D0D), width: 2),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOnlineToggle() {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isOnline
              ? const Color(0xFF4CAF50).withOpacity(0.4)
              : const Color(0xFF2A2A2A),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: _isOnline
                  ? const Color(0xFF4CAF50)
                  : const Color(0xFF555555),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isOnline ? 'You are Online' : 'You are Offline',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                Text(
                  _isOnline
                      ? 'Receiving job alerts nearby'
                      : 'Toggle on to receive job alerts',
                  style: const TextStyle(
                      color: Color(0xFF888888), fontSize: 12),
                ),
              ],
            ),
          ),
          Switch(
            value: _isOnline,
            onChanged: _toggleOnline,
            activeColor: const Color(0xFF4CAF50),
            inactiveThumbColor: const Color(0xFF555555),
            inactiveTrackColor: const Color(0xFF2A2A2A),
          ),
        ],
      ),
    );
  }

  Widget _buildJobList() {
    if (_isLoadingJobs) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFFF6B00)),
      );
    }

    if (_nearbyJobs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search_off_rounded,
                color: Color(0xFF555555), size: 48),
            const SizedBox(height: 12),
            const Text('No nearby jobs right now',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            const Text('Check back soon or wait for new alerts',
                style: TextStyle(color: Color(0xFF888888), fontSize: 13)),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: _loadNearbyJobs,
              icon: const Icon(Icons.refresh, color: Color(0xFFFF6B00)),
              label: const Text('Refresh',
                  style: TextStyle(color: Color(0xFFFF6B00))),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              const Text(
                'Nearby Jobs',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF6B00).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${_nearbyJobs.length} new',
                  style: const TextStyle(
                    color: Color(0xFFFF6B00),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: _nearbyJobs.length,
            itemBuilder: (context, i) {
              final job = _nearbyJobs[i];
              return GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => JobDetailScreen(job: job),
                  ),
                ),
                child: _buildJobAlert(job),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildJobAlert(Map<String, dynamic> job) {
    final urgency = job['urgency'] ?? 'normal';
    Color urgencyColor = const Color(0xFF4CAF50);
    String urgencyLabel = 'Normal';
    if (urgency == 'urgent') {
      urgencyColor = const Color(0xFFFF9800);
      urgencyLabel = 'Urgent';
    }
    if (urgency == 'emergency') {
      urgencyColor = const Color(0xFFF44336);
      urgencyLabel = 'Emergency';
    }

    final customer = job['profiles'];
    final customerName = customer?['name'] ?? 'Customer';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: urgency == 'emergency'
              ? const Color(0xFFF44336).withOpacity(0.4)
              : const Color(0xFF2A2A2A),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: urgencyColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(urgencyLabel,
                    style: TextStyle(
                        color: urgencyColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF252525),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(job['skill_needed'] ?? '',
                    style: const TextStyle(
                        color: Color(0xFF888888), fontSize: 11)),
              ),
              const Spacer(),
              Text(_timeAgo(job['created_at']),
                  style: const TextStyle(
                      color: Color(0xFF555555), fontSize: 11)),
            ],
          ),
          const SizedBox(height: 10),
          Text(job['title'] ?? '',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.location_on_outlined,
                  color: Color(0xFF888888), size: 14),
              const SizedBox(width: 4),
              Text('${_distanceLabel(job)} away',
                  style: const TextStyle(
                      color: Color(0xFF888888), fontSize: 12)),
              const SizedBox(width: 12),
              const Icon(Icons.person_outline,
                  color: Color(0xFF888888), size: 14),
              const SizedBox(width: 4),
              Text(customerName,
                  style: const TextStyle(
                      color: Color(0xFF888888), fontSize: 12)),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () =>
                      setState(() => _nearbyJobs.remove(job)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF888888),
                    side: const BorderSide(color: Color(0xFF2A2A2A)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  child: const Text('Decline',
                      style: TextStyle(fontSize: 13)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: () => _acceptJob(job['id']),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF6B00),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    elevation: 0,
                  ),
                  child: const Text('Accept Job',
                      style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOfflineState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: const BoxDecoration(
              color: Color(0xFF1A1A1A),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.wifi_off_rounded,
                color: Color(0xFF555555), size: 36),
          ),
          const SizedBox(height: 16),
          const Text(
            'You\'re Offline',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Toggle online to start\nreceiving job alerts',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF888888), fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF111111),
        border: Border(top: BorderSide(color: Color(0xFF1F1F1F))),
      ),
      child: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) {
          setState(() => _currentIndex = i);
          if (i == 1) {
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const WorkerMyJobsScreen()),
            );
          } else if (i == 2) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MessagesScreen()),
            );
          } else if (i == 3) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProfileScreen()),
            );
          }
        },
        backgroundColor: Colors.transparent,
        selectedItemColor: const Color(0xFFFF6B00),
        unselectedItemColor: const Color(0xFF555555),
        elevation: 0,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'Home'),
          BottomNavigationBarItem(
              icon: Icon(Icons.work_outline),
              activeIcon: Icon(Icons.work),
              label: 'My Jobs'),
          BottomNavigationBarItem(
              icon: Icon(Icons.chat_bubble_outline),
              activeIcon: Icon(Icons.chat_bubble),
              label: 'Messages'),
          BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'Profile'),
        ],
      ),
    );
  }
}
