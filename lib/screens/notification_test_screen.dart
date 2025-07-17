import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/notification_service.dart';
import '../widgets/notification_settings_widget.dart';

class NotificationTestScreen extends StatefulWidget {
  const NotificationTestScreen({Key? key}) : super(key: key);

  @override
  State<NotificationTestScreen> createState() => _NotificationTestScreenState();
}

class _NotificationTestScreenState extends State<NotificationTestScreen> {
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  final _topicController = TextEditingController();
  
  bool _isLoading = false;
  String? _deviceToken;
  List<String> _subscribedTopics = [];

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    final token = await NotificationService.getDeviceToken();
    setState(() {
      _deviceToken = token;
    });
  }

  Future<void> _sendTestNotification() async {
    if (_titleController.text.isEmpty || _bodyController.text.isEmpty) {
      _showSnackBar('Please enter both title and body');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await NotificationService.sendLocalNotification(
        title: _titleController.text,
        body: _bodyController.text,
        data: {
          'test': 'true',
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
      _showSnackBar('Test notification sent successfully');
    } catch (e) {
      _showSnackBar('Error sending notification: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _subscribeToTopic() async {
    if (_topicController.text.isEmpty) {
      _showSnackBar('Please enter a topic name');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await NotificationService.subscribeToTopic(_topicController.text);
      setState(() {
        _subscribedTopics.add(_topicController.text);
      });
      _showSnackBar('Subscribed to topic: ${_topicController.text}');
      _topicController.clear();
    } catch (e) {
      _showSnackBar('Error subscribing to topic: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _unsubscribeFromTopic(String topic) async {
    setState(() {
      _isLoading = true;
    });

    try {
      await NotificationService.unsubscribeFromTopic(topic);
      setState(() {
        _subscribedTopics.remove(topic);
      });
      _showSnackBar('Unsubscribed from topic: $topic');
    } catch (e) {
      _showSnackBar('Error unsubscribing from topic: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _copyTokenToClipboard() {
    if (_deviceToken != null) {
      Clipboard.setData(ClipboardData(text: _deviceToken!));
      _showSnackBar('Device token copied to clipboard');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification Test'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Notification Settings Widget
            const NotificationSettingsWidget(),
            
            const SizedBox(height: 24),
            
            // Test Notification Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Send Test Notification',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 16),
                    
                    TextField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: 'Notification Title',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    TextField(
                      controller: _bodyController,
                      decoration: const InputDecoration(
                        labelText: 'Notification Body',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),
                    
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _sendTestNotification,
                        child: _isLoading 
                            ? const CircularProgressIndicator() 
                            : const Text('Send Test Notification'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Topic Subscription Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Topic Subscription',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 16),
                    
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _topicController,
                            decoration: const InputDecoration(
                              labelText: 'Topic Name',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        ElevatedButton(
                          onPressed: _isLoading ? null : _subscribeToTopic,
                          child: const Text('Subscribe'),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 16),
                    
                    if (_subscribedTopics.isNotEmpty) ...[
                      const Text('Subscribed Topics:'),
                      const SizedBox(height: 8),
                      ...(_subscribedTopics.map((topic) => ListTile(
                        leading: const Icon(Icons.topic),
                        title: Text(topic),
                        trailing: IconButton(
                          icon: const Icon(Icons.unsubscribe),
                          onPressed: () => _unsubscribeFromTopic(topic),
                        ),
                      )).toList()),
                    ],
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Device Token Section
            if (_deviceToken != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Device Token',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 16),
                      
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _deviceToken!,
                          style: const TextStyle(
                            fontSize: 12,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _copyTokenToClipboard,
                          icon: const Icon(Icons.copy),
                          label: const Text('Copy Token'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    _topicController.dispose();
    super.dispose();
  }
}