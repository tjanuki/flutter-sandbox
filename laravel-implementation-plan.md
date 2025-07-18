# Laravel Messaging App Implementation Plan

## Overview
This document outlines the complete implementation plan for the Laravel backend that will serve as the messaging interface for the Flutter WebView application. The Laravel app will provide REST API endpoints, real-time messaging, push notifications, and a responsive web interface.

## Architecture Overview

### Core Components
1. **REST API Layer** - Message CRUD operations, user management, conversations
2. **WebSocket Server** - Real-time messaging using Laravel Echo + Pusher/Redis
3. **Push Notification Service** - FCM integration for mobile notifications
4. **Web Interface** - Responsive UI for WebView integration
5. **Authentication System** - JWT-based API authentication
6. **Database Layer** - MySQL/PostgreSQL with optimized messaging schema

### Technology Stack
- **Framework**: Laravel 10.x
- **Database**: MySQL 8.0+ or PostgreSQL 13+
- **WebSocket**: Laravel Echo + Pusher or Redis
- **Push Notifications**: Firebase Cloud Messaging (FCM)
- **Frontend**: Blade templates + Alpine.js + Tailwind CSS
- **Authentication**: Laravel Sanctum (API tokens)
- **Caching**: Redis
- **Queue System**: Redis + Horizon

## Database Schema

### Users Table
```sql
CREATE TABLE users (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    email_verified_at TIMESTAMP NULL,
    password VARCHAR(255) NOT NULL,
    avatar VARCHAR(255) NULL,
    is_online BOOLEAN DEFAULT FALSE,
    last_seen TIMESTAMP NULL,
    fcm_token VARCHAR(255) NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_users_email (email),
    INDEX idx_users_online (is_online),
    INDEX idx_users_last_seen (last_seen)
);
```

### Conversations Table
```sql
CREATE TABLE conversations (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(255) NULL,
    type ENUM('direct', 'group') DEFAULT 'direct',
    created_by BIGINT UNSIGNED NOT NULL,
    last_message_id BIGINT UNSIGNED NULL,
    last_message_at TIMESTAMP NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE CASCADE,
    INDEX idx_conversations_type (type),
    INDEX idx_conversations_last_message (last_message_at)
);
```

### Conversation Participants Table
```sql
CREATE TABLE conversation_participants (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    conversation_id BIGINT UNSIGNED NOT NULL,
    user_id BIGINT UNSIGNED NOT NULL,
    joined_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_read_at TIMESTAMP NULL,
    is_admin BOOLEAN DEFAULT FALSE,
    FOREIGN KEY (conversation_id) REFERENCES conversations(id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    UNIQUE KEY unique_conversation_user (conversation_id, user_id),
    INDEX idx_participants_conversation (conversation_id),
    INDEX idx_participants_user (user_id)
);
```

### Messages Table
```sql
CREATE TABLE messages (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    conversation_id BIGINT UNSIGNED NOT NULL,
    user_id BIGINT UNSIGNED NOT NULL,
    content TEXT NOT NULL,
    type ENUM('text', 'image', 'file', 'system') DEFAULT 'text',
    metadata JSON NULL,
    edited_at TIMESTAMP NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (conversation_id) REFERENCES conversations(id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    INDEX idx_messages_conversation (conversation_id),
    INDEX idx_messages_user (user_id),
    INDEX idx_messages_created_at (created_at)
);
```

### Message Reactions Table
```sql
CREATE TABLE message_reactions (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    message_id BIGINT UNSIGNED NOT NULL,
    user_id BIGINT UNSIGNED NOT NULL,
    emoji VARCHAR(10) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (message_id) REFERENCES messages(id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    UNIQUE KEY unique_message_user_emoji (message_id, user_id, emoji),
    INDEX idx_reactions_message (message_id)
);
```

### Typing Indicators Table
```sql
CREATE TABLE typing_indicators (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    conversation_id BIGINT UNSIGNED NOT NULL,
    user_id BIGINT UNSIGNED NOT NULL,
    is_typing BOOLEAN DEFAULT TRUE,
    expires_at TIMESTAMP NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (conversation_id) REFERENCES conversations(id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    UNIQUE KEY unique_conversation_user_typing (conversation_id, user_id),
    INDEX idx_typing_conversation (conversation_id),
    INDEX idx_typing_expires (expires_at)
);
```

## API Endpoints

### Authentication Endpoints
```
POST /api/register - User registration
POST /api/login - User login
POST /api/logout - User logout
POST /api/refresh - Refresh token
GET /api/me - Get current user profile
PUT /api/me - Update user profile
POST /api/fcm-token - Update FCM token
```

