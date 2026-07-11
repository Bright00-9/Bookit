import 'dart:typed_data';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'auth_service.dart';

// Global navigator key — used to navigate on notification tap
final GlobalKey<NavigatorState> navigatorKey =
    GlobalKey<NavigatorState>();

// ─── Background handler ───────────────────────────────────────
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(
    RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('BG message: ${message.messageId}');
}

// ─── Background tap handler ───────────────────────────────────
@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse response) {
  debugPrint('BG tap: ${response.payload}');
}

class NotificationService {
  static final _messaging = FirebaseMessaging.instance;
  static final _localNotifications =
      FlutterLocalNotificationsPlugin();

  // ─── Channels ─────────────────────────────────────────────
  static final _jobsChannel = AndroidNotificationChannel(
    'moka_jobs',
    'Job Alerts',
    description: 'Notifications for nearby job postings',
    importance: Importance.high,
    sound: const RawResourceAndroidNotificationSound(
        'notification_sound'),
    enableVibration: true,
    vibrationPattern:
        Int64List.fromList([0, 250, 250, 250]),
    playSound: true,
    showBadge: true,
  );

  static final _emergencyChannel = AndroidNotificationChannel(
    'moka_emergency',
    'Emergency Job Alerts',
    description: 'High priority emergency job notifications',
    importance: Importance.max,
    sound: const RawResourceAndroidNotificationSound(
        'notification_sound'),
    enableVibration: true,
    vibrationPattern:
        Int64List.fromList([0, 500, 200, 500, 200, 500]),
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
    sound: const RawResourceAndroidNotificationSound(
        'notification_sound'),
    enableVibration: true,
    vibrationPattern:
        Int64List.fromList([0, 200, 100, 200]),
    playSound: true,
    showBadge: true,
  );

  // ── New: acceptance fee paid notification channel ──────────
  static final _acceptanceChannel = AndroidNotificationChannel(
    'moka_acceptance',
    'Job Acceptance',
    description:
        'Notifications when a customer accepts your application',
    importance: Importance.high,
    sound: const RawResourceAndroidNotificationSound(
        'notification_sound'),
    enableVibration: true,
    vibrationPattern:
        Int64List.fromList([0, 300, 150, 300]),
    playSound: true,
    showBadge: true,
    enableLights: true,
    ledColor: const Color(0xFF4CAF50),
  );

  // ─── Initialize ───────────────────────────────────────────
  static Future<void> initialize() async {
    // 1. Request permissions
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      criticalAlert: true,
      provisional: false,
    );
    debugPrint(
        'Permission: ${settings.authorizationStatus}');

