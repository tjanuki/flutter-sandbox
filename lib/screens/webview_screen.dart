import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../services/webview_service.dart';
import '../services/notification_service.dart';
import '../utils/javascript_bridge.dart';
import 'notification_test_screen.dart';
import 'dart:async';

class WebViewScreen extends StatefulWidget {
  const WebViewScreen({Key? key}) : super(key: key);

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> with WidgetsBindingObserver {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  Timer? _retryTimer;
  int _retryCount = 0;
  static const int _maxRetries = 3;
  
  // Laravel app served by Herd
  final String _laravelUrl = 'https://messaging-backend-sandbox.test/messaging';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeWebView();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _retryTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _controller.reload();
    }
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
              _hasError = false;
              _retryCount = 0;
            });
            _injectJavaScript();
          },
          onWebResourceError: (WebResourceError error) {
            setState(() {
              _hasError = true;
              _errorMessage = error.description;
              _isLoading = false;
            });
            _handleWebViewError(error);
          },
          onHttpError: (HttpResponseError error) {
            setState(() {
              _hasError = true;
              _errorMessage = 'HTTP Error: ${error.response?.statusCode}';
              _isLoading = false;
            });
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
    _controller.runJavaScript(JavaScriptBridge.bridgeScript);
    _controller.runJavaScript(JavaScriptBridge.notificationPermissionScript);
    _controller.runJavaScript(JavaScriptBridge.serviceWorkerScript);
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
          _handleRegularMessage(data);
          break;
          
        case 'user_status':
          _handleUserStatus(data['status']);
          break;
          
        case 'typing_indicator':
          _handleTypingIndicator(data['isTyping'], data['userId']);
          break;
          
        case 'request_device_token':
          _handleDeviceTokenRequest();
          break;
          
        case 'subscribe_topic':
          _handleTopicSubscription(data['topic'], true);
          break;
          
        case 'unsubscribe_topic':
          _handleTopicSubscription(data['topic'], false);
          break;
          
        case 'notification_permission':
          _handleNotificationPermission(data['permission']);
          break;
          
        default:
          print('Unknown message type: ${data['type']}');
      }
    } catch (e) {
      print('Error handling message from WebView: $e');
      _sendErrorToWebView('Failed to parse message: $e');
    }
  }

  void _handleRegularMessage(Map<String, dynamic> data) {
    // Handle regular message data
    print('Received message: $data');
  }

  void _handleUserStatus(String status) {
    // Handle user status updates
    print('User status changed: $status');
  }

  void _handleTypingIndicator(bool isTyping, String userId) {
    // Handle typing indicator updates
    print('User $userId is typing: $isTyping');
  }

  void _handleDeviceTokenRequest() async {
    try {
      final token = await NotificationService.getDeviceToken();
      _sendDeviceTokenToWebView(token);
    } catch (e) {
      print('Error getting device token: $e');
      _sendErrorToWebView('Failed to get device token');
    }
  }

  void _handleTopicSubscription(String topic, bool subscribe) async {
    try {
      if (subscribe) {
        await NotificationService.subscribeToTopic(topic);
      } else {
        await NotificationService.unsubscribeFromTopic(topic);
      }
      _sendTopicSubscriptionResult(topic, subscribe, true);
    } catch (e) {
      print('Error with topic subscription: $e');
      _sendTopicSubscriptionResult(topic, subscribe, false);
    }
  }

  void _handleNotificationPermission(String permission) {
    print('Web notification permission: $permission');
  }

  void _sendDeviceTokenToWebView(String? token) {
    _controller.runJavaScript('''
      if (window.onDeviceTokenReceived) {
        window.onDeviceTokenReceived('$token');
      }
    ''');
  }

  void _sendTopicSubscriptionResult(String topic, bool subscribe, bool success) {
    final action = subscribe ? 'subscribed' : 'unsubscribed';
    _controller.runJavaScript('''
      if (window.onTopicSubscriptionResult) {
        window.onTopicSubscriptionResult('$topic', '$action', $success);
      }
    ''');
  }

  void _sendErrorToWebView(String error) {
    _controller.runJavaScript('''
      if (window.onFlutterError) {
        window.onFlutterError('$error');
      }
    ''');
  }

  void _handleWebViewError(WebResourceError error) {
    if (_retryCount < _maxRetries) {
      _retryTimer = Timer(Duration(seconds: 2 * (_retryCount + 1)), () {
        _retryCount++;
        _reloadWebView();
      });
    } else {
      _showErrorSnackBar('Failed to load after $_maxRetries attempts');
    }
  }

  void _reloadWebView() {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    _controller.reload();
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          action: SnackBarAction(
            label: 'Retry',
            textColor: Colors.white,
            onPressed: () {
              _retryCount = 0;
              _reloadWebView();
            },
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Messaging App'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const NotificationTestScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _controller.reload(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          _reloadWebView();
        },
        child: Stack(
          children: [
            if (!_hasError) WebViewWidget(controller: _controller),
            if (_hasError) _buildErrorView(),
            if (_isLoading)
              const Center(
                child: CircularProgressIndicator(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              'Failed to load messaging app',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                _retryCount = 0;
                _reloadWebView();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}