### Conversation Endpoints
```
GET /api/conversations - List user's conversations
POST /api/conversations - Create new conversation
GET /api/conversations/{id} - Get conversation details
PUT /api/conversations/{id} - Update conversation
DELETE /api/conversations/{id} - Delete conversation
POST /api/conversations/{id}/participants - Add participant
DELETE /api/conversations/{id}/participants/{userId} - Remove participant
```

### Message Endpoints
```
GET /api/conversations/{id}/messages - Get messages (paginated)
POST /api/conversations/{id}/messages - Send message
PUT /api/messages/{id} - Edit message
DELETE /api/messages/{id} - Delete message
POST /api/messages/{id}/reactions - Add reaction
DELETE /api/messages/{id}/reactions - Remove reaction
POST /api/conversations/{id}/read - Mark messages as read
```

### Real-time Endpoints
```
POST /api/conversations/{id}/typing - Start/stop typing
GET /api/conversations/{id}/typing - Get typing users
POST /api/user/status - Update online status
```

### Push Notification Endpoints
```
POST /api/notifications/send - Send push notification
POST /api/notifications/subscribe - Subscribe to topic
POST /api/notifications/unsubscribe - Unsubscribe from topic
```

## Real-time Events (WebSocket)

### Event Types
```javascript
// Message Events
MessageSent - New message in conversation
MessageUpdated - Message edited
MessageDeleted - Message deleted
MessageReactionAdded - Reaction added to message
MessageReactionRemoved - Reaction removed from message

// Conversation Events
ConversationCreated - New conversation created
ConversationUpdated - Conversation details updated
ConversationDeleted - Conversation deleted
ParticipantAdded - User added to conversation
ParticipantRemoved - User removed from conversation

// User Events
UserOnline - User came online
UserOffline - User went offline
UserTyping - User started typing
UserStoppedTyping - User stopped typing

// Notification Events
NotificationReceived - Push notification received
```

### WebSocket Channel Structure
```
// Private channels for users
private-user.{userId}

// Private channels for conversations
private-conversation.{conversationId}

// Presence channels for online users
presence-conversation.{conversationId}
```

## Laravel Implementation Structure

### Models

#### User Model
```php
<?php

namespace App\Models;

use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use Laravel\Sanctum\HasApiTokens;

class User extends Authenticatable
{
    use HasApiTokens, Notifiable;

    protected $fillable = [
        'name', 'email', 'password', 'avatar', 'fcm_token'
    ];

    protected $hidden = [
        'password', 'remember_token', 'fcm_token'
    ];

    protected $casts = [
        'email_verified_at' => 'datetime',
        'last_seen' => 'datetime',
        'is_online' => 'boolean'
    ];

    // Relationships
    public function conversations()
    {
        return $this->belongsToMany(Conversation::class, 'conversation_participants')
                   ->withPivot('joined_at', 'last_read_at', 'is_admin')
                   ->withTimestamps();
    }

    public function messages()
    {
        return $this->hasMany(Message::class);
    }

    public function reactions()
    {
        return $this->hasMany(MessageReaction::class);
    }

    // Scopes
    public function scopeOnline($query)
    {
        return $query->where('is_online', true);
    }

    // Methods
    public function updateOnlineStatus(bool $isOnline)
    {
        $this->update([
            'is_online' => $isOnline,
            'last_seen' => now()
        ]);
    }
}
```

#### Conversation Model
```php
<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Conversation extends Model
{
    protected $fillable = [
        'name', 'type', 'created_by', 'last_message_id', 'last_message_at'
    ];

    protected $casts = [
        'last_message_at' => 'datetime'
    ];

    // Relationships
    public function creator()
    {
        return $this->belongsTo(User::class, 'created_by');
    }

    public function participants()
    {
        return $this->belongsToMany(User::class, 'conversation_participants')
                   ->withPivot('joined_at', 'last_read_at', 'is_admin')
                   ->withTimestamps();
    }

    public function messages()
    {
        return $this->hasMany(Message::class);
    }

    public function lastMessage()
    {
        return $this->belongsTo(Message::class, 'last_message_id');
    }

    // Scopes
    public function scopeForUser($query, $userId)
    {
        return $query->whereHas('participants', function ($q) use ($userId) {
            $q->where('user_id', $userId);
        });
    }

    // Methods
    public function addParticipant(User $user, bool $isAdmin = false)
    {
        return $this->participants()->attach($user->id, [
            'is_admin' => $isAdmin,
            'joined_at' => now()
        ]);
    }

    public function removeParticipant(User $user)
    {
        return $this->participants()->detach($user->id);
    }
}
```

