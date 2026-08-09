import 'dart:ui';
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

  static double calculateTax(double subtotal) {
    return subtotal * taxDecimal;
  }
}
