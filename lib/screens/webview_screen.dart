import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../services/webview_service.dart';
import '../services/notification_service.dart';

class WebViewScreen extends StatefulWidget {
  const WebViewScreen({Key? key}) : super(key: key);

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  
  // Replace with your Laravel app URL
  final String _laravelUrl = 'https://your-laravel-app.com/messaging';

  @override
  void initState() {
    super.initState();
    _initializeWebView();
  }

  void _initializeWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            // Update loading progress
          },
          onPageStarted: (String url) {
            setState(() {
              _isLoading = true;
            });
          },
          onPageFinished: (String url) {
            setState(() {
              _isLoading = false;
            });
            _injectJavaScript();
          },
          onWebResourceError: (WebResourceError error) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Web resource error: ${error.description}'),
                backgroundColor: Colors.red,
              ),
            );
          },
        ),
      )
      ..addJavaScriptChannel(
        'FlutterBridge',
        onMessageReceived: (JavaScriptMessage message) {
          _handleMessageFromWebView(message.message);
        },
      )
      ..loadRequest(Uri.parse(_laravelUrl));
  }

  void _injectJavaScript() {
    _controller.runJavaScript('''
      window.FlutterBridge = {
        sendNotification: function(title, body, data) {
          FlutterBridge.postMessage(JSON.stringify({
            type: 'notification',
            title: title,
            body: body,
            data: data
          }));
        },
        
        sendMessage: function(message) {
          FlutterBridge.postMessage(JSON.stringify({
            type: 'message',
            data: message
          }));
        }
      };
      
      // Notify web app that Flutter bridge is ready
      if (window.onFlutterBridgeReady) {
        window.onFlutterBridgeReady();
      }
    ''');
  }

  void _handleMessageFromWebView(String message) {
    try {
      final data = WebViewService.parseMessage(message);
      
      switch (data['type']) {
        case 'notification':
          NotificationService.showNotification(
            title: data['title'] ?? 'New Message',
            body: data['body'] ?? '',
            payload: data['data']?.toString(),
          );
          break;
        case 'message':
          // Handle other message types
          break;
      }
    } catch (e) {
      print('Error handling message from WebView: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Messaging App'),
        backgroundColor: Colors.blue,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _controller.reload(),
          ),
        ],
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(),
            ),
        ],
      ),
    );
  }
}