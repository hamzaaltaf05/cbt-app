import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Top-level background message handler for FCM.
/// Must be annotated with `@pragma('vm:entry-point')` so Flutter's isolate
/// can invoke it when the app is in the background or killed.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('FCM: Handling background message ${message.messageId}');
}

/// Central service managing push notifications, device tokens, and foreground alerts.
class FCMService {
  FCMService._();
  static final FCMService instance = FCMService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'high_importance_channel',
    'High Importance Notifications',
    description: 'Used for important notifications like facility issues and shop alerts.',
    importance: Importance.high,
  );

  /// Global callback for navigating when a notification is tapped.
  /// (refType, refId)
  void Function(String refType, String? refId)? onNotificationTap;

  /// Initializes Firebase messaging, notification channels, and auth listeners.
  Future<void> init({void Function(String refType, String? refId)? onNotificationTap}) async {
    this.onNotificationTap = onNotificationTap;

    // 1. Request notification permissions (Android 13+ / iOS)
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    debugPrint('FCM: User permission status: ${settings.authorizationStatus}');

    // 2. Setup Foreground Notification Channel (Android)
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);

    await _localNotifications.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (response) {
        _handlePayload(response.payload);
      },
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);

    // 3. Foreground message presentation options
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // 4. Foreground message listener
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('FCM: Received foreground message: ${message.notification?.title}');
      _showLocalNotification(message);
    });

    // 5. App opened from background via notification tap
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('FCM: App opened from notification: ${message.data}');
      _handleRemoteMessageData(message.data);
    });

    // 6. Check if app was opened from terminated state via notification tap
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      debugPrint('FCM: App cold-started from notification: ${initialMessage.data}');
      _handleRemoteMessageData(initialMessage.data);
    }

    // 7. Token refresh listener
    _messaging.onTokenRefresh.listen((newToken) {
      debugPrint('FCM: Token refreshed: $newToken');
      syncTokenToSupabase(newToken);
    });

    // 8. Auth state listener: sync token on sign in, remove on sign out
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final session = data.session;
      if (session != null) {
        syncTokenToSupabase();
      }
    });

    // Initial sync if user is already logged in
    await syncTokenToSupabase();
  }

  /// Sends the current device's FCM token to the Supabase `fcm_tokens` table.
  Future<void> syncTokenToSupabase([String? explicitToken]) async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      final token = explicitToken ?? await _messaging.getToken();
      if (token == null) return;

      final platformStr = Platform.isAndroid
          ? 'android'
          : (Platform.isIOS ? 'ios' : 'web');

      await Supabase.instance.client.from('fcm_tokens').upsert({
        'user_id': user.id,
        'token': token,
        'platform': platformStr,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'token');

      debugPrint('FCM: Successfully synced token to Supabase for user ${user.id}');
    } catch (e) {
      debugPrint('FCM: Error syncing token to Supabase: $e');
    }
  }

  /// Deletes the device's token from Supabase upon logout.
  Future<void> deleteTokenOnLogout() async {
    try {
      final token = await _messaging.getToken();
      if (token != null) {
        await Supabase.instance.client
            .from('fcm_tokens')
            .delete()
            .eq('token', token);
        debugPrint('FCM: Deleted token from Supabase on logout.');
      }
    } catch (e) {
      debugPrint('FCM: Error removing token on logout: $e');
    }
  }

  /// Shows a heads-up local banner notification when the app is in the foreground.
  void _showLocalNotification(RemoteMessage message) {
    final notification = message.notification;
    final android = message.notification?.android;

    if (notification != null && !kIsWeb) {
      _localNotifications.show(
        id: notification.hashCode,
        title: notification.title,
        body: notification.body,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            _channel.id,
            _channel.name,
            channelDescription: _channel.description,
            icon: android?.smallIcon ?? '@mipmap/ic_launcher',
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
        payload: jsonEncode(message.data),
      );
    }
  }

  void _handlePayload(String? rawPayload) {
    if (rawPayload == null || rawPayload.isEmpty) return;
    try {
      final map = jsonDecode(rawPayload);
      if (map is Map<String, dynamic>) {
        _handleRemoteMessageData(map);
      }
    } catch (e) {
      debugPrint('FCM: Failed to parse payload: $e');
    }
  }

  void _handleRemoteMessageData(Map<String, dynamic> data) {
    final refType = data['ref_type']?.toString();
    final refId = data['ref_id']?.toString();
    if (refType != null && onNotificationTap != null) {
      onNotificationTap!(refType, refId);
    }
  }
}
