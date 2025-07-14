# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Flutter messaging app that integrates with a Laravel backend through WebView. The app displays a Laravel web messaging interface within a native Flutter shell, providing native push notifications and bidirectional communication between Flutter and the web content.

## Architecture

### Hybrid App Structure
- **Flutter Shell**: Native mobile app wrapper (`lib/main.dart`)
- **WebView Container**: Displays Laravel messaging interface (`lib/screens/webview_screen.dart`)
- **JavaScript Bridge**: Enables communication between Flutter and web content (`lib/utils/javascript_bridge.dart`)
- **Notification System**: Firebase Cloud Messaging + local notifications (`lib/services/notification_service.dart`)

### Key Integration Pattern
The app uses a JavaScript bridge to enable bidirectional communication:
- **Flutter → Web**: Inject JavaScript functions into WebView
- **Web → Flutter**: JavaScript `postMessage` API with JSON message parsing
- **Laravel Integration**: Specialized handlers for Laravel Echo, CSRF tokens, and API calls

## Development Commands

### Flutter Commands
```bash
# Install dependencies
flutter pub get

# Run app (requires Flutter SDK)
flutter run

# Build for Android
flutter build apk

# Build for iOS
flutter build ios
```

### Prerequisites
- Flutter SDK installed
- Dart SDK (currently at `/opt/homebrew/opt/dart/libexec`)
- Firebase project configured with FCM
- Laravel backend with messaging API endpoints

## Configuration Requirements

### Firebase Setup
- Add `google-services.json` to `android/app/`
- Add `GoogleService-Info.plist` to `ios/Runner/`
- Configure Firebase Cloud Messaging in Firebase Console

### Laravel Backend URL
- Update `_laravelUrl` in `lib/screens/webview_screen.dart` (currently placeholder)
- Ensure Laravel app has responsive messaging interface
- Configure CORS for Flutter WebView requests

### Platform-Specific Configuration
- **Android**: FCM permissions and services configured in `android/app/src/main/AndroidManifest.xml`
- **iOS**: Background modes and permissions in `ios/Runner/Info.plist`

## JavaScript Bridge API

The bridge provides these methods to the Laravel web app:

### Flutter → Web Communication
```javascript
// Available in Laravel web app
window.FlutterMessaging.sendNotification(title, body, data)
window.FlutterMessaging.sendMessage(messageData)
window.LaravelMessaging.sendMessage(conversationId, content)
```

### Web → Flutter Communication
- Messages sent via `FlutterBridge.postMessage()` 
- Parsed as JSON in `_handleMessageFromWebView()`
- Supports types: `notification`, `message`, `user_status`, `typing_indicator`

## Services Architecture

### NotificationService
- Handles FCM initialization and token management
- Manages local and push notification display
- Supports topic subscription/unsubscription
- Background message handling

### WebViewService
- JSON message parsing utilities
- Message creation helpers
- Error handling for bridge communication

## Laravel Integration Expectations

The Laravel backend should provide:
- Responsive messaging interface suitable for mobile WebView
- API endpoints for message sending/receiving
- Laravel Echo integration for real-time updates
- CSRF token handling for secure requests
- Authentication token management

## Known Issues

- Line 42 in `webview_screen.dart` has typo: `ealse` should be `false`
- Firebase configuration files not included (need to be added manually)
- Laravel URL is placeholder and needs to be updated

## Dependencies

Key packages used:
- `webview_flutter`: WebView integration
- `firebase_messaging`: Push notifications
- `flutter_local_notifications`: Local notification display
- `permission_handler`: Runtime permissions
- `http`: HTTP requests