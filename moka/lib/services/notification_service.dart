import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'auth_service.dart';
import 'dart:typed_data';

// Global navigator key — used to navigate from notification tap
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// Background handler — must be top-level AND initialize Firebase
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('Background message: ${message.messageId}');
}

class NotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  // ─── Notification Channels ──────────────────────────────────────────────────
  // Normal jobs channel
  static final AndroidNotificationChannel _jobsChannel =
      AndroidNotificationChannel(
    'moka_jobs',
    'Job Alerts',
    description: 'Notifications for nearby job postings',
    importance: Importance.high,
    sound: const RawResourceAndroidNotificationSound('notification_sound'),
    enableVibration: true,
    vibrationPattern: Int64List.fromList([0, 250, 250, 250]),
    playSound: true,
    showBadge: true,
  );

  // Emergency jobs channel — max priority
  static final AndroidNotificationChannel _emergencyChannel =
      AndroidNotificationChannel(
    'moka_emergency',
    'Emergency Job Alerts',
    description: 'High priority emergency job notifications',
    importance: Importance.max,
    sound: const RawResourceAndroidNotificationSound('notification_sound'),
    enableVibration: true,
    vibrationPattern: Int64List.fromList([0, 500, 200, 500, 200, 500]),
    playSound: true,
    showBadge: true,
    enableLights: true,
    ledColor: Color(0xFFF44336),
  );

  static Future<void> initialize() async {
    // ── 1. Request permissions ───────────────────────────────────────────────
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      criticalAlert: true, // iOS critical alerts bypass silent mode
      provisional: false,
    );
    debugPrint('Permission: ${settings.authorizationStatus}');

    // ── 2. Set foreground notification presentation (iOS) ────────────────────
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // ── 3. Create Android notification channels ──────────────────────────────
    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    await androidPlugin?.createNotificationChannel(_jobsChannel);
    await androidPlugin?.createNotificationChannel(_emergencyChannel);

    // Request exact alarm permission (Android 12+)
    await androidPlugin?.requestExactAlarmsPermission();
    await androidPlugin?.requestNotificationsPermission();

    // ── 4. Initialize local notifications ───────────────────────────────────
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _localNotifications.initialize(
      settings: InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        _navigateFromPayload(response.payload);
      },
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

    // ── 5. Handle app opened from terminated state ───────────────────────────
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      Future.delayed(const Duration(seconds: 1), () {
        _handleNotificationTap(initialMessage);
      });
    }

    // ── 6. Save FCM token ────────────────────────────────────────────────────
    final token = await _messaging.getToken();
    if (token != null) {
      debugPrint('FCM Token: $token');
      await AuthService.updateFcmToken(token);
    }
    _messaging.onTokenRefresh
        .listen((token) => AuthService.updateFcmToken(token));

    // ── 7. Foreground messages ───────────────────────────────────────────────
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _showLocalNotification(message);
    });

    // ── 8. Background tap (app was in background, not terminated) ───────────
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _handleNotificationTap(message);
    });
  }

  // ─── Show heads-up notification ─────────────────────────────────────────────
  static Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    final urgency = message.data['urgency'] ?? 'normal';
    final isEmergency = urgency == 'emergency';
    final channel = isEmergency ? _emergencyChannel : _jobsChannel;

    final androidDetails = AndroidNotificationDetails(
      channel.id,
      channel.name,
      channelDescription: channel.description,
      importance: isEmergency ? Importance.max : Importance.high,
      priority: isEmergency ? Priority.max : Priority.high,
      icon: '@mipmap/ic_launcher',
      largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
      sound: const RawResourceAndroidNotificationSound('notification_sound'),
      playSound: true,
      enableVibration: true,
      vibrationPattern: isEmergency
          ? Int64List.fromList([0, 500, 200, 500, 200, 500])
          : Int64List.fromList([0, 250, 250, 250]),

      // ✅ This makes it pop up like WhatsApp
      fullScreenIntent: isEmergency,

      // ✅ Heads-up notification (shows on top of screen)
      visibility: NotificationVisibility.public,
      category: AndroidNotificationCategory.message,

      // Style with big text
      styleInformation: BigTextStyleInformation(
        notification.body ?? 'A new job is available near you',
        htmlFormatBigText: false,
        contentTitle: notification.title ?? 'New Job Alert 🔔',
        summaryText: urgency == 'urgent'
            ? '⚡ Urgent'
            : urgency == 'emergency'
                ? '🚨 Emergency'
                : '🔔 New Job',
      ),

      // Show on lock screen
      ticker: notification.title,
      showWhen: true,
      when: DateTime.now().millisecondsSinceEpoch,
      colorized: true,
      color: isEmergency ? const Color(0xFFF44336) : const Color(0xFFFF6B00),
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.active,
    );

    await _localNotifications.show(
      id: notification.hashCode,
      title: notification.title ?? 'New Job Alert',
      body: notification.body ?? 'A new job is available near you',
      notificationDetails: NotificationDetails(android: androidDetails, iOS: iosDetails),
      payload: message.data['job_id'],
    );
  }

  static void _handleNotificationTap(RemoteMessage message) {
    _navigateFromPayload(message.data['job_id']);
  }

  static void _navigateFromPayload(String? payload) {
    if (payload != null) {
      navigatorKey.currentState?.pushNamedAndRemoveUntil(
        '/worker-home',
        (route) => false,
      );
    }
  }
}

// Background notification tap handler — must be top-level
@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse response) {
  debugPrint('Background notification tapped: ${response.payload}');
}