    // 2. iOS foreground presentation
    await _messaging
        .setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // 3. Create Android channels
    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin
        ?.createNotificationChannel(_jobsChannel);
    await androidPlugin
        ?.createNotificationChannel(_emergencyChannel);
    await androidPlugin
        ?.createNotificationChannel(_chatChannel);
    await androidPlugin
        ?.createNotificationChannel(_acceptanceChannel);
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
      onDidReceiveNotificationResponse:
          (NotificationResponse response) {
        _navigateFromPayload(
          response.payload,
          type: response.notificationResponseType.name,
        );
      },
      onDidReceiveBackgroundNotificationResponse:
          notificationTapBackground,
    );

    // 5. Handle app opened from terminated state
    final initialMessage =
        await _messaging.getInitialMessage();
    if (initialMessage != null) {
      Future.delayed(const Duration(seconds: 1),
          () => _handleTap(initialMessage));
    }

    // 6. Save FCM token
    await _saveToken();
    _messaging.onTokenRefresh
        .listen((t) => AuthService.updateFcmToken(t));

    // 7. Foreground messages
    FirebaseMessaging.onMessage
        .listen(_showLocalNotification);

    // 8. Background tap
    FirebaseMessaging.onMessageOpenedApp
        .listen(_handleTap);
  }

  // ─── Save FCM token ───────────────────────────────────────
  static Future<void> _saveToken() async {
    try {
      final token = await _messaging.getToken();
      if (token != null) {
        debugPrint('FCM Token: $token');
        await AuthService.updateFcmToken(token);
      }
    } catch (e) {
      debugPrint('FCM token error: $e');
    }
  }

  // ── Clear FCM token on logout ─────────────────────────────
  // Call this before AuthService.logout()
  static Future<void> clearTokenOnLogout() async {
    try {
      await AuthService.updateFcmToken(null);
      await _messaging.deleteToken();
    } catch (e) {
      debugPrint('FCM clear token error: $e');
    }
  }

  // ─── Show local notification ──────────────────────────────
  static Future<void> _showLocalNotification(
      RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    final type = message.data['type'] ?? 'job';
    final urgency = message.data['urgency'] ?? 'normal';
    final isEmergency = urgency == 'emergency';
    final isChat = type == 'chat';
    final isAcceptance = type == 'acceptance';

    // Pick channel
    final channel = isChat
        ? _chatChannel
        : isAcceptance
            ? _acceptanceChannel
            : isEmergency
                ? _emergencyChannel
                : _jobsChannel;

    final vibration = isEmergency
        ? Int64List.fromList([0, 500, 200, 500, 200, 500])
        : isChat
            ? Int64List.fromList([0, 200, 100, 200])
            : isAcceptance
                ? Int64List.fromList([0, 300, 150, 300])
                : Int64List.fromList([0, 250, 250, 250]);

    // Payload — what to navigate to on tap
    final payload = isChat
        ? '${type}:${message.data['conversation_id']}'
        : isAcceptance
            ? '${type}:${message.data['job_id']}'
            : 'job:${message.data['job_id']}';

    final androidDetails = AndroidNotificationDetails(
      channel.id,
      channel.name,
      channelDescription: channel.description,
      importance:
          isEmergency ? Importance.max : Importance.high,
      priority:
          isEmergency ? Priority.max : Priority.high,
      icon: '@mipmap/ic_launcher',
      largeIcon: const DrawableResourceAndroidBitmap(
          '@mipmap/ic_launcher'),
      sound: const RawResourceAndroidNotificationSound(
          'notification_sound'),
      playSound: true,
      enableVibration: true,
      vibrationPattern: vibration,
      fullScreenIntent: isEmergency,
      visibility: NotificationVisibility.public,
      category: isChat
          ? AndroidNotificationCategory.message
          : AndroidNotificationCategory.reminder,
      styleInformation: BigTextStyleInformation(
        notification.body ?? '',
        contentTitle:
            notification.title ?? 'MoKa',
        summaryText: isEmergency
            ? '🚨 Emergency'
            : isChat
                ? '💬 Message'
                : isAcceptance
                    ? '✅ Job Accepted'
                    : '🔔 New Job',
      ),
      color: isEmergency
          ? const Color(0xFFF44336)
          : isChat
              ? const Color(0xFF2196F3)
              : isAcceptance
                  ? const Color(0xFF4CAF50)
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
      notificationDetails: NotificationDetails(
          android: androidDetails, iOS: iosDetails),
      payload: payload,
    );
  }

  // ─── Send chat notification ───────────────────────────────
  static Future<void> sendChatNotification({
    required String fcmToken,
    required String senderName,
    required String message,
    required String conversationId,
  }) async {
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
          vibrationPattern:
              Int64List.fromList([0, 200, 100, 200]),
          color: const Color(0xFF2196F3),
          colorized: true,
          styleInformation: BigTextStyleInformation(
              message,
              contentTitle: '💬 $senderName'),
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentSound: true,
          presentBadge: true,
        ),
      ),
      payload: 'chat:$conversationId',
    );
  }

  // ── Send acceptance notification (called after fee paid) ──
  // Call this from AcceptanceFeeService.confirmPaymentAndAccept()
  static Future<void> showAcceptanceNotification({
    required String jobTitle,
    required String jobId,
  }) async {
    await _localNotifications.show(
      id: jobId.hashCode,
      title: '✅ You got the job!',
      body:
          'A customer accepted you for "$jobTitle". Open the app to get started.',
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _acceptanceChannel.id,
          _acceptanceChannel.name,
          importance: Importance.high,
          priority: Priority.high,
          sound: const RawResourceAndroidNotificationSound(
              'notification_sound'),
          playSound: true,
          enableVibration: true,
          vibrationPattern:
              Int64List.fromList([0, 300, 150, 300]),
          color: const Color(0xFF4CAF50),
          colorized: true,
          styleInformation: BigTextStyleInformation(
            'A customer accepted you for "$jobTitle". Open the app to get started.',
            contentTitle: '✅ You got the job!',
            summaryText: 'Job Accepted',
          ),
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentSound: true,
          presentBadge: true,
        ),
      ),
      payload: 'acceptance:$jobId',
    );
  }

  // ─── Handle FCM tap ───────────────────────────────────────
  static void _handleTap(RemoteMessage message) {
    final type = message.data['type'] ?? 'job';
    final jobId = message.data['job_id'];
    final conversationId = message.data['conversation_id'];

    if (type == 'chat') {
      _navigateFromPayload('chat:$conversationId');
    } else if (type == 'acceptance') {
      _navigateFromPayload('acceptance:$jobId');
    } else {
      _navigateFromPayload('job:$jobId');
    }
  }

  // ─── Navigate based on payload ────────────────────────────
  // Payload format: "type:id"
  // e.g. "job:abc123", "chat:xyz789", "acceptance:def456"
  static void _navigateFromPayload(
    String? payload, {
    String? type,
  }) {
    if (payload == null) return;

    final parts = payload.split(':');
    if (parts.length < 2) return;

    final notifType = parts[0];
    final id = parts.sublist(1).join(':'); // handle UUIDs with colons

    switch (notifType) {
      case 'job':
        // Navigate to worker home → jobs tab
        // The worker can see the job in their nearby jobs list
        navigatorKey.currentState?.pushNamedAndRemoveUntil(
          '/worker-home',
          (r) => false,
          arguments: {'tab': 0, 'job_id': id},
        );
        break;

      case 'chat':
        // Navigate to worker home → messages
        navigatorKey.currentState?.pushNamedAndRemoveUntil(
          '/worker-home',
          (r) => false,
          arguments: {'tab': 2, 'conversation_id': id},
        );
        break;

      case 'acceptance':
        // Navigate to worker my jobs screen
        navigatorKey.currentState?.pushNamedAndRemoveUntil(
          '/worker-home',
          (r) => false,
          arguments: {'tab': 1, 'job_id': id},
        );
        break;

      default:
        navigatorKey.currentState?.pushNamedAndRemoveUntil(
          '/worker-home',
          (r) => false,
        );
    }
  }
}