#### Message Model
```php
<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Message extends Model
{
    protected $fillable = [
        'conversation_id', 'user_id', 'content', 'type', 'metadata', 'edited_at'
    ];

    protected $casts = [
        'metadata' => 'array',
        'edited_at' => 'datetime'
    ];

    // Relationships
    public function conversation()
    {
        return $this->belongsTo(Conversation::class);
    }

    public function user()
    {
        return $this->belongsTo(User::class);
    }

    public function reactions()
    {
        return $this->hasMany(MessageReaction::class);
    }

    // Scopes
    public function scopeForConversation($query, $conversationId)
    {
        return $query->where('conversation_id', $conversationId);
    }

    public function scopeRecent($query)
    {
        return $query->orderBy('created_at', 'desc');
    }

    // Methods
    public function addReaction(User $user, string $emoji)
    {
        return $this->reactions()->updateOrCreate(
            ['user_id' => $user->id, 'emoji' => $emoji],
            ['created_at' => now()]
        );
    }

    public function removeReaction(User $user, string $emoji)
    {
        return $this->reactions()
                   ->where('user_id', $user->id)
                   ->where('emoji', $emoji)
                   ->delete();
    }
}
```

### Controllers

#### MessageController
```php
<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\StoreMessageRequest;
use App\Http\Requests\UpdateMessageRequest;
use App\Models\Conversation;
use App\Models\Message;
use App\Services\MessageService;
use App\Services\NotificationService;
use Illuminate\Http\Request;

class MessageController extends Controller
{
    protected MessageService $messageService;
    protected NotificationService $notificationService;

    public function __construct(
        MessageService $messageService,
        NotificationService $notificationService
    ) {
        $this->messageService = $messageService;
        $this->notificationService = $notificationService;
    }

    public function index(Request $request, Conversation $conversation)
    {
        $this->authorize('view', $conversation);

        $messages = $this->messageService->getMessages(
            $conversation->id,
            $request->get('page', 1),
            $request->get('limit', 50)
        );

        return response()->json([
            'messages' => $messages->items(),
            'pagination' => [
                'current_page' => $messages->currentPage(),
                'last_page' => $messages->lastPage(),
                'per_page' => $messages->perPage(),
                'total' => $messages->total()
            ]
        ]);
    }

    public function store(StoreMessageRequest $request, Conversation $conversation)
    {
        $this->authorize('participate', $conversation);

        $message = $this->messageService->createMessage(
            $conversation->id,
            $request->user()->id,
            $request->validated()
        );

        // Send push notifications to other participants
        $this->notificationService->sendMessageNotification($message);

        return response()->json($message->load('user'), 201);
    }

    public function update(UpdateMessageRequest $request, Message $message)
    {
        $this->authorize('update', $message);

        $updatedMessage = $this->messageService->updateMessage(
            $message->id,
            $request->validated()
        );

        return response()->json($updatedMessage);
    }

    public function destroy(Message $message)
    {
        $this->authorize('delete', $message);

        $this->messageService->deleteMessage($message->id);

        return response()->json(null, 204);
    }

    public function addReaction(Request $request, Message $message)
    {
        $this->authorize('react', $message);

        $request->validate([
            'emoji' => 'required|string|max:10'
        ]);

        $reaction = $this->messageService->addReaction(
            $message->id,
            $request->user()->id,
            $request->emoji
        );

        return response()->json($reaction, 201);
    }

    public function removeReaction(Request $request, Message $message)
    {
        $this->authorize('react', $message);

        $request->validate([
            'emoji' => 'required|string|max:10'
        ]);

        $this->messageService->removeReaction(
            $message->id,
            $request->user()->id,
            $request->emoji
        );

        return response()->json(null, 204);
    }

    public function markAsRead(Request $request, Conversation $conversation)
    {
        $this->authorize('participate', $conversation);

        $this->messageService->markAsRead(
            $conversation->id,
            $request->user()->id
        );

        return response()->json(['message' => 'Messages marked as read']);
    }
}
```

### Services

#### MessageService
```php
<?php

namespace App\Services;

use App\Models\Conversation;
use App\Models\Message;
use App\Models\MessageReaction;
use App\Events\MessageSent;
use App\Events\MessageUpdated;
use App\Events\MessageDeleted;
use App\Events\MessageReactionAdded;
use App\Events\MessageReactionRemoved;
use Illuminate\Pagination\LengthAwarePaginator;

class MessageService
{
    public function getMessages(int $conversationId, int $page = 1, int $limit = 50): LengthAwarePaginator
    {
        return Message::forConversation($conversationId)
                     ->with(['user', 'reactions.user'])
                     ->recent()
                     ->paginate($limit, ['*'], 'page', $page);
    }

    public function createMessage(int $conversationId, int $userId, array $data): Message
    {
        $message = Message::create([
            'conversation_id' => $conversationId,
            'user_id' => $userId,
            'content' => $data['content'],
            'type' => $data['type'] ?? 'text',
            'metadata' => $data['metadata'] ?? null
        ]);

        // Update conversation's last message
        $conversation = Conversation::find($conversationId);
        $conversation->update([
            'last_message_id' => $message->id,
            'last_message_at' => $message->created_at
        ]);

        // Broadcast the message
        broadcast(new MessageSent($message->load('user')))->toOthers();

        return $message;
    }

    public function updateMessage(int $messageId, array $data): Message
    {
        $message = Message::findOrFail($messageId);
        
        $message->update([
            'content' => $data['content'],
            'edited_at' => now()
        ]);

        // Broadcast the update
        broadcast(new MessageUpdated($message->load('user')))->toOthers();

        return $message;
    }

    public function deleteMessage(int $messageId): void
    {
        $message = Message::findOrFail($messageId);
        
        // Broadcast the deletion before deleting
        broadcast(new MessageDeleted($message))->toOthers();
        
        $message->delete();
    }

    public function addReaction(int $messageId, int $userId, string $emoji): MessageReaction
    {
        $message = Message::findOrFail($messageId);
        
        $reaction = $message->addReaction(
            auth()->user(),
            $emoji
        );

        // Broadcast the reaction
        broadcast(new MessageReactionAdded($reaction->load('user')))->toOthers();

        return $reaction;
    }

    public function removeReaction(int $messageId, int $userId, string $emoji): void
    {
        $message = Message::findOrFail($messageId);
        
        $reaction = MessageReaction::where([
            'message_id' => $messageId,
            'user_id' => $userId,
            'emoji' => $emoji
        ])->first();

        if ($reaction) {
            broadcast(new MessageReactionRemoved($reaction))->toOthers();
            $reaction->delete();
        }
    }

    public function markAsRead(int $conversationId, int $userId): void
    {
        $conversation = Conversation::findOrFail($conversationId);
        
        $conversation->participants()
                    ->where('user_id', $userId)
                    ->update(['last_read_at' => now()]);
    }
}
```

#### NotificationService
```php
<?php

namespace App\Services;

use App\Models\Message;
use App\Models\User;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

class NotificationService
{
    protected string $fcmServerKey;
    protected string $fcmUrl = 'https://fcm.googleapis.com/fcm/send';

    public function __construct()
    {
        $this->fcmServerKey = config('services.fcm.server_key');
    }

    public function sendMessageNotification(Message $message): void
    {
        $conversation = $message->conversation;
        $sender = $message->user;

        // Get all participants except the sender
        $participants = $conversation->participants()
                                   ->where('user_id', '!=', $sender->id)
                                   ->whereNotNull('fcm_token')
                                   ->get();

        foreach ($participants as $participant) {
            $this->sendToDevice($participant->fcm_token, [
                'title' => $conversation->name ?: $sender->name,
                'body' => $message->content,
                'data' => [
                    'type' => 'message',
                    'conversation_id' => $conversation->id,
                    'message_id' => $message->id,
                    'sender_id' => $sender->id,
                    'sender_name' => $sender->name
                ]
            ]);
        }
    }

    public function sendToDevice(string $token, array $notification): bool
    {
        try {
            $response = Http::withHeaders([
                'Authorization' => 'key=' . $this->fcmServerKey,
                'Content-Type' => 'application/json'
            ])->post($this->fcmUrl, [
                'to' => $token,
                'notification' => [
                    'title' => $notification['title'],
                    'body' => $notification['body'],
                    'click_action' => 'FLUTTER_NOTIFICATION_CLICK'
                ],
                'data' => $notification['data'] ?? []
            ]);

            return $response->successful();
        } catch (\Exception $e) {
            Log::error('FCM notification failed: ' . $e->getMessage());
            return false;
        }
    }

    public function sendToTopic(string $topic, array $notification): bool
    {
        try {
            $response = Http::withHeaders([
                'Authorization' => 'key=' . $this->fcmServerKey,
                'Content-Type' => 'application/json'
            ])->post($this->fcmUrl, [
                'to' => '/topics/' . $topic,
                'notification' => [
                    'title' => $notification['title'],
                    'body' => $notification['body'],
                    'click_action' => 'FLUTTER_NOTIFICATION_CLICK'
                ],
                'data' => $notification['data'] ?? []
            ]);

            return $response->successful();
        } catch (\Exception $e) {
            Log::error('FCM topic notification failed: ' . $e->getMessage());
            return false;
        }
    }

    public function subscribeToTopic(string $token, string $topic): bool
    {
        try {
            $response = Http::withHeaders([
                'Authorization' => 'key=' . $this->fcmServerKey,
                'Content-Type' => 'application/json'
            ])->post('https://iid.googleapis.com/iid/v1/' . $token . '/rel/topics/' . $topic);

            return $response->successful();
        } catch (\Exception $e) {
            Log::error('FCM topic subscription failed: ' . $e->getMessage());
            return false;
        }
    }

    public function unsubscribeFromTopic(string $token, string $topic): bool
    {
        try {
            $response = Http::withHeaders([
                'Authorization' => 'key=' . $this->fcmServerKey,
                'Content-Type' => 'application/json'
            ])->delete('https://iid.googleapis.com/iid/v1/' . $token . '/rel/topics/' . $topic);

            return $response->successful();
        } catch (\Exception $e) {
            Log::error('FCM topic unsubscription failed: ' . $e->getMessage());
            return false;
        }
    }
}
```

