import 'dart:typed_data';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'auth_service.dart';

// Global navigator key — used to navigate on notification tap
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// ─── Background handler (top-level, required by Firebase) ────────────────────
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('BG message: ${message.messageId}');
}

// ─── Background tap handler (top-level, required by flutter_local_notifications)
@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse response) {
  debugPrint('BG tap: ${response.payload}');
}

class NotificationService {
  static final _messaging = FirebaseMessaging.instance;
  static final _localNotifications = FlutterLocalNotificationsPlugin();

  // ─── Channels ────────────────────────────────────────────────────────────
  static final _jobsChannel = AndroidNotificationChannel(
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

  static final _emergencyChannel = AndroidNotificationChannel(
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
    ledColor: const Color(0xFFF44336),
  );

  static final _chatChannel = AndroidNotificationChannel(
    'moka_chat',
    'Chat Messages',
    description: 'Notifications for new chat messages',
    importance: Importance.high,
    sound: const RawResourceAndroidNotificationSound('notification_sound'),
    enableVibration: true,
    vibrationPattern: Int64List.fromList([0, 200, 100, 200]),
    playSound: true,
    showBadge: true,
  );

  // ─── Initialize ──────────────────────────────────────────────────────────
  static Future<void> initialize() async {
    // 1. Request permissions
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      criticalAlert: true,
      provisional: false,
    );
    debugPrint('Permission: ${settings.authorizationStatus}');

    // 2. iOS foreground presentation
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // 3. Create Android channels
    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(_jobsChannel);
    await androidPlugin?.createNotificationChannel(_emergencyChannel);
    await androidPlugin?.createNotificationChannel(_chatChannel);
    await androidPlugin?.requestExactAlarmsPermission();
    await androidPlugin?.requestNotificationsPermission();

    // 4. Init local notifications
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

    // 5. Handle app opened from terminated state
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      Future.delayed(const Duration(seconds: 1),
          () => _handleTap(initialMessage));
    }

    // 6. Save FCM token
    final token = await _messaging.getToken();
    if (token != null) {
      debugPrint('FCM Token: $token');
      await AuthService.updateFcmToken(token);
    }
    _messaging.onTokenRefresh
        .listen((t) => AuthService.updateFcmToken(t));

    // 7. Foreground messages → show local notification with sound
    FirebaseMessaging.onMessage.listen(_showLocalNotification);

    // 8. Background tap
    FirebaseMessaging.onMessageOpenedApp.listen(_handleTap);
  }

  // ─── Show notification (WhatsApp-style heads-up) ──────────────────────────
  static Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    final type = message.data['type'] ?? 'job';
    final urgency = message.data['urgency'] ?? 'normal';
    final isEmergency = urgency == 'emergency';
    final isChat = type == 'chat';

    // Pick channel
    final channel = isChat
        ? _chatChannel
        : isEmergency
            ? _emergencyChannel
            : _jobsChannel;

    final vibration = isEmergency
        ? Int64List.fromList([0, 500, 200, 500, 200, 500])
        : isChat
            ? Int64List.fromList([0, 200, 100, 200])
            : Int64List.fromList([0, 250, 250, 250]);

    final androidDetails = AndroidNotificationDetails(
      channel.id,
      channel.name,
      channelDescription: channel.description,
      importance: isEmergency ? Importance.max : Importance.high,
      priority: isEmergency ? Priority.max : Priority.high,
      icon: '@mipmap/ic_launcher',
      largeIcon:
          const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
      // ✅ Sound
      sound: const RawResourceAndroidNotificationSound('notification_sound'),
      playSound: true,
      // ✅ Vibration
      enableVibration: true,
      vibrationPattern: vibration,
      // ✅ Heads-up popup (like WhatsApp)
      fullScreenIntent: isEmergency,
      visibility: NotificationVisibility.public,
      category: isChat
          ? AndroidNotificationCategory.message
          : AndroidNotificationCategory.reminder,
      // ✅ Big text style
      styleInformation: BigTextStyleInformation(
        notification.body ?? '',
        contentTitle: notification.title ?? 'MoKa',
        summaryText: isEmergency
            ? '🚨 Emergency'
            : isChat
                ? '💬 Message'
                : '🔔 New Job',
      ),
      // ✅ Color accent
      color: isEmergency
          ? const Color(0xFFF44336)
          : isChat
              ? const Color(0xFF2196F3)
              : const Color(0xFFFF6B00),
      colorized: true,
      showWhen: true,
      when: DateTime.now().millisecondsSinceEpoch,
      ticker: notification.title,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.active,
    );

    await _localNotifications.show(
      id: notification.hashCode,
      title: notification.title ?? 'MoKa',
      body: notification.body ?? '',
      notificationDetails: NotificationDetails(android: androidDetails, iOS: iosDetails),
      payload: message.data['job_id'] ?? message.data['conversation_id'],
    );
  }

  // ─── Send chat notification (called from chat screen) ────────────────────
  static Future<void> sendChatNotification({
    required String fcmToken,
    required String senderName,
    required String message,
    required String conversationId,
  }) async {
    // This is called from NestJS backend in production
    // For local testing, show directly
    await _localNotifications.show(
      id: conversationId.hashCode,
      title: '💬 $senderName',
      body: message,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _chatChannel.id,
          _chatChannel.name,
          importance: Importance.high,
          priority: Priority.high,
          sound: const RawResourceAndroidNotificationSound(
              'notification_sound'),
          playSound: true,
          enableVibration: true,
          vibrationPattern: Int64List.fromList([0, 200, 100, 200]),
          color: const Color(0xFF2196F3),
          colorized: true,
          styleInformation: BigTextStyleInformation(message,
              contentTitle: '💬 $senderName'),
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentSound: true,
          presentBadge: true,
        ),
      ),
      payload: conversationId,
    );
  }

  static void _handleTap(RemoteMessage message) {
    final type = message.data['type'] ?? 'job';
    if (type == 'chat') {
      _navigateFromPayload(message.data['conversation_id'],
          isChat: true);
    } else {
      _navigateFromPayload(message.data['job_id']);
    }
  }

  static void _navigateFromPayload(String? payload,
      {bool isChat = false}) {
    if (payload == null) return;
    if (isChat) {
      navigatorKey.currentState
          ?.pushNamedAndRemoveUntil('/worker-home', (r) => false);
    } else {
      navigatorKey.currentState
          ?.pushNamedAndRemoveUntil('/worker-home', (r) => false);
    }
  }
}
