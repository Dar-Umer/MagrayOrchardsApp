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

  static double get taxRate => _taxRate;
  static bool get gstEnabled => _gstEnabled;
  static double get taxDecimal => _gstEnabled ? _taxRate / 100 : 0;
  static String get gstin => _gstin;
  static double get maxOrderAmount => _maxOrderAmount;
  static String get announcementMessage => _announcementMessage;
  static String get announcementMessageShort => _announcementMessageShort;
  static double get freeDeliveryThreshold => _freeDeliveryThreshold;
  static bool get otpVerificationEnabled => _otpVerificationEnabled;

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
    } catch (_) {
    }
  }

  static double calculateTax(double subtotal) {
    return subtotal * taxDecimal;
  }
}
