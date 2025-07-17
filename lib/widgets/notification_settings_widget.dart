import 'package:flutter/material.dart';
import '../services/notification_service.dart';

class NotificationSettingsWidget extends StatefulWidget {
  const NotificationSettingsWidget({Key? key}) : super(key: key);

  @override
  State<NotificationSettingsWidget> createState() => _NotificationSettingsWidgetState();
}

class _NotificationSettingsWidgetState extends State<NotificationSettingsWidget> {
  bool _notificationsEnabled = false;
  bool _isLoading = true;
  String? _deviceToken;

  @override
  void initState() {
    super.initState();
    _checkNotificationStatus();
  }

  Future<void> _checkNotificationStatus() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final enabled = await NotificationService.areNotificationsEnabled();
      final token = await NotificationService.getDeviceToken();

      setState(() {
        _notificationsEnabled = enabled;
        _deviceToken = token;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      print('Error checking notification status: $e');
    }
  }

  Future<void> _toggleNotifications() async {
    if (_notificationsEnabled) {
      // If notifications are enabled, open settings to disable them
      await NotificationService.openNotificationSettings();
    } else {
      // If notifications are disabled, request permissions
      await NotificationService.initialize();
    }
    
    // Refresh status after potential changes
    await _checkNotificationStatus();
  }

  Future<void> _sendTestNotification() async {
    await NotificationService.sendLocalNotification(
      title: 'Test Notification',
      body: 'This is a test notification from your messaging app!',
      data: {'test': 'true'},
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    return Card(
      margin: const EdgeInsets.all(16.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Notification Settings',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            
            // Notification status
            ListTile(
              leading: Icon(
                _notificationsEnabled ? Icons.notifications_active : Icons.notifications_off,
                color: _notificationsEnabled ? Colors.green : Colors.red,
              ),
              title: Text(
                _notificationsEnabled ? 'Notifications Enabled' : 'Notifications Disabled',
              ),
              subtitle: Text(
                _notificationsEnabled 
                    ? 'You will receive push notifications for new messages'
                    : 'Enable notifications to receive message alerts',
              ),
              trailing: Switch(
                value: _notificationsEnabled,
                onChanged: (value) => _toggleNotifications(),
              ),
            ),
            
            const Divider(),
            
            // Device token info (for debugging)
            if (_deviceToken != null) ...[
              ListTile(
                leading: const Icon(Icons.token),
                title: const Text('Device Token'),
                subtitle: Text(
                  _deviceToken!.substring(0, 20) + '...',
                  style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.copy),
                  onPressed: () {
                    // Copy token to clipboard (would need clipboard package)
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Token copied to clipboard')),
                    );
                  },
                ),
              ),
              const Divider(),
            ],
            
            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: _notificationsEnabled ? _sendTestNotification : null,
                  icon: const Icon(Icons.notification_add),
                  label: const Text('Test Notification'),
                ),
                ElevatedButton.icon(
                  onPressed: _checkNotificationStatus,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh Status'),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Additional settings
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Open System Settings'),
              subtitle: const Text('Configure notification preferences in system settings'),
              onTap: () => NotificationService.openNotificationSettings(),
            ),
          ],
        ),
      ),
    );
  }
}