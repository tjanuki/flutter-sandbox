import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'screens/webview_screen.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize notification service
  await NotificationService.initialize();
  
  // Request notification permissions
  await Permission.notification.request();
  
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