## WebSocket Events

### MessageSent Event
```php
<?php

namespace App\Events;

use App\Models\Message;
use Illuminate\Broadcasting\Channel;
use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Broadcasting\PresenceChannel;
use Illuminate\Broadcasting\PrivateChannel;
use Illuminate\Contracts\Broadcasting\ShouldBroadcast;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

class MessageSent implements ShouldBroadcast
{
    use Dispatchable, InteractsWithSockets, SerializesModels;

    public Message $message;

    public function __construct(Message $message)
    {
        $this->message = $message;
    }

    public function broadcastOn(): array
    {
        return [
            new PrivateChannel('conversation.' . $this->message->conversation_id),
        ];
    }

    public function broadcastAs(): string
    {
        return 'message.sent';
    }

    public function broadcastWith(): array
    {
        return [
            'message' => $this->message->toArray(),
            'user' => $this->message->user->toArray(),
            'conversation_id' => $this->message->conversation_id
        ];
    }
}
```

## Web Interface (Blade Templates)

### Main Messaging Interface
```blade
<!-- resources/views/messaging/index.blade.php -->
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <meta name="csrf-token" content="{{ csrf_token() }}">
    <title>Messaging App</title>
    <script src="https://cdn.tailwindcss.com"></script>
    <script src="https://unpkg.com/alpinejs@3.x.x/dist/cdn.min.js" defer></script>
</head>
<body class="bg-gray-100 h-screen flex flex-col">
    <div id="app" class="flex-1 flex flex-col">
        <!-- Header -->
        <header class="bg-blue-600 text-white p-4 shadow">
            <div class="flex justify-between items-center">
                <h1 class="text-xl font-bold">Messages</h1>
                <div class="flex items-center space-x-4">
                    <span class="text-sm">{{ auth()->user()->name }}</span>
                    <button onclick="toggleNotifications()" class="bg-blue-500 hover:bg-blue-400 px-3 py-1 rounded text-sm">
                        Enable Notifications
                    </button>
                </div>
            </div>
        </header>

        <!-- Main Content -->
        <div class="flex-1 flex overflow-hidden">
            <!-- Conversations List -->
            <div class="w-1/3 bg-white border-r border-gray-200 flex flex-col">
                <div class="p-4 border-b border-gray-200">
                    <h2 class="font-semibold text-gray-800">Conversations</h2>
                </div>
                <div class="flex-1 overflow-y-auto" id="conversations-list">
                    <!-- Conversations will be loaded here -->
                </div>
            </div>

            <!-- Messages Area -->
            <div class="flex-1 flex flex-col">
                <div class="flex-1 overflow-y-auto p-4 space-y-4" id="messages-container">
                    <!-- Messages will be loaded here -->
                </div>

                <!-- Message Input -->
                <div class="p-4 border-t border-gray-200 bg-white">
                    <div class="flex space-x-2">
                        <input 
                            type="text" 
                            id="message-input" 
                            placeholder="Type a message..." 
                            class="flex-1 border border-gray-300 rounded-lg px-4 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500"
                            onkeypress="handleKeyPress(event)"
                        >
                        <button 
                            onclick="sendMessage()" 
                            class="bg-blue-600 hover:bg-blue-700 text-white px-6 py-2 rounded-lg font-medium"
                        >
                            Send
                        </button>
                    </div>
                </div>
            </div>
        </div>
    </div>

    <!-- JavaScript -->
    <script>
        // Global variables
        let currentConversationId = null;
        let currentUser = @json(auth()->user());
        let csrfToken = document.querySelector('meta[name="csrf-token"]').getAttribute('content');
        
        // Initialize app
        document.addEventListener('DOMContentLoaded', function() {
            initializeApp();
            loadConversations();
            setupWebSocket();
        });

        function initializeApp() {
            // Initialize Flutter bridge if available
            if (window.FlutterBridge) {
                window.FlutterBridge.postMessage(JSON.stringify({
                    type: 'request_device_token'
                }));
            }
        }

        function toggleNotifications() {
            if ('Notification' in window) {
                Notification.requestPermission().then(function (permission) {
                    if (permission === 'granted') {
                        console.log('Notifications enabled');
                        if (window.FlutterBridge) {
                            window.FlutterBridge.postMessage(JSON.stringify({
                                type: 'notification_permission',
                                permission: permission
                            }));
                        }
                    }
                });
            }
        }

        function loadConversations() {
            fetch('/api/conversations', {
                headers: {
                    'Authorization': 'Bearer ' + localStorage.getItem('api_token'),
                    'Content-Type': 'application/json'
                }
            })
            .then(response => response.json())
            .then(conversations => {
                renderConversations(conversations);
            })
            .catch(error => {
                console.error('Error loading conversations:', error);
            });
        }

        function renderConversations(conversations) {
            const container = document.getElementById('conversations-list');
            container.innerHTML = conversations.map(conversation => `
                <div class="p-4 border-b border-gray-100 hover:bg-gray-50 cursor-pointer" 
                     onclick="selectConversation(${conversation.id})">
                    <div class="flex justify-between items-start">
                        <div>
                            <h3 class="font-medium text-gray-900">${conversation.name || 'Direct Message'}</h3>
                            <p class="text-sm text-gray-500 mt-1">${conversation.last_message?.content || 'No messages yet'}</p>
                        </div>
                        <span class="text-xs text-gray-400">${formatTime(conversation.last_message_at)}</span>
                    </div>
                </div>
            `).join('');
        }

        function selectConversation(conversationId) {
            currentConversationId = conversationId;
            loadMessages(conversationId);
            
            // Mark as read
            fetch(`/api/conversations/${conversationId}/read`, {
                method: 'POST',
                headers: {
                    'Authorization': 'Bearer ' + localStorage.getItem('api_token'),
                    'Content-Type': 'application/json',
                    'X-CSRF-TOKEN': csrfToken
                }
            });
        }

        function loadMessages(conversationId) {
            fetch(`/api/conversations/${conversationId}/messages`, {
                headers: {
                    'Authorization': 'Bearer ' + localStorage.getItem('api_token'),
                    'Content-Type': 'application/json'
                }
            })
            .then(response => response.json())
            .then(data => {
                renderMessages(data.messages);
            })
            .catch(error => {
                console.error('Error loading messages:', error);
            });
        }

        function renderMessages(messages) {
            const container = document.getElementById('messages-container');
            container.innerHTML = messages.map(message => `
                <div class="flex ${message.user_id === currentUser.id ? 'justify-end' : 'justify-start'}">
                    <div class="max-w-xs lg:max-w-md px-4 py-2 rounded-lg ${
                        message.user_id === currentUser.id 
                            ? 'bg-blue-600 text-white' 
                            : 'bg-white text-gray-900 border border-gray-200'
                    }">
                        ${message.user_id !== currentUser.id ? `<p class="text-sm font-medium text-gray-500 mb-1">${message.user.name}</p>` : ''}
                        <p>${message.content}</p>
                        <p class="text-xs opacity-75 mt-1">${formatTime(message.created_at)}</p>
                    </div>
                </div>
            `).join('');
            
            // Scroll to bottom
            container.scrollTop = container.scrollHeight;
        }

        function sendMessage() {
            const input = document.getElementById('message-input');
            const content = input.value.trim();
            
            if (!content || !currentConversationId) return;
            
            fetch(`/api/conversations/${currentConversationId}/messages`, {
                method: 'POST',
                headers: {
                    'Authorization': 'Bearer ' + localStorage.getItem('api_token'),
                    'Content-Type': 'application/json',
                    'X-CSRF-TOKEN': csrfToken
                },
                body: JSON.stringify({
                    content: content,
                    type: 'text'
                })
            })
            .then(response => response.json())
            .then(message => {
                input.value = '';
                // Message will be added via WebSocket
            })
            .catch(error => {
                console.error('Error sending message:', error);
            });
        }

        function handleKeyPress(event) {
            if (event.key === 'Enter') {
                sendMessage();
            }
        }

        function setupWebSocket() {
            if (window.Echo) {
                // Listen for new messages
                Echo.private(`conversation.${currentConversationId}`)
                    .listen('MessageSent', (e) => {
                        addMessageToUI(e.message);
                        
                        // Send notification to Flutter if app is in background
                        if (window.FlutterBridge) {
                            window.FlutterBridge.postMessage(JSON.stringify({
                                type: 'notification',
                                title: e.user.name,
                                body: e.message.content,
                                data: {
                                    conversation_id: e.conversation_id,
                                    message_id: e.message.id
                                }
                            }));
                        }
                    });
            }
        }

        function addMessageToUI(message) {
            const container = document.getElementById('messages-container');
            const messageElement = document.createElement('div');
            messageElement.className = `flex ${message.user_id === currentUser.id ? 'justify-end' : 'justify-start'}`;
            messageElement.innerHTML = `
                <div class="max-w-xs lg:max-w-md px-4 py-2 rounded-lg ${
                    message.user_id === currentUser.id 
                        ? 'bg-blue-600 text-white' 
                        : 'bg-white text-gray-900 border border-gray-200'
                }">
                    ${message.user_id !== currentUser.id ? `<p class="text-sm font-medium text-gray-500 mb-1">${message.user.name}</p>` : ''}
                    <p>${message.content}</p>
                    <p class="text-xs opacity-75 mt-1">${formatTime(message.created_at)}</p>
                </div>
            `;
            container.appendChild(messageElement);
            container.scrollTop = container.scrollHeight;
        }

        function formatTime(timestamp) {
            return new Date(timestamp).toLocaleTimeString([], {hour: '2-digit', minute:'2-digit'});
        }

        // Flutter bridge callbacks
        window.onDeviceTokenReceived = function(token) {
            if (token) {
                // Update FCM token
                fetch('/api/fcm-token', {
                    method: 'POST',
                    headers: {
                        'Authorization': 'Bearer ' + localStorage.getItem('api_token'),
                        'Content-Type': 'application/json',
                        'X-CSRF-TOKEN': csrfToken
                    },
                    body: JSON.stringify({
                        fcm_token: token
                    })
                });
            }
        };

        window.onFlutterError = function(error) {
            console.error('Flutter error:', error);
        };
    </script>
</body>
</html>
```

