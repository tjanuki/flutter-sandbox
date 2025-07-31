import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

class NotificationService {
  static final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;

  static Future<void> initialize() async {
    // Initialize Firebase Messaging
    await _initializeFirebaseMessaging();
  }

  static Future<void> _initializeFirebaseMessaging() async {
    // Request permission for notifications
    await _requestNotificationPermissions();

    // Get the token only if permissions are granted
    NotificationSettings settings = await _firebaseMessaging.getNotificationSettings();
    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('User granted permission');
    } else {
      print('User declined or has not accepted permission');
      return; // Exit early if no permission
    }

    // Get the token
    String? token = await _firebaseMessaging.getToken();
    print('FCM Token: $token');
    
    // Handle background messages
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    
    // Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _handleForegroundMessage(message);
    });

    // Handle notification opened app
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _handleNotificationOpenedApp(message);
    });
  }

  static Future<void> _handleForegroundMessage(RemoteMessage message) async {
    RemoteNotification? notification = message.notification;
    AndroidNotification? android = message.notification?.android;

    if (notification != null && android != null && !kIsWeb) {
      print('Foreground message received: ${notification.title} - ${notification.body}');
      // Note: Without flutter_local_notifications, we can only log or handle via system notifications
    }
  }

  static void _handleNotificationOpenedApp(RemoteMessage message) {
    print('Notification opened app: ${message.data}');
    // Handle navigation based on notification data
  }

  static Future<String?> getDeviceToken() async {
    return await _firebaseMessaging.getToken();
  }

  static Future<void> subscribeToTopic(String topic) async {
    await _firebaseMessaging.subscribeToTopic(topic);
  }

  static Future<void> unsubscribeFromTopic(String topic) async {
    await _firebaseMessaging.unsubscribeFromTopic(topic);
  }

  static Future<bool> _requestNotificationPermissions() async {
    // Request Firebase Messaging permissions
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    // Request system-level notification permissions
    PermissionStatus permissionStatus = await Permission.notification.request();
    
    bool firebaseGranted = settings.authorizationStatus == AuthorizationStatus.authorized;
    bool systemGranted = permissionStatus == PermissionStatus.granted;
    
    if (kDebugMode) {
      print('Firebase permission: $firebaseGranted');
      print('System permission: $systemGranted');
    }
    
    return firebaseGranted && systemGranted;
  }

  static Future<bool> areNotificationsEnabled() async {
    NotificationSettings settings = await _firebaseMessaging.getNotificationSettings();
    PermissionStatus permissionStatus = await Permission.notification.status;
    
    return settings.authorizationStatus == AuthorizationStatus.authorized &&
           permissionStatus == PermissionStatus.granted;
  }

  static Future<void> openNotificationSettings() async {
    await openAppSettings();
  }

  // Simplified methods without local notifications
  static Future<void> sendLocalNotification({
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    print('Local notification (Firebase only): $title - $body');
    // Note: This would require server-side FCM call to actually show notification
  }

  static Future<void> cancelAllNotifications() async {
    print('Cancel all notifications (Firebase only)');
    // Note: Firebase doesn't provide direct API to cancel notifications
  }

  static Future<void> cancelNotification(int id) async {
    print('Cancel notification $id (Firebase only)');
    // Note: Firebase doesn't provide direct API to cancel specific notifications
  }
}

// Top-level function for handling background messages
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (kDebugMode) {
    print('Handling a background message: ${message.messageId}');
    print('Message data: ${message.data}');
  }
  
  // Note: Without flutter_local_notifications, we can only log background messages
  RemoteNotification? notification = message.notification;
  if (notification != null) {
    print('Background notification: ${notification.title} - ${notification.body}');
  }
}