import 'dart:convert';

class WebViewService {
  static Map<String, dynamic> parseMessage(String message) {
    try {
      return json.decode(message);
    } catch (e) {
      print('Error parsing message: $e');
      return {};
    }
  }

  static String createMessage(String type, Map<String, dynamic> data) {
    return json.encode({
      'type': type,
      'data': data,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  static String createNotificationMessage({
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) {
    return createMessage('notification', {
      'title': title,
      'body': body,
      'data': data ?? {},
    });
  }

  static String createStatusMessage(String status) {
    return createMessage('status', {
      'status': status,
    });
  }

  static String createErrorMessage(String error) {
    return createMessage('error', {
      'error': error,
    });
  }
  
  static String createDeviceTokenMessage(String token) {
    return createMessage('device_token', {
      'token': token,
    });
  }
  
  static String createTopicSubscriptionMessage(String topic, bool subscribe, bool success) {
    return createMessage('topic_subscription_result', {
      'topic': topic,
      'action': subscribe ? 'subscribe' : 'unsubscribe',
      'success': success,
    });
  }
  
  static String createUserStatusMessage(String status) {
    return createMessage('user_status', {
      'status': status,
    });
  }
  
  static String createTypingIndicatorMessage(bool isTyping, String userId) {
    return createMessage('typing_indicator', {
      'isTyping': isTyping,
      'userId': userId,
    });
  }
  
  static String createConnectivityMessage(bool isOnline) {
    return createMessage('connectivity', {
      'isOnline': isOnline,
    });
  }
  
  static bool isValidMessageType(String type) {
    const validTypes = {
      'notification',
      'message',
      'user_status',
      'typing_indicator',
      'request_device_token',
      'subscribe_topic',
      'unsubscribe_topic',
      'device_token',
      'topic_subscription_result',
      'connectivity',
      'error',
      'status',
    };
    return validTypes.contains(type);
  }
  
  static void clearMessageQueue() {
    _messageQueue.clear();
  }
  
  static int get queuedMessageCount => _messageQueue.length;
  
  static Map<String, dynamic> sanitizeMessage(Map<String, dynamic> message) {
    final sanitized = <String, dynamic>{};
    
    // Only allow safe fields
    const allowedFields = {
      'type', 'data', 'timestamp', 'id', 'title', 'body', 'status',
      'isTyping', 'userId', 'topic', 'token', 'action', 'success',
      'error', 'isOnline'
    };
    
    message.forEach((key, value) {
      if (allowedFields.contains(key)) {
        sanitized[key] = value;
      }
    });
    
    return sanitized;
  }
}