import 'package:flutter/material.dart';

class CustomerHomeScreen extends StatefulWidget {
  const CustomerHomeScreen({super.key});

  @override
  State<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen> {
  int _currentIndex = 0;

  // Mock recent jobs
  final List<Map<String, dynamic>> _recentJobs = [
    {
      'title': 'Fix leaking pipe',
      'skill': 'Plumber',
      'status': 'active',
      'time': '2 mins ago',
      'applicants': 3,
    },
    {
      'title': 'Paint 2 bedroom apartment',
      'skill': 'Painter',
      'status': 'completed',
      'time': 'Yesterday',
      'applicants': 5,
    },
    {
      'title': 'Install ceiling fan',
      'skill': 'Electrician',
      'status': 'completed',
      'time': '2 days ago',
      'applicants': 2,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 24),
                    _buildPostJobBanner(),
                    const SizedBox(height: 28),
                    _buildSkillCategories(),
                    const SizedBox(height: 28),
                    _buildRecentJobs(),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.pushNamed(context, '/post-job'),
        backgroundColor: const Color(0xFFFF6B00),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Post Job',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                'Hello, John 👋',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'What do you need help with?',
                style: TextStyle(color: Color(0xFF888888), fontSize: 13),
              ),
            ],
          ),
          const Spacer(),
          CircleAvatar(
            radius: 22,
            backgroundColor: const Color(0xFF1A1A1A),
            child: const Icon(Icons.person, color: Color(0xFF888888)),
          ),
        ],
      ),
    );
  }

  Widget _buildPostJobBanner() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF6B00), Color(0xFFFF8C00)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Need a worker?',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Post a job and get\nalerts from nearby workers',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 14),
                ElevatedButton(
                  onPressed: () => Navigator.pushNamed(context, '/post-job'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFFFF6B00),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    elevation: 0,
                  ),
                  child: const Text('Post Now',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
          const Icon(Icons.handyman_rounded,
              color: Colors.white30, size: 80),
        ],
      ),
    );
  }

  Widget _buildSkillCategories() {
    final categories = [
      {'icon': Icons.plumbing, 'label': 'Plumber'},
      {'icon': Icons.electric_bolt, 'label': 'Electrician'},
      {'icon': Icons.cleaning_services, 'label': 'Cleaner'},
      {'icon': Icons.format_paint, 'label': 'Painter'},
      {'icon': Icons.carpenter, 'label': 'Carpenter'},
      {'icon': Icons.more_horiz, 'label': 'More'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Browse by Skill',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 14),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.1,
          ),
          itemCount: categories.length,
          itemBuilder: (context, i) {
            return GestureDetector(
              onTap: () {},
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF2A2A2A)),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(categories[i]['icon'] as IconData,
                        color: const Color(0xFFFF6B00), size: 28),
                    const SizedBox(height: 6),
                    Text(
                      categories[i]['label'] as String,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildRecentJobs() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Your Recent Jobs',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            TextButton(
              onPressed: () {},
              child: const Text('See all',
                  style: TextStyle(color: Color(0xFFFF6B00), fontSize: 13)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ..._recentJobs.map((job) => _buildJobCard(job)),
      ],
    );
  }

  Widget _buildJobCard(Map<String, dynamic> job) {
    final isActive = job['status'] == 'active';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive
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
              color: isActive
                  ? const Color(0xFFFF6B00).withOpacity(0.15)
                  : const Color(0xFF252525),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.work_outline,
              color: isActive
                  ? const Color(0xFFFF6B00)
                  : const Color(0xFF666666),
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  job['title'],
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF252525),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        job['skill'],
                        style: const TextStyle(
                            color: Color(0xFF888888), fontSize: 11),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      job['time'],
                      style: const TextStyle(
                          color: Color(0xFF555555), fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isActive
                      ? const Color(0xFFFF6B00).withOpacity(0.15)
                      : const Color(0xFF1E3A1E),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isActive ? 'Active' : 'Done',
                  style: TextStyle(
                    color: isActive
                        ? const Color(0xFFFF6B00)
                        : const Color(0xFF4CAF50),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${job['applicants']} applied',
                style: const TextStyle(
                    color: Color(0xFF555555), fontSize: 11),
              ),
            ],
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
        onTap: (i) => setState(() => _currentIndex = i),
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
