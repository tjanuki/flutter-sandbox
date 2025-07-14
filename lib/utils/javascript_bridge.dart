class JavaScriptBridge {
  static const String bridgeScript = '''
    window.FlutterMessaging = {
      // Send notification from web to Flutter
      sendNotification: function(title, body, data) {
        if (window.FlutterBridge) {
          window.FlutterBridge.postMessage(JSON.stringify({
            type: 'notification',
            title: title,
            body: body,
            data: data || {}
          }));
        }
      },
      
      // Send message data from web to Flutter
      sendMessage: function(messageData) {
        if (window.FlutterBridge) {
          window.FlutterBridge.postMessage(JSON.stringify({
            type: 'message',
            data: messageData
          }));
        }
      },
      
      // Send user status from web to Flutter
      sendUserStatus: function(status) {
        if (window.FlutterBridge) {
          window.FlutterBridge.postMessage(JSON.stringify({
            type: 'user_status',
            status: status
          }));
        }
      },
      
      // Send typing indicator from web to Flutter
      sendTypingIndicator: function(isTyping, userId) {
        if (window.FlutterBridge) {
          window.FlutterBridge.postMessage(JSON.stringify({
            type: 'typing_indicator',
            isTyping: isTyping,
            userId: userId
          }));
        }
      },
      
      // Request device token from Flutter
      requestDeviceToken: function() {
        if (window.FlutterBridge) {
          window.FlutterBridge.postMessage(JSON.stringify({
            type: 'request_device_token'
          }));
        }
      },
      
      // Subscribe to push notification topic
      subscribeToTopic: function(topic) {
        if (window.FlutterBridge) {
          window.FlutterBridge.postMessage(JSON.stringify({
            type: 'subscribe_topic',
            topic: topic
          }));
        }
      },
      
      // Unsubscribe from push notification topic
      unsubscribeFromTopic: function(topic) {
        if (window.FlutterBridge) {
          window.FlutterBridge.postMessage(JSON.stringify({
            type: 'unsubscribe_topic',
            topic: topic
          }));
        }
      }
    };
    
    // Laravel-specific helper functions
    window.LaravelMessaging = {
      // Initialize Laravel integration
      init: function() {
        console.log('Laravel Messaging Bridge initialized');
        
        // Listen for Laravel Echo events if available
        if (window.Echo) {
          this.setupEchoListeners();
        }
        
        // Setup CSRF token for Laravel requests
        this.setupCSRFToken();
      },
      
      // Setup Laravel Echo listeners for real-time events
      setupEchoListeners: function() {
        if (window.Echo && window.Laravel && window.Laravel.user) {
          const userId = window.Laravel.user.id;
          
          // Listen for new messages
          window.Echo.private('messages.' + userId)
            .listen('NewMessage', (e) => {
              window.FlutterMessaging.sendNotification(
                'New Message from ' + e.message.sender.name,
                e.message.content,
                {
                  messageId: e.message.id,
                  senderId: e.message.sender.id,
                  conversationId: e.message.conversation_id
                }
              );
            });
          
          // Listen for typing indicators
          window.Echo.private('typing.' + userId)
            .listen('UserTyping', (e) => {
              window.FlutterMessaging.sendTypingIndicator(
                e.isTyping,
                e.userId
              );
            });
        }
      },
      
      // Setup CSRF token for Laravel requests
      setupCSRFToken: function() {
        const token = document.querySelector('meta[name="csrf-token"]');
        if (token) {
          window.Laravel = window.Laravel || {};
          window.Laravel.csrfToken = token.getAttribute('content');
        }
      },
      
      // Send message through Laravel API
      sendMessage: function(conversationId, content) {
        fetch('/api/messages', {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'X-CSRF-TOKEN': window.Laravel.csrfToken,
            'Authorization': 'Bearer ' + this.getAuthToken()
          },
          body: JSON.stringify({
            conversation_id: conversationId,
            content: content
          })
        })
        .then(response => response.json())
        .then(data => {
          window.FlutterMessaging.sendMessage({
            type: 'message_sent',
            message: data
          });
        })
        .catch(error => {
          console.error('Error sending message:', error);
          window.FlutterMessaging.sendMessage({
            type: 'message_error',
            error: error.message
          });
        });
      },
      
      // Get authentication token
      getAuthToken: function() {
        return localStorage.getItem('auth_token') || 
               sessionStorage.getItem('auth_token') ||
               (window.Laravel && window.Laravel.authToken);
      }
    };
    
    // Auto-initialize when DOM is ready
    if (document.readyState === 'loading') {
      document.addEventListener('DOMContentLoaded', function() {
        window.LaravelMessaging.init();
      });
    } else {
      window.LaravelMessaging.init();
    }
    
    // Notify Flutter that bridge is ready
    if (window.onFlutterBridgeReady) {
      window.onFlutterBridgeReady();
    }
  ''';

  static const String notificationPermissionScript = '''
    // Request notification permission for web
    if ('Notification' in window && Notification.permission === 'default') {
      Notification.requestPermission().then(function(permission) {
        window.FlutterMessaging.sendMessage({
          type: 'notification_permission',
          permission: permission
        });
      });
    }
  ''';

  static const String serviceWorkerScript = '''
    // Register service worker for push notifications
    if ('serviceWorker' in navigator) {
      navigator.serviceWorker.register('/sw.js')
        .then(function(registration) {
          console.log('Service Worker registered with scope:', registration.scope);
        })
        .catch(function(error) {
          console.log('Service Worker registration failed:', error);
        });
    }
  ''';
}