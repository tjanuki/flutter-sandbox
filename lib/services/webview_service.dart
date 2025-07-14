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
}