import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import '../models/home_section.dart';
import 'api_service.dart';

class ShopConfig {
  static double _taxRate = 18;
  static bool _gstEnabled = true;
  static String _gstin = '';
  static double _maxOrderAmount = 0;
  static String _announcementMessage = 'Free Delivery on Orders Above Rs.999';
  static String _announcementMessageShort = 'Free Delivery on Rs.999+';
  static double _freeDeliveryThreshold = 999;
  static bool _otpVerificationEnabled = true;
  static bool _promoBannerEnabled = true;
  static String _promoBannerTitle = 'Free Delivery on Orders Above Rs.999';
  static String _promoBannerSubtitle =
      'Grab the best deals on premium farming essentials before they\'re gone.';
  static Color _promoBannerColor = const Color(0xFFF97316);
  static String _promoBannerLink = '';

  // Mobile app version / maintenance
  static String _androidLatestVersion = '1.0.0';
  static String _androidMinVersion = '1.0.0';
  static String _androidStoreUrl = '';
  static String _iosLatestVersion = '1.0.0';
  static String _iosMinVersion = '1.0.0';
  static String _iosStoreUrl = '';
  static String _updateNotes = '';
  static bool _maintenanceEnabled = false;
  static String _maintenanceMessage =
      'We are currently under maintenance. Please check back soon.';
  static String _maintenanceUntil = '';

  // App home page layout (ordered, admin-configurable).
  static List<HomeSection> _homeSections = const [];

  static const List<HomeSection> _defaultHomeSections = [
    HomeSection(type: 'announcement'),
    HomeSection(type: 'delivery'),
    HomeSection(type: 'banner_carousel'),
    HomeSection(type: 'categories'),
    HomeSection(type: 'brands'),
    HomeSection(type: 'promo'),
    HomeSection(
        type: 'products',
        title: "Today's Offers",
        source: 'offers',
        layout: 'carousel',
        rows: 1,
        limit: 10),
    HomeSection(type: 'subscription'),
    HomeSection(
        type: 'products',
        title: 'Featured Products',
        source: 'featured',
        layout: 'carousel',
        rows: 1,
        limit: 10),
    HomeSection(
        type: 'products',
        title: 'Newly Added',
        source: 'newest',
        layout: 'grid',
        rows: 2,
        limit: 10),
    HomeSection(type: 'services'),
  ];

  static double get taxRate => _taxRate;
  static bool get gstEnabled => _gstEnabled;
  static double get taxDecimal => _gstEnabled ? _taxRate / 100 : 0;
  static String get gstin => _gstin;
  static double get maxOrderAmount => _maxOrderAmount;
  static String get announcementMessage => _announcementMessage;
  static String get announcementMessageShort => _announcementMessageShort;
  static double get freeDeliveryThreshold => _freeDeliveryThreshold;
  static bool get otpVerificationEnabled => _otpVerificationEnabled;
  static bool get promoBannerEnabled => _promoBannerEnabled;
  static String get promoBannerTitle => _promoBannerTitle;
  static String get promoBannerSubtitle => _promoBannerSubtitle;
  static Color get promoBannerColor => _promoBannerColor;
  static String get promoBannerLink => _promoBannerLink;

  static String get androidLatestVersion => _androidLatestVersion;
  static String get androidMinVersion => _androidMinVersion;
  static String get androidStoreUrl => _androidStoreUrl;
  static String get iosLatestVersion => _iosLatestVersion;
  static String get iosMinVersion => _iosMinVersion;
  static String get iosStoreUrl => _iosStoreUrl;
  static String get updateNotes => _updateNotes;
  static bool get maintenanceEnabled => _maintenanceEnabled;
  static String get maintenanceMessage => _maintenanceMessage;
  static String get maintenanceUntil => _maintenanceUntil;

  /// Ordered home sections. Falls back to the built-in default layout when
  /// the admin has not saved a layout (or the payload is empty).
  static List<HomeSection> get homeSections =>
      _homeSections.isNotEmpty ? _homeSections : _defaultHomeSections;

