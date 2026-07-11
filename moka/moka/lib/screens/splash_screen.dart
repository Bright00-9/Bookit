 import 'dart:math';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // ── Main logo animation ───────────────────────────────
  late AnimationController _logoController;
  late Animation<double> _logoFade;
  late Animation<double> _logoScale;
  late Animation<double> _logoRotate;

  // ── Text slide up animation ───────────────────────────
  late AnimationController _textController;
  late Animation<double> _textFade;
  late Animation<Offset> _textSlide;

  // ── Tagline animation ─────────────────────────────────
  late AnimationController _taglineController;
  late Animation<double> _taglineFade;

  // ── Floating icons animation ──────────────────────────
  late AnimationController _floatController;

  // ── Pulse ring animation ──────────────────────────────
  late AnimationController _pulseController;
  late Animation<double> _pulseScale;
  late Animation<double> _pulseOpacity;

  // ── Bottom bar animation ──────────────────────────────
  late AnimationController _bottomController;
  late Animation<double> _bottomFade;
  late Animation<Offset> _bottomSlide;

  // ── Loading dots ──────────────────────────────────────
  late AnimationController _dotsController;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _startAnimations();
    _navigate();
  }

  void _setupAnimations() {
    // Logo
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _logoFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
          parent: _logoController,
          curve: const Interval(0, 0.6,
              curve: Curves.easeOut)),
    );
    _logoScale = Tween<double>(begin: 0.3, end: 1).animate(
      CurvedAnimation(
          parent: _logoController,
          curve: Curves.elasticOut),
    );
    _logoRotate =
        Tween<double>(begin: -0.1, end: 0).animate(
      CurvedAnimation(
          parent: _logoController,
          curve: Curves.easeOut),
    );

    // Text
    _textController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _textFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
          parent: _textController,
          curve: Curves.easeOut),
    );
    _textSlide = Tween<Offset>(
      begin: const Offset(0, 0.4),
      end: Offset.zero,
    ).animate(CurvedAnimation(
        parent: _textController,
        curve: Curves.easeOut));

    // Tagline
    _taglineController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _taglineFade =
        Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
          parent: _taglineController,
          curve: Curves.easeIn),
    );

    // Floating icons — continuous loop
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    // Pulse ring
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: false);
    _pulseScale =
        Tween<double>(begin: 1.0, end: 2.0).animate(
      CurvedAnimation(
          parent: _pulseController,
          curve: Curves.easeOut),
    );
    _pulseOpacity =
        Tween<double>(begin: 0.4, end: 0.0).animate(
      CurvedAnimation(
          parent: _pulseController,
          curve: Curves.easeOut),
    );

    // Bottom
    _bottomController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _bottomFade =
        Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
          parent: _bottomController,
          curve: Curves.easeIn),
    );
    _bottomSlide = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
        parent: _bottomController,
        curve: Curves.easeOut));

    // Dots
    _dotsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  Future<void> _startAnimations() async {
    await Future.delayed(
        const Duration(milliseconds: 100));
    _logoController.forward();

    await Future.delayed(
        const Duration(milliseconds: 500));
    _textController.forward();

    await Future.delayed(
        const Duration(milliseconds: 300));
    _taglineController.forward();

    await Future.delayed(
        const Duration(milliseconds: 400));
    _bottomController.forward();
  }

  // ── Navigation with timeout safety ───────────────────
  Future<void> _navigate() async {
    await Future.delayed(
        const Duration(milliseconds: 2800));
    if (!mounted) return;

    try {
      await Future.any([
        _doAuthCheck(),
        Future.delayed(
          const Duration(seconds: 5),
          () => _goTo('/onboarding'),
        ),
      ]);
    } catch (_) {
      _goTo('/onboarding');
    }
  }

  Future<void> _doAuthCheck() async {
    final session =
        Supabase.instance.client.auth.currentSession;

    if (session == null) {
      _goTo('/onboarding');
      return;
    }

    // Refresh if expired
    if (session.isExpired) {
      try {
        final refreshed = await Supabase
            .instance.client.auth
            .refreshSession();
        if (refreshed.session == null) {
          _goTo('/onboarding');
          return;
        }
      } catch (_) {
        _goTo('/onboarding');
        return;
      }
    }

    // Fetch profile with timeout
    try {
      final profile = await AuthService
          .getCurrentProfile()
          .timeout(
        const Duration(seconds: 4),
        onTimeout: () => null,
      );

      if (!mounted) return;

      if (profile == null) {
        await Supabase.instance.client.auth
            .signOut();
        _goTo('/onboarding');
        return;
      }

      // Create settings if first login
      await AuthService.initSettingsAfterLogin();

      final role =
          profile['role'] ?? 'customer';

      if (role == 'worker') {
        _goTo('/worker-home');
      } else if (role == 'admin') {
        _goTo('/admin');
      } else {
        _goTo('/customer-home');
      }
    } catch (_) {
      _goTo('/onboarding');
    }
  }

  void _goTo(String route) {
    if (!mounted) return;
    Navigator.pushReplacementNamed(
        context, route);
  }

  @override
  void dispose() {
    _logoController.dispose();
    _textController.dispose();
    _taglineController.dispose();
    _floatController.dispose();
    _pulseController.dispose();
    _bottomController.dispose();
    _dotsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: Stack(
        children: [
          // ── Background grid pattern ─────────────────
          Positioned.fill(
            child: CustomPaint(
              painter: _GridPainter(),
            ),
          ),

          // ── Floating skill icons ────────────────────
          ..._buildFloatingIcons(size),

          // ── Orange glow behind logo ─────────────────
          Center(
            child: AnimatedBuilder(
              animation: _logoController,
              builder: (_, __) => Opacity(
                opacity: _logoFade.value * 0.3,
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(
                            0xFFFF6B00),
                        blurRadius: 120,
                        spreadRadius: 40,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── Main content ────────────────────────────
          Center(
            child: Column(
              mainAxisAlignment:
                  MainAxisAlignment.center,
              children: [
                // ── Pulse ring + Logo ───────────────
                AnimatedBuilder(
                  animation: Listenable.merge([
                    _logoController,
                    _pulseController,
                  ]),
                  builder: (_, __) => Stack(
                    alignment: Alignment.center,
                    children: [
                      // Outer pulse ring
                      Transform.scale(
                        scale: _pulseScale.value,
                        child: Opacity(
                          opacity:
                              _pulseOpacity.value *
                                  _logoFade.value,
                          child: Container(
                            width: 90,
                            height: 90,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(
                                    0xFFFF6B00),
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Inner pulse ring
                      Transform.scale(
                        scale: 1 +
                            (_pulseScale.value -
                                    1) *
                                0.5,
                        child: Opacity(
                          opacity:
                              _pulseOpacity.value *
                                  0.6 *
                                  _logoFade.value,
                          child: Container(
                            width: 90,
                            height: 90,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(
                                    0xFFFF6B00),
                                width: 1.5,
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Logo box
                      FadeTransition(
                        opacity: _logoFade,
                        child: ScaleTransition(
                          scale: _logoScale,
                          child: Transform.rotate(
                            angle: _logoRotate.value,
                            child: Container(
                              width: 90,
                              height: 90,
                              decoration: BoxDecoration(
                                gradient:
                                    const LinearGradient(
                                  colors: [
                                    Color(0xFFFF8C00),
                                    Color(0xFFFF6B00),
                                    Color(0xFFE55A00),
                                  ],
                                  begin:
                                      Alignment.topLeft,
                                  end: Alignment
                                      .bottomRight,
                                ),
                                borderRadius:
                                    BorderRadius
                                        .circular(26),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(
                                            0xFFFF6B00)
                                        .withOpacity(
                                            0.5),
                                    blurRadius: 30,
                                    spreadRadius: 4,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.handyman_rounded,
                                color: Colors.white,
                                size: 46,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                // ── App name ────────────────────────
                FadeTransition(
                  opacity: _textFade,
                  child: SlideTransition(
                    position: _textSlide,
                    child: Column(
                      children: [
                        ShaderMask(
                          shaderCallback: (bounds) =>
                              const LinearGradient(
                            colors: [
                              Colors.white,
                              Color(0xFFFFB366),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ).createShader(bounds),
                          child: const Text(
                            'MoKa',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 52,
                              fontWeight:
                                  FontWeight.w900,
                              letterSpacing: -2,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),

                        // Animated underline
                        AnimatedBuilder(
                          animation: _textController,
                          builder: (_, __) => Container(
                            width: 60 *
                                _textFade.value,
                            height: 3,
                            decoration: BoxDecoration(
                              gradient:
                                  const LinearGradient(
                                colors: [
                                  Color(0xFFFF6B00),
                                  Color(0xFFFFB366),
                                ],
                              ),
                              borderRadius:
                                  BorderRadius.circular(
                                      2),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // ── Tagline ──────────────────────────
                FadeTransition(
                  opacity: _taglineFade,
                  child: const Text(
                    'Workers at your fingertips',
                    style: TextStyle(
                      color: Color(0xFF888888),
                      fontSize: 15,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // ── Skill chips ──────────────────────
                FadeTransition(
                  opacity: _taglineFade,
                  child: Wrap(
                    spacing: 8,
                    children: [
                      _skillChip(
                          Icons.plumbing, 'Plumber'),
                      _skillChip(
                          Icons.electrical_services, 'Electrician'),
                      _skillChip(
                          Icons.cleaning_services, 'Cleaner'),
                      _skillChip(
                          Icons.carpenter, 'Carpenter'),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Bottom section ──────────────────────────
          Positioned(
            bottom: 48,
            left: 0,
            right: 0,
            child: FadeTransition(
              opacity: _bottomFade,
              child: SlideTransition(
                position: _bottomSlide,
                child: Column(
                  children: [
                    // Loading dots
                    AnimatedBuilder(
                      animation: _dotsController,
                      builder: (_, __) => Row(
                        mainAxisAlignment:
                            MainAxisAlignment.center,
                        children: List.generate(3, (i) {
                          final delay = i * 0.33;
                          final t =
                              (_dotsController.value +
                                      delay) %
                                  1.0;
                          final scale =
                              0.5 + 0.5 * sin(t * pi);
                          return Container(
                            margin:
                                const EdgeInsets.symmetric(
                                    horizontal: 4),
                            width: 8 * scale,
                            height: 8 * scale,
                            decoration: BoxDecoration(
                              color: Color.lerp(
                                const Color(0xFF444444),
                                const Color(0xFFFF6B00),
                                scale,
                              ),
                              shape: BoxShape.circle,
                            ),
                          );
                        }),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Version
                    const Text(
                      'v1.0.0',
                      style: TextStyle(
                        color: Color(0xFF333333),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Skill chip ────────────────────────────────────────
  Widget _skillChip(IconData icon, String label) {
    return AnimatedBuilder(
      animation: _taglineController,
      builder: (_, __) => Opacity(
        opacity: _taglineFade.value,
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: const Color(0xFF2A2A2A)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  style: const TextStyle(
                      fontSize: 12)),
              const SizedBox(width: 4),
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF888888),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Floating skill icons in background ───────────────
  List<Widget> _buildFloatingIcons(Size size) {
    final icons = [
      (Icons.plumbing, 0.12, 0.15, 1.0),
      (Icons.electric_bolt, 0.82, 0.10, 1.4),
      (Icons.cleaning_services, 0.08, 0.72, 0.8),
      (Icons.carpenter, 0.85, 0.68, 1.2),
      (Icons.format_paint, 0.20, 0.88, 0.6),
      (Icons.build, 0.75, 0.85, 1.0),
      (Icons.construction, 0.50, 0.08, 0.7),
      (Icons.home_repair_service, 0.45, 0.92, 0.9),
    ];

    return icons.map((item) {
      final icon = item.$1 as IconData;
      final x = item.$2 as double;
      final y = item.$3 as double;
      final speed = item.$4 as double;

      return AnimatedBuilder(
        animation: _floatController,
        builder: (_, __) {
          final t = _floatController.value *
              2 *
              pi *
              speed;
          final offsetY = sin(t) * 8;
          final opacity =
              0.06 + 0.04 * sin(t + pi / 3);

          return Positioned(
            left: size.width * x,
            top: size.height * y + offsetY,
            child: Opacity(
              opacity: opacity,
              child: Icon(
                icon,
                color: const Color(0xFFFF6B00),
                size: 28,
              ),
            ),
          );
        },
      );
    }).toList();
  }
}

// ── Background grid painter ───────────────────────────────
class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFFF6B00).withOpacity(0.03)
      ..strokeWidth = 1;

    const spacing = 40.0;

    // Vertical lines
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        paint,
      );
    }

    // Horizontal lines
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        paint,
      );
    }

    // Corner dots at intersections
    final dotPaint = Paint()
      ..color =
          const Color(0xFFFF6B00).withOpacity(0.06)
      ..style = PaintingStyle.fill;

    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0;
          y < size.height;
          y += spacing) {
        canvas.drawCircle(Offset(x, y), 1.5, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) =>
      false;
}