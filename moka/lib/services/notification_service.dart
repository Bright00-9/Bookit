import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'auth_service.dart';

// Global navigator key — used to navigate from notification tap
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// ✅ Background handler must be top-level AND initialize Firebase
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('Background message received: ${message.messageId}');
}

class NotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  // ✅ Create Android notification channel explicitly
  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'moka_jobs',
    'Job Alerts',
    description: 'Notifications for nearby job postings',
    importance: Importance.high,
  );

  static Future<void> initialize() async {
    // Request permission
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    debugPrint('Notification permission: ${settings.authorizationStatus}');

    // ✅ Create the Android notification channel
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);

    // Initialize local notifications with tap callback
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false, // already requested above
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        if (response.payload != null) {
          navigatorKey.currentState?.pushNamedAndRemoveUntil(
            '/worker-home',
            (route) => false,
          );
        }
      },
    );

    // ✅ Handle app opened from terminated state via notification
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationTap(initialMessage);
    }

    // Get FCM token and save to Supabase
    final token = await _messaging.getToken();
    if (token != null) {
      debugPrint('FCM Token: $token');
      await AuthService.updateFcmToken(token);
    }

    // Listen to token refresh
    _messaging.onTokenRefresh.listen((newToken) {
      AuthService.updateFcmToken(newToken);
    });

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _showLocalNotification(message);
    });

    // Handle notification tap when app is in background (not terminated)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _handleNotificationTap(message);
    });
  }

  // Show local notification when app is in foreground
  static Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    final androidDetails = AndroidNotificationDetails(
      _channel.id,
      _channel.name,
      channelDescription: _channel.description,
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      // ✅ Show heads-up notification on Android
      fullScreenIntent: message.data['urgency'] == 'emergency',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      id: notification.hashCode,
      title: notification.title ?? 'New Job Alert',
      body: notification.body ?? 'A new job is available near you',
      notificationDetails: details,
      payload: message.data['job_id'],
    );
  }

  static void _handleNotificationTap(RemoteMessage message) {
    final jobId = message.data['job_id'];
    if (jobId != null) {
      navigatorKey.currentState?.pushNamedAndRemoveUntil(
        '/worker-home',
        (route) => false,
      );
    }
  }
}
