import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../config/api_config.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../services/shop_config.dart';
import '../models/push_notification.dart';

/// Wraps Firebase Cloud Messaging for Magray Orchards.
///
/// Firebase options are read from the server (`GET /api/config` → admin
/// "Firebase Setup" page) first, then `--dart-define` as a build-time
/// override. The app works on web/mobile before a real Firebase project is
/// configured by gracefully disabling push:
///   flutter run --dart-define=FIREBASE_API_KEY=... --dart-define=FIREBASE_APP_ID=...
///   --dart-define=FIREBASE_MESSAGING_SENDER_ID=... --dart-define=FIREBASE_PROJECT_ID=...
///   --dart-define=FIREBASE_AUTH_DOMAIN=... --dart-define=FIREBASE_STORAGE_BUCKET=...
class PushService {
  static final PushService instance = PushService._();
  PushService._();

  static const _apiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const _appId = String.fromEnvironment('FIREBASE_APP_ID');
  static const _senderId = String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID');
  static const _projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
  static const _authDomain = String.fromEnvironment('FIREBASE_AUTH_DOMAIN');
  static const _storageBucket = String.fromEnvironment('FIREBASE_STORAGE_BUCKET');

  bool _initialized = false;
  bool _configured = false;
  FirebaseMessaging? _messaging;
  String? _token;
  String? _pendingToken;

  /// Whether Firebase config is present (enables real push delivery).
  bool get isConfigured => _configured;
  bool get isInitialized => _initialized;

