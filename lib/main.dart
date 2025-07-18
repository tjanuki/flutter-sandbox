import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'screens/webview_screen.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase (required for FCM)
  try {
    await Firebase.initializeApp();
  } catch (e) {
    print('Firebase initialization failed: $e');
  }
  
  // Initialize notification service
  await NotificationService.initialize();
  
  runApp(const MessagingApp());
}

class MessagingApp extends StatelessWidget {
  const MessagingApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Messaging App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const WebViewScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}