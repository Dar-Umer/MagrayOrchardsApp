import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import '../models/home_section.dart';
import 'api_service.dart';

class ShopConfig {
  /// Bumped every time [load] succeeds, so UI can react to remote config
  /// changes (admin toggles) without a full app restart. The home screen
  /// listens to this to rebuild its sections.
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  static String _siteName = 'Magray Orchards';
  static String _logoUrl = '';
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

  // Firebase (FCM) app config — fetched from /api/config, used by PushService.
  static String _firebaseApiKey = '';
  static String _firebaseAppId = '';
  static String _firebaseMessagingSenderId = '';
  static String _firebaseProjectId = '';
  static String _firebaseAuthDomain = '';
  static String _firebaseStorageBucket = '';

  // App home page layout (ordered, admin-configurable).
  static List<HomeSection> _homeSections = const [];

  static const List<HomeSection> _defaultHomeSections = [
    HomeSection(type: 'delivery', enabled: false),
    HomeSection(type: 'banner_carousel'),
    HomeSection(type: 'categories'),
    HomeSection(type: 'brands'),
    HomeSection(type: 'promo', enabled: false),
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

  static String get siteName => _siteName;
  static String get logoUrl => _logoUrl;
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

  static String get firebaseApiKey => _firebaseApiKey;
  static String get firebaseAppId => _firebaseAppId;
  static String get firebaseMessagingSenderId => _firebaseMessagingSenderId;
  static String get firebaseProjectId => _firebaseProjectId;
  static String get firebaseAuthDomain => _firebaseAuthDomain;
  static String get firebaseStorageBucket => _firebaseStorageBucket;

  /// Whether the server provided a complete Firebase config for this app.
  static bool get firebaseConfigured =>
      _firebaseApiKey.isNotEmpty &&
      _firebaseAppId.isNotEmpty &&
      _firebaseProjectId.isNotEmpty;

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

  static String _str(dynamic v, [String fallback = '']) =>
      v == null ? fallback : v.toString();

  static String _strNonEmpty(dynamic v, String fallback) {
    final s = v?.toString().trim() ?? '';
    return s.isNotEmpty ? s : fallback;
  }

  static double _double(dynamic v, double fallback) {
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '') ?? fallback;
  }

  static bool _bool(dynamic v, bool fallback) {
    if (v is bool) return v;
    if (v is num) return v != 0;
    if (v is String) {
      if (v.toLowerCase() == 'true' || v == '1') return true;
      if (v.toLowerCase() == 'false' || v == '0') return false;
    }
    return fallback;
  }

  @visibleForTesting
  static Future<bool> Function()? mockLoaderForTesting;

  static Future<bool> load({bool rethrowErrors = false}) async {
    if (mockLoaderForTesting != null) {
      try {
        final ok = await mockLoaderForTesting!();
        if (!ok && rethrowErrors) {
          throw ApiException(
            statusCode: 0,
            message: 'Unable to connect to Magray Orchards servers. Please check your connection.',
          );
        }
        return ok;
      } catch (e) {
        if (rethrowErrors) rethrow;
        return false;
      }
    }
    try {
      final response = await ApiService.get('/config');
      final data = response['data'] ?? response;
      if (data is! Map) return false;

      _siteName = _strNonEmpty(data['site_name'], _siteName);
      _logoUrl = _str(data['logo_url']);
      _taxRate = _double(data['tax_rate'], 18);
      _gstEnabled = _bool(data['gst_enabled'], true);
      _gstin = _str(data['gstin']);
      _maxOrderAmount = _double(data['max_order_amount'], 0);
      _announcementMessage = _str(data['announcement_message'], _announcementMessage);
      _announcementMessageShort =
          _str(data['announcement_message_short'], _announcementMessageShort);
      _freeDeliveryThreshold = _double(data['free_delivery_threshold'], 999);
      _otpVerificationEnabled = _bool(data['otp_verification_enabled'], true);
      _promoBannerEnabled = _bool(data['promo_banner_enabled'], true);
      _promoBannerTitle = _str(data['promo_banner_title'], _promoBannerTitle);
      _promoBannerSubtitle = _str(data['promo_banner_subtitle'], _promoBannerSubtitle);
      final colorHex = _str(data['promo_banner_color']);
      if (colorHex.isNotEmpty) {
        final parsed = _parseHexColor(colorHex);
        if (parsed != null) _promoBannerColor = parsed;
      }
      _promoBannerLink = _str(data['promo_banner_link']);

      _androidLatestVersion = _strNonEmpty(
          data['mobile_app_android_latest_version'], _androidLatestVersion);
      _androidMinVersion = _strNonEmpty(
          data['mobile_app_android_min_version'], _androidMinVersion);
      _androidStoreUrl = _str(data['mobile_app_android_store_url']);
      _iosLatestVersion = _strNonEmpty(
          data['mobile_app_ios_latest_version'], _iosLatestVersion);
      _iosMinVersion =
          _strNonEmpty(data['mobile_app_ios_min_version'], _iosMinVersion);
      _iosStoreUrl = _str(data['mobile_app_ios_store_url']);
      _updateNotes = _str(data['mobile_app_update_notes']);
      _maintenanceEnabled = _bool(data['mobile_app_maintenance_enabled'], false);
      _maintenanceMessage = _strNonEmpty(
          data['mobile_app_maintenance_message'], _maintenanceMessage);
      _maintenanceUntil = _str(data['mobile_app_maintenance_until']);

      final firebase = data['firebase'];
      if (firebase is Map) {
        _firebaseApiKey = _str(firebase['api_key']);
        _firebaseAppId = _str(firebase['app_id']);
        _firebaseMessagingSenderId = _str(firebase['messaging_sender_id']);
        _firebaseProjectId = _str(firebase['project_id']);
        _firebaseAuthDomain = _str(firebase['auth_domain']);
        _firebaseStorageBucket = _str(firebase['storage_bucket']);
      }

      final layout = HomeLayout.fromJson(data['home_layout']);
      _homeSections = layout.sections;

      // Notify listeners (home screen, checkout, etc.) that config changed.
      revision.value++;
      return true;
    } catch (e) {
      debugPrint('ShopConfig.load failed: $e');
      if (rethrowErrors) rethrow;
      return false;
    }
  }

  @visibleForTesting
  static void setMaintenanceForTesting(bool enabled, [String message = '', String until = '']) {
    _maintenanceEnabled = enabled;
    if (message.isNotEmpty) _maintenanceMessage = message;
    if (until.isNotEmpty) _maintenanceUntil = until;
  }

  @visibleForTesting
  static void setMinVersionForTesting(String version) {
    _androidMinVersion = version;
    _iosMinVersion = version;
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
