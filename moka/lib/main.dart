import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'screens/splash_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/customer_home_screen.dart';
import 'screens/post_job_screen.dart';
import 'screens/worker_home_screen.dart';
import 'services/supabase_service.dart';
import 'services/notification_service.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Init Firebase
  await Firebase.initializeApp();

  // Register background message handler
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  // Init Supabase
  await initSupabase();

  // Init notifications
  await NotificationService.initialize();

  runApp(const MokaApp());
}

@override
void initState() {
  super.initState();
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    await NotificationService.initialize(context);
    await AppTipDialog.showIfEnabled(context);
  });
}

class MokaApp extends StatelessWidget {
  const MokaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Moka',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0D0D0D),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFFF6B00),
          secondary: Color(0xFFFF8C00),
          surface: Color(0xFF1A1A1A),
        ),
        useMaterial3: true,
      ),
      home: const SplashScreen(),
      routes: {
        '/onboarding': (context) => const OnboardingScreen(),
        '/login': (context) => const LoginScreen(),
        '/signup': (context) => const SignupScreen(),
        '/customer-home': (context) => const CustomerHomeScreen(),
        '/post-job': (context) => const PostJobScreen(),
        '/worker-home': (context) => const WorkerHomeScreen(),
      },
    );
  }
}
