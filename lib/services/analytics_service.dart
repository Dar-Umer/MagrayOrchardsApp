import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';
import 'location_service.dart';

class AnalyticsService {
  AnalyticsService._();
  static final AnalyticsService instance = AnalyticsService._();

  static bool enableHeartbeat = true;
  static const String _sessionKey = 'analytics_session_id';
  String? _sessionId;
  Timer? _heartbeatTimer;

  String _currentScreen = 'HomeScreen';
  int? _currentProductId;
  int? _currentServiceId;
  String? _currentServiceSlug;
  bool _isInitialized = false;

  String get sessionId => _sessionId ?? 'guest-session';
  String get currentScreen => _currentScreen;

  /// Initializes analytics, loads or generates persistent session ID,
  /// and starts a non-intrusive 30-second presence heartbeat.
  Future<void> init() async {
    if (_isInitialized) return;
    _isInitialized = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      _sessionId = prefs.getString(_sessionKey);

      if (_sessionId == null || _sessionId!.isEmpty) {
        final rand = Random().nextInt(999999);
        _sessionId = 'ses-${DateTime.now().millisecondsSinceEpoch}-$rand';
        await prefs.setString(_sessionKey, _sessionId!);
      }
    } catch (_) {
      _sessionId ??= 'ses-${DateTime.now().millisecondsSinceEpoch}';
    }

    _startHeartbeat();
  }

  void _startHeartbeat() {
    if (!enableHeartbeat) return;
    try {
      if (Platform.environment.containsKey('FLUTTER_TEST')) return;
    } catch (_) {}

    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _sendPing(isHeartbeat: true);
    });
  }

  /// Track when a user navigates to a new screen or views an item.
  Future<void> trackScreen(
    String screenName, {
    int? productId,
    int? serviceId,
    String? serviceSlug,
    String? eventType,
    Map<String, dynamic>? metadata,
  }) async {
    _currentScreen = screenName;
    _currentProductId = productId;
    _currentServiceId = serviceId;
    _currentServiceSlug = serviceSlug;

    await _sendPing(
      screen: screenName,
      productId: productId,
      serviceId: serviceId,
      serviceSlug: serviceSlug,
      eventType: eventType ?? (productId != null ? 'product_view' : (serviceId != null || serviceSlug != null ? 'service_view' : 'screen_view')),
      metadata: metadata,
      isHeartbeat: false,
    );
  }

  Future<void> _sendPing({
    String? screen,
    int? productId,
    int? serviceId,
    String? serviceSlug,
    String? eventType,
    Map<String, dynamic>? metadata,
    bool isHeartbeat = false,
  }) async {
    if (_sessionId == null) {
      await init();
    }

    final targetScreen = screen ?? _currentScreen;
    final targetProduct = productId ?? _currentProductId;
    final targetService = serviceId ?? _currentServiceId;
    final targetSlug = serviceSlug ?? _currentServiceSlug;

    // Detect district from pre-collected LocationService
    String? district;
    try {
      final loc = LocationService.instance;
      if (loc.hasLocation && loc.address != null) {
        final addr = loc.address!.toLowerCase();
        for (final d in ['pulwama', 'shopian', 'srinagar', 'baramulla', 'anantnag', 'budgam', 'ganderbal', 'kulgam', 'kupwara', 'bandipora']) {
          if (addr.contains(d)) {
            district = d[0].toUpperCase() + d.substring(1);
            break;
          }
        }
        district ??= loc.address!.split(',').first.trim();
      }
    } catch (_) {}

    String deviceType = 'android';
    try {
      if (!kIsWeb && Platform.isIOS) {
        deviceType = 'ios';
      }
    } catch (_) {}

    final payload = {
      'session_id': _sessionId,
      'screen_name': targetScreen,
      'event_type': eventType ?? (isHeartbeat ? 'heartbeat' : 'screen_view'),
      'device_type': deviceType,
      'app_version': '1.0.0',
      if (targetProduct != null) 'product_id': targetProduct,
      if (targetService != null) 'service_id': targetService,
      if (targetSlug != null) 'service_slug': targetSlug,
      if (district != null) 'district': district,
      if (metadata != null) 'metadata': metadata,
    };

    try {
      await ApiService.post('/analytics/track', body: payload);
    } catch (e) {
      // Non-blocking fire-and-forget: fail silently on network timeout
      if (kDebugMode) {
        debugPrint('AnalyticsService non-blocking ping skipped: $e');
      }
    }
  }

  void dispose() {
    _heartbeatTimer?.cancel();
  }
}