## Configuration Files

### Environment Variables
```env
# .env
APP_NAME="Laravel Messaging App"
APP_ENV=production
APP_KEY=base64:your-app-key-here
APP_DEBUG=false
APP_URL=https://your-laravel-app.com

DB_CONNECTION=mysql
DB_HOST=127.0.0.1
DB_PORT=3306
DB_DATABASE=messaging_app
DB_USERNAME=your_username
DB_PASSWORD=your_password

BROADCAST_DRIVER=pusher
CACHE_DRIVER=redis
QUEUE_CONNECTION=redis
SESSION_DRIVER=redis

REDIS_HOST=127.0.0.1
REDIS_PASSWORD=null
REDIS_PORT=6379

PUSHER_APP_ID=your-pusher-app-id
PUSHER_APP_KEY=your-pusher-key
PUSHER_APP_SECRET=your-pusher-secret
PUSHER_APP_CLUSTER=mt1

FCM_SERVER_KEY=your-fcm-server-key

SANCTUM_STATEFUL_DOMAINS=your-laravel-app.com
```

### Broadcasting Configuration
```php
// config/broadcasting.php
return [
    'default' => env('BROADCAST_DRIVER', 'null'),
    'connections' => [
        'pusher' => [
            'driver' => 'pusher',
            'key' => env('PUSHER_APP_KEY'),
            'secret' => env('PUSHER_APP_SECRET'),
            'app_id' => env('PUSHER_APP_ID'),
            'options' => [
                'cluster' => env('PUSHER_APP_CLUSTER'),
                'useTLS' => true,
            ],
        ],
        'redis' => [
            'driver' => 'redis',
            'connection' => 'default',
        ],
    ],
];
```

