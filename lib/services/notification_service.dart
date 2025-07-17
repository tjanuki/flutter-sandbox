import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  static final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;

  static Future<void> initialize() async {
    // Initialize local notifications
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    
    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _localNotifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Initialize Firebase Messaging
    await _initializeFirebaseMessaging();
  }

  static Future<void> _initializeFirebaseMessaging() async {
    // Request permission for notifications using both Firebase and permission_handler
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
      await showNotification(
        title: notification.title ?? 'New Message',
        body: notification.body ?? '',
        payload: message.data.toString(),
      );
    }
  }

  static void _handleNotificationOpenedApp(RemoteMessage message) {
    print('Notification opened app: ${message.data}');
    // Handle navigation based on notification data
  }

  static Future<void> showNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'messaging_channel',
      'Messaging Notifications',
      channelDescription: 'Notifications for messaging app',
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'ticker',
      icon: '@mipmap/ic_launcher',
    );

    const DarwinNotificationDetails iOSPlatformChannelSpecifics =
        DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title,
      body,
      platformChannelSpecifics,
      payload: payload,
    );
  }

  static void _onNotificationTapped(NotificationResponse response) {
    print('Notification tapped: ${response.payload}');
    // Handle notification tap
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

  static Future<void> sendLocalNotification({
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    await showNotification(
      title: title,
      body: body,
      payload: data?.toString(),
    );
  }

  static Future<void> cancelAllNotifications() async {
    await _localNotifications.cancelAll();
  }

  static Future<void> cancelNotification(int id) async {
    await _localNotifications.cancel(id);
  }

  static Future<void> createNotificationChannel({
    required String channelId,
    required String channelName,
    required String channelDescription,
    Importance importance = Importance.high,
  }) async {
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'messaging_channel',
      'Messaging Notifications',
      description: 'Notifications for messaging app',
      importance: Importance.high,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }
}

// Top-level function for handling background messages
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (kDebugMode) {
    print('Handling a background message: ${message.messageId}');
    print('Message data: ${message.data}');
  }
  
  // Initialize local notifications for background processing
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  
  const DarwinInitializationSettings initializationSettingsIOS =
      DarwinInitializationSettings();

  const InitializationSettings initializationSettings =
      InitializationSettings(
    android: initializationSettingsAndroid,
    iOS: initializationSettingsIOS,
  );

  await FlutterLocalNotificationsPlugin().initialize(initializationSettings);
  
  // Show notification for background messages
  RemoteNotification? notification = message.notification;
  if (notification != null) {
    await _showBackgroundNotification(
      title: notification.title ?? 'New Message',
      body: notification.body ?? '',
      data: message.data,
    );
  }
}

// Helper method for showing background notifications
Future<void> _showBackgroundNotification({
  required String title,
  required String body,
  Map<String, dynamic>? data,
}) async {
  const AndroidNotificationDetails androidPlatformChannelSpecifics =
      AndroidNotificationDetails(
    'messaging_channel',
    'Messaging Notifications',
    channelDescription: 'Notifications for messaging app',
    importance: Importance.max,
    priority: Priority.high,
    ticker: 'ticker',
    icon: '@mipmap/ic_launcher',
  );

  const DarwinNotificationDetails iOSPlatformChannelSpecifics =
      DarwinNotificationDetails(
    presentAlert: true,
    presentBadge: true,
    presentSound: true,
  );

  const NotificationDetails platformChannelSpecifics = NotificationDetails(
    android: androidPlatformChannelSpecifics,
    iOS: iOSPlatformChannelSpecifics,
  );

  await FlutterLocalNotificationsPlugin().show(
    DateTime.now().millisecondsSinceEpoch.remainder(100000),
    title,
    body,
    platformChannelSpecifics,
    payload: data?.toString(),
  );
}