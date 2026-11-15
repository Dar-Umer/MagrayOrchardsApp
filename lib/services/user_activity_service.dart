import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/product.dart';
import 'api_service.dart';

class UserActivityService {
  static const String _recentProductsKey = 'user_recent_products_cache';
  static const String _sessionIdKey = 'user_device_session_id';
  static const int _maxRecentCache = 20;

  static String? _cachedSessionId;

  /// Get or create a persistent anonymous device session ID.
  static Future<String> getSessionId() async {
    if (_cachedSessionId != null) return _cachedSessionId!;
    try {
      final prefs = await SharedPreferences.getInstance();
      var sid = prefs.getString(_sessionIdKey);
      if (sid == null || sid.isEmpty) {
        sid = 'guest_${DateTime.now().millisecondsSinceEpoch}_${(1000 + (DateTime.now().microsecond % 9000))}';
        await prefs.setString(_sessionIdKey, sid);
      }
      _cachedSessionId = sid;
      return sid;
    } catch (_) {
      return 'anon_session';
    }
  }

  /// Get locally cached recently viewed products for zero-latency instant render.
  static Future<List<Product>> getLocalRecentProducts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_recentProductsKey);
      if (raw == null || raw.isEmpty) return [];
      final List<dynamic> list = jsonDecode(raw);
      return list.whereType<Map<String, dynamic>>().map((e) => Product.fromJson(e)).toList();
    } catch (e) {
      if (kDebugMode) debugPrint('Error reading local recent products: $e');
      return [];
    }
  }

  /// Record a product view locally and sync asynchronously with backend.
  static Future<void> recordProductView(Product product) async {
    try {
      // 1. Update local cache immediately
      final prefs = await SharedPreferences.getInstance();
      final current = await getLocalRecentProducts();

      // Remove duplicate if exists, prepend to front
      current.removeWhere((p) => p.id == product.id);
      current.insert(0, product);
      if (current.length > _maxRecentCache) {
        current.removeRange(_maxRecentCache, current.length);
      }

      await prefs.setString(
        _recentProductsKey,
        jsonEncode(current.map((p) => p.toJson()).toList()),
      );

      // 2. Sync to backend asynchronously
      final sessionId = await getSessionId();
      _syncViewToBackend(product.id, sessionId);
    } catch (e) {
      if (kDebugMode) debugPrint('Error recording product view: $e');
    }
  }

  /// Fire and forget background sync to Laravel API
  static Future<void> _syncViewToBackend(int productId, String sessionId) async {
    try {
      await ApiService.post('/user/activity', body: {
        'product_id': productId,
        'session_id': sessionId,
      });
    } catch (_) {
      // Offline or network error - local cache already has it
    }
  }

  /// Clear local recent history
  static Future<void> clearLocalHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_recentProductsKey);
    } catch (_) {}
  }
}