## Deployment Steps

### 1. Server Setup
```bash
# Ubuntu/Debian server setup
sudo apt update
sudo apt install nginx mysql-server redis-server supervisor
sudo snap install php --classic
composer install --optimize-autoloader --no-dev
```

### 2. Database Setup
```bash
# Create database
mysql -u root -p
CREATE DATABASE messaging_app;
CREATE USER 'messaging_user'@'localhost' IDENTIFIED BY 'secure_password';
GRANT ALL PRIVILEGES ON messaging_app.* TO 'messaging_user'@'localhost';
FLUSH PRIVILEGES;

# Run migrations
php artisan migrate --force
php artisan db:seed
```

### 3. Queue Worker Setup
```bash
# supervisor configuration for queue workers
sudo nano /etc/supervisor/conf.d/laravel-worker.conf
```

### 4. Nginx Configuration
```nginx
server {
    listen 80;
    server_name your-laravel-app.com;
    root /var/www/messaging-app/public;

    index index.php;

    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }

    location ~ \.php$ {
        fastcgi_pass unix:/var/run/php/php8.2-fpm.sock;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME $realpath_root$fastcgi_script_name;
        include fastcgi_params;
    }

    location ~ /\.(?!well-known).* {
        deny all;
    }
}
```

### 5. WebSocket Server
```bash
# Install Laravel WebSockets (alternative to Pusher)
composer require beyondcode/laravel-websockets
php artisan vendor:publish --provider="BeyondCode\LaravelWebSockets\WebSocketsServiceProvider" --tag="migrations"
php artisan migrate
php artisan websockets:serve
```

## Testing Strategy