  /// Latest/min version + store URL for the current platform.
  /// On web (or unknown platform) defaults to Android values; gating is
  /// skipped on web since there is no installed app version to compare.
  static String get latestVersion =>
      _isAndroid() ? _androidLatestVersion : _iosLatestVersion;
  static String get minVersion =>
      _isAndroid() ? _androidMinVersion : _iosMinVersion;
  static String get storeUrl => _isAndroid() ? _androidStoreUrl : _iosStoreUrl;

  static bool _isAndroid() {
    if (kIsWeb) return true;
    return !Platform.isIOS;
  }

  static Future<void> load() async {
    try {
      final response = await ApiService.get('/config');
      final data = response['data'] ?? response;
      _taxRate = (data['tax_rate'] as num?)?.toDouble() ?? 18;
      _gstEnabled = (data['gst_enabled'] as bool?) ?? true;
      _gstin = (data['gstin'] as String?) ?? '';
      _maxOrderAmount = (data['max_order_amount'] as num?)?.toDouble() ?? 0;
      _announcementMessage = (data['announcement_message'] as String?) ?? _announcementMessage;
      _announcementMessageShort = (data['announcement_message_short'] as String?) ?? _announcementMessageShort;
      _freeDeliveryThreshold = (data['free_delivery_threshold'] as num?)?.toDouble() ?? 999;
      _otpVerificationEnabled = (data['otp_verification_enabled'] as bool?) ?? true;
      _promoBannerEnabled = (data['promo_banner_enabled'] as bool?) ?? true;
      _promoBannerTitle = (data['promo_banner_title'] as String?) ?? _promoBannerTitle;
      _promoBannerSubtitle = (data['promo_banner_subtitle'] as String?) ?? _promoBannerSubtitle;
      final colorHex = (data['promo_banner_color'] as String?) ?? '';
      if (colorHex.isNotEmpty) {
        final parsed = _parseHexColor(colorHex);
        if (parsed != null) _promoBannerColor = parsed;
      }
      _promoBannerLink = (data['promo_banner_link'] as String?) ?? '';

      _androidLatestVersion = (data['mobile_app_android_latest_version'] as String?) ?? _androidLatestVersion;
      _androidMinVersion = (data['mobile_app_android_min_version'] as String?) ?? _androidMinVersion;
      _androidStoreUrl = (data['mobile_app_android_store_url'] as String?) ?? '';
      _iosLatestVersion = (data['mobile_app_ios_latest_version'] as String?) ?? _iosLatestVersion;
      _iosMinVersion = (data['mobile_app_ios_min_version'] as String?) ?? _iosMinVersion;
      _iosStoreUrl = (data['mobile_app_ios_store_url'] as String?) ?? '';
      _updateNotes = (data['mobile_app_update_notes'] as String?) ?? '';
      _maintenanceEnabled = (data['mobile_app_maintenance_enabled'] as bool?) ?? false;
      _maintenanceMessage = (data['mobile_app_maintenance_message'] as String?) ?? _maintenanceMessage;
      _maintenanceUntil = (data['mobile_app_maintenance_until'] as String?) ?? '';

      final layout = HomeLayout.fromJson(data['home_layout']);
      _homeSections = layout.sections;
    } catch (_) {
    }
  }

  static Color? _parseHexColor(String hex) {
    var value = hex.replaceFirst('#', '');
    if (value.length == 6) value = 'FF$value';
    if (value.length != 8) return null;
    final parsed = int.tryParse(value, radix: 16);
    if (parsed == null) return null;
    return Color(parsed);
  }

  /// Semantic version compare. Returns <0, 0, >0 if a <, ==, > b.
  static int compareVersions(String a, String b) {
    final pa = _parts(a);
    final pb = _parts(b);
    final len = pa.length > pb.length ? pa.length : pb.length;
    for (var i = 0; i < len; i++) {
      final x = i < pa.length ? pa[i] : 0;
      final y = i < pb.length ? pb[i] : 0;
      if (x != y) return x - y;
    }
    return 0;
  }

  static List<int> _parts(String v) {
    return v
        .replaceAll(RegExp(r'[^\d.]'), '')
        .split('.')
        .map((s) => int.tryParse(s) ?? 0)
        .toList();
  }

  static double calculateTax(double subtotal) {
    return subtotal * taxDecimal;
  }
}
