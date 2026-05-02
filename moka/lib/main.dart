import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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

class MokaApp extends StatelessWidget {
  const MokaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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
      home: const AuthGate(),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/signup': (context) => const SignupScreen(),
        '/customer-home': (context) => const CustomerHomeScreen(),
        '/post-job': (context) => const PostJobScreen(),
        '/worker-home': (context) => const WorkerHomeScreen(),
      },
    );
  }
}

// Automatically routes user based on auth state + role
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFF0D0D0D),
            body: Center(
              child: CircularProgressIndicator(color: Color(0xFFFF6B00)),
            ),
          );
        }

        final session = snapshot.data?.session;

        if (session == null) {
          return const LoginScreen();
        }

        // Fetch role and redirect
        return FutureBuilder<Map<String, dynamic>?>(
          future: Supabase.instance.client
              .from('profiles')
              .select()
              .eq('id', session.user.id)
              .single(),
          builder: (context, profileSnapshot) {
            if (profileSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                backgroundColor: Color(0xFF0D0D0D),
                body: Center(
                  child:
                      CircularProgressIndicator(color: Color(0xFFFF6B00)),
                ),
              );
            }

            final role = profileSnapshot.data?['role'];

            if (role == 'worker') {
              return const WorkerHomeScreen();
            }
            return const CustomerHomeScreen();
          },
        );
      },
    );
  }
}