### API Tests
```php
// tests/Feature/MessageTest.php
<?php

namespace Tests\Feature;

use Tests\TestCase;
use App\Models\User;
use App\Models\Conversation;
use App\Models\Message;
use Illuminate\Foundation\Testing\RefreshDatabase;

class MessageTest extends TestCase
{
    use RefreshDatabase;

    public function test_user_can_send_message_to_conversation()
    {
        $user = User::factory()->create();
        $conversation = Conversation::factory()->create();
        $conversation->addParticipant($user);

        $response = $this->actingAs($user, 'sanctum')
                        ->postJson("/api/conversations/{$conversation->id}/messages", [
                            'content' => 'Hello World',
                            'type' => 'text'
                        ]);

        $response->assertStatus(201);
        $this->assertDatabaseHas('messages', [
            'conversation_id' => $conversation->id,
            'user_id' => $user->id,
            'content' => 'Hello World'
        ]);
    }

    public function test_user_can_get_conversation_messages()
    {
        $user = User::factory()->create();
        $conversation = Conversation::factory()->create();
        $conversation->addParticipant($user);
        
        Message::factory()->count(5)->create([
            'conversation_id' => $conversation->id,
            'user_id' => $user->id
        ]);

        $response = $this->actingAs($user, 'sanctum')
                        ->getJson("/api/conversations/{$conversation->id}/messages");

        $response->assertStatus(200);
        $response->assertJsonStructure([
            'messages' => [
                '*' => ['id', 'content', 'user_id', 'created_at']
            ],
            'pagination'
        ]);
    }
}
```

### WebSocket Tests
```php
// tests/Feature/WebSocketTest.php
<?php

namespace Tests\Feature;

use Tests\TestCase;
use App\Models\User;
use App\Models\Conversation;
use App\Events\MessageSent;
use Illuminate\Support\Facades\Event;
use Illuminate\Foundation\Testing\RefreshDatabase;

class WebSocketTest extends TestCase
{
    use RefreshDatabase;

    public function test_message_sent_event_is_broadcasted()
    {
        Event::fake();

        $user = User::factory()->create();
        $conversation = Conversation::factory()->create();
        $conversation->addParticipant($user);

        $this->actingAs($user, 'sanctum')
            ->postJson("/api/conversations/{$conversation->id}/messages", [
                'content' => 'Hello World',
                'type' => 'text'
            ]);

        Event::assertDispatched(MessageSent::class);
    }
}
```

## Security Considerations

### Authentication & Authorization
1. **JWT Token Security**: Use Laravel Sanctum for API authentication
2. **CSRF Protection**: Implement CSRF tokens for web forms
3. **Rate Limiting**: Implement rate limiting for API endpoints
4. **Input Validation**: Validate all user inputs
5. **XSS Prevention**: Sanitize message content

### Data Security
1. **Encryption**: Encrypt sensitive data at rest
2. **HTTPS**: Force HTTPS for all communications
3. **Database Security**: Use parameterized queries
4. **File Upload Security**: Validate file uploads
5. **Message Privacy**: Implement proper access controls

### Performance Optimization

### Database Optimization
1. **Indexing**: Add proper database indexes
2. **Query Optimization**: Optimize N+1 queries
3. **Connection Pooling**: Use database connection pooling
4. **Caching**: Implement Redis caching

### Application Performance
1. **Queue System**: Use queues for heavy operations
2. **CDN**: Use CDN for static assets
3. **Compression**: Enable gzip compression
4. **Opcache**: Enable PHP opcache

## Monitoring & Logging

### Application Monitoring
1. **Error Tracking**: Use Sentry or similar
2. **Performance Monitoring**: Use New Relic or similar
3. **Uptime Monitoring**: Use Pingdom or similar
4. **Log Management**: Use ELK stack or similar

### Metrics to Track
1. **API Response Times**
2. **WebSocket Connection Count**
3. **Message Delivery Success Rate**
4. **Push Notification Delivery Rate**
5. **Database Query Performance**

## Future Enhancements

### Phase 1 Extensions
1. **File Sharing**: Support for image/file messages
2. **Voice Messages**: Audio message support
3. **Message Reactions**: Emoji reactions
4. **Message Threading**: Reply to specific messages

### Phase 2 Extensions
1. **Group Management**: Advanced group features
2. **User Roles**: Admin, moderator roles
3. **Message Encryption**: End-to-end encryption
4. **Video Calling**: WebRTC integration

### Phase 3 Extensions
1. **Bot Integration**: Chatbot support
2. **Message Translation**: Multi-language support
3. **Advanced Search**: Full-text search
4. **Analytics Dashboard**: Usage analytics

This comprehensive implementation plan provides a solid foundation for building a production-ready Laravel messaging application that seamlessly integrates with the Flutter WebView app.