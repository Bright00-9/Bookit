import 'package:flutter/material.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<Map<String, dynamic>> _pages = [
    {
      'icon': Icons.handyman_rounded,
      'color': Color(0xFFFF6B00),
      'title': 'Find Workers\nInstantly',
      'subtitle':
          'Post any job and get alerts\nto skilled workers near you in seconds.',
      'bg': Color(0xFF1A0A00),
    },
    {
      'icon': Icons.location_on_rounded,
      'color': Color(0xFF4CAF50),
      'title': 'Location-Based\nMatching',
      'subtitle':
          'Workers nearby get notified\nautomatically. No scrolling, no searching.',
      'bg': Color(0xFF001A00),
    },
    {
      'icon': Icons.verified_rounded,
      'color': Color(0xFF2196F3),
      'title': 'Trusted &\nReliable',
      'subtitle':
          'Rate workers after every job.\nBuild a community of trusted professionals.',
      'bg': Color(0xFF00091A),
    },
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: SafeArea(
        child: Column(
          children: [
            // Skip button
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 16, 20, 0),
                child: TextButton(
                  onPressed: () =>
                      Navigator.pushReplacementNamed(context, '/login'),
                  child: const Text(
                    'Skip',
                    style: TextStyle(
                        color: Color(0xFF888888),
                        fontSize: 14,
                        fontWeight: FontWeight.w500),
                  ),
                ),
              ),
            ),

            // Pages
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemCount: _pages.length,
                itemBuilder: (context, i) => _buildPage(_pages[i]),
              ),
            ),

            // Bottom controls
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 0, 28, 40),
              child: Column(
                children: [
                  // Dots
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _pages.length,
                      (i) => AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: _currentPage == i ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _currentPage == i
                              ? const Color(0xFFFF6B00)
                              : const Color(0xFF2A2A2A),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Next / Get Started button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _nextPage,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF6B00),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        _currentPage == _pages.length - 1
                            ? 'Get Started'
                            : 'Next',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Login link
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Already have an account?',
                        style: TextStyle(
                            color: Color(0xFF888888), fontSize: 14),
                      ),
                      TextButton(
                        onPressed: () =>
                            Navigator.pushReplacementNamed(context, '/login'),
                        child: const Text(
                          'Sign In',
                          style: TextStyle(
                            color: Color(0xFFFF6B00),
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPage(Map<String, dynamic> page) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon container with glow
          Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              color: (page['color'] as Color).withOpacity(0.12),
              shape: BoxShape.circle,
              border: Border.all(
                color: (page['color'] as Color).withOpacity(0.3),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: (page['color'] as Color).withOpacity(0.2),
                  blurRadius: 40,
                  spreadRadius: 10,
                ),
              ],
            ),
            child: Icon(
              page['icon'] as IconData,
              color: page['color'] as Color,
              size: 64,
            ),
          ),

          const SizedBox(height: 48),

          Text(
            page['title'] as String,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 34,
              fontWeight: FontWeight.w900,
              height: 1.15,
              letterSpacing: -0.5,
            ),
          ),

          const SizedBox(height: 16),

          Text(
            page['subtitle'] as String,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF888888),
              fontSize: 16,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