  /// Called once from main() — must be awaited before runApp.
  Future<void> initialize() async {
    if (_initialized) return;

    // Prefer dart-define; fall back to the server-provided config so the
    // admin can manage Firebase from the panel without rebuilding the app.
    final apiKey = _apiKey.isNotEmpty ? _apiKey : ShopConfig.firebaseApiKey;
    final appId = _appId.isNotEmpty ? _appId : ShopConfig.firebaseAppId;
    final senderId = _senderId.isNotEmpty ? _senderId : ShopConfig.firebaseMessagingSenderId;
    final projectId = _projectId.isNotEmpty ? _projectId : ShopConfig.firebaseProjectId;
    final authDomain = _authDomain.isNotEmpty ? _authDomain : ShopConfig.firebaseAuthDomain;
    final storageBucket = _storageBucket.isNotEmpty ? _storageBucket : ShopConfig.firebaseStorageBucket;

    // Only initialize when we have valid credentials.
    if (apiKey.isEmpty || appId.isEmpty || projectId.isEmpty) {
      _initialized = true;
      _configured = false;
      debugPrint('PushService: Firebase not configured — push disabled.');
      return;
    }

    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: FirebaseOptions(
            apiKey: apiKey,
            appId: appId,
            messagingSenderId: senderId,
            projectId: projectId,
            authDomain: authDomain.isEmpty ? null : authDomain,
            storageBucket: storageBucket.isEmpty ? null : storageBucket,
          ),
        );
      }
      _messaging = FirebaseMessaging.instance;
      _configured = true;
      _initialized = true;
      debugPrint('PushService: Firebase initialized.');
    } catch (e) {
      _initialized = true;
      _configured = false;
      debugPrint('PushService: Firebase init failed: $e');
    }
  }

  /// Registers the FCM token with the backend for the logged-in user.
  /// Safe to call after login; re-registers if the token rotated.
  Future<void> registerToken(AuthProvider auth, {String deviceType = 'android'}) async {
    if (!_configured || !auth.isLoggedIn) return;

    try {
      final token = await _messaging!.getToken();
      if (token == null || token.isEmpty) return;
      _token = token;
      if (token != _pendingToken) {
        await ApiService.registerDeviceToken(token, deviceType: deviceType);
        _pendingToken = token;
        debugPrint('PushService: token registered (${token.length} chars).');
      }
    } catch (e) {
      debugPrint('PushService: token registration failed: $e');
    }
  }

  /// Removes the backend token binding (on logout).
  Future<void> unregisterToken() async {
    final token = _token;
    _token = null;
    _pendingToken = null;
    if (!_configured || token == null || token.isEmpty) return;
    try {
      await ApiService.unregisterDeviceToken(token);
    } catch (e) {
      debugPrint('PushService: token unregister failed: $e');
    }
  }

  /// Refreshes the token (fires when FCM rotates it).
  Future<void> watchTokenRefresh(AuthProvider auth) async {
    if (!_configured) return;
    _messaging!.onTokenRefresh.listen((newToken) {
      _token = newToken;
      if (auth.isLoggedIn) {
        ApiService.registerDeviceToken(newToken).catchError((e) {
          debugPrint('PushService: token refresh register failed: $e');
        });
      }
    });
  }

  /// Foreground message stream — used to show an in-app banner.
  Stream<RemoteMessage> get onMessage {
    if (!_configured) return const Stream.empty();
    return FirebaseMessaging.onMessage.asBroadcastStream();
  }

  /// Message tapped (app in background/terminated) — used for deep linking.
  Stream<RemoteMessage> get onMessageOpenedApp {
    if (!_configured) return const Stream.empty();
    return FirebaseMessaging.onMessageOpenedApp.asBroadcastStream();
  }

  /// Message that opened the app (terminated state).
  Future<RemoteMessage?> getInitialMessage() async {
    if (!_configured) return null;
    try {
      return await _messaging!.getInitialMessage();
    } catch (_) {
      return null;
    }
  }

  /// Whether notifications are permitted on this device.
  Future<bool> requestPermission() async {
    if (!_configured) return false;
    try {
      final settings = await _messaging!.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      return settings.authorizationStatus == AuthorizationStatus.authorized;
    } catch (e) {
      debugPrint('PushService: permission request failed: $e');
      return false;
    }
  }

  /// Parses a remote message into a friendly PushNotification (used for the
  /// foreground banner). Falls back to the payload keys the backend sends.
  PushNotification messageToNotification(RemoteMessage message) {
    final n = message.notification;
    final data = message.data;
    final title = n?.title ?? (data['title'] ?? 'Magray Orchards').toString();
    final body = n?.body ?? (data['body'] ?? '').toString();
    return PushNotification(
      id: int.tryParse(data['notification_id'] ?? '') ?? 0,
      title: title,
      body: body,
      type: (data['type'] ?? 'transactional').toString(),
      trigger: data['trigger']?.toString(),
      data: data,
      isRead: false,
      createdAt: DateTime.now(),
    );
  }

  /// Deep-link navigation target derived from a message payload.
  ({String? screen, int? id}) parseTarget(RemoteMessage message) {
    final data = message.data;
    String? screen = data['screen']?.toString();
    if (screen == null || screen.isEmpty) {
      if (data['order_id'] != null) screen = 'order';
      else if (data['booking_id'] != null) screen = 'booking';
      else if (data['subscription_id'] != null) screen = 'subscription';
      else if (data['type']?.toString() == 'promotional') screen = 'notifications';
    }
    final raw = data['order_id'] ?? data['booking_id'] ?? data['subscription_id'];
    final id = raw is num ? raw.toInt() : int.tryParse(raw?.toString() ?? '');
    return (screen: screen, id: id);
  }
}

/// Handles a background message (app terminated or in background) on Android.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (Firebase.apps.isEmpty) return;
  debugPrint('PushService (background): ${message.notification?.title}');
}

/// Convenience: shows a MaterialBanner/SnackBar for a foreground message.
void showForegroundPushBanner(BuildContext context, PushNotification n) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      content: Row(
        children: [
          const Icon(Icons.notifications_active_outlined, color: Colors.white, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  n.title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (n.body.isNotEmpty)
                  Text(n.body, maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
      duration: const Duration(seconds: 4),
    ),
  );
}