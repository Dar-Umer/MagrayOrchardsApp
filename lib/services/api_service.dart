import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';
import '../models/service_booking.dart';

class ApiService {
  static String? _token;
  static VoidCallback? _onUnauthorized;

  static void setOnUnauthorized(voidCallback) {
    _onUnauthorized = voidCallback;
  }

  static Future<void> loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('auth_token');
  }

  static Future<void> setToken(String? token) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    if (token != null) {
      await prefs.setString('auth_token', token);
    } else {
      await prefs.remove('auth_token');
    }
  }

  static String? get token => _token;

  static Map<String, String> _headers() {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (_token != null) {
      headers['Authorization'] = 'Bearer $_token';
    }
    return headers;
  }

  static String _extractMessage(dynamic body, String fallback) {
    if (body is Map) {
      if (body['message'] is String && (body['message'] as String).isNotEmpty) {
        return body['message'] as String;
      }
      if (body['errors'] is Map) {
        final errors = body['errors'] as Map;
        final first = errors.values.first;
        if (first is List && first.isNotEmpty) {
          return first.first.toString();
        }
      }
    }
    return fallback;
  }

  static dynamic _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return null;
      return json.decode(response.body);
    }

    if (response.statusCode == 401) {
      _onUnauthorized?.call();
      throw ApiException(
        statusCode: 401,
        message: 'Your session has expired. Please log in again.',
      );
    }

    final body = response.body.isNotEmpty ? json.decode(response.body) : null;

    final message = _extractMessage(body, _defaultMessage(response.statusCode));

    throw ApiException(
      statusCode: response.statusCode,
      message: message,
    );
  }

  static String _defaultMessage(int statusCode) {
    switch (statusCode) {
      case 400:
        return 'Invalid request. Please check your input.';
      case 403:
        return 'You don\'t have permission to do this.';
      case 404:
        return 'The requested resource was not found.';
      case 422:
        return 'Please check your input and try again.';
      case 429:
        return 'Too many requests. Please wait a moment and try again.';
      case 500:
        return 'Something went wrong on our end. Please try again.';
      case 503:
        return 'The service is temporarily unavailable. Please try again later.';
      default:
        return 'An unexpected error occurred. Please try again.';
    }
  }

  static Future<dynamic> _makeRequest(Future<http.Response> Function() request) async {
    try {
      final response = await request().timeout(const Duration(seconds: 30));
      return _handleResponse(response);
    } on SocketException {
      debugPrint('ApiService: SocketException');
      throw ApiException(
        statusCode: 0,
        message: 'No internet connection. Please check your network and try again.',
      );
    } on TimeoutException {
      debugPrint('ApiService: TimeoutException');
      throw ApiException(
        statusCode: 0,
        message: 'Request timed out. Please try again.',
      );
    } on HandshakeException {
      debugPrint('ApiService: HandshakeException');
      throw ApiException(
        statusCode: 0,
        message: 'Secure connection failed. Please try again.',
      );
    } on http.ClientException {
      debugPrint('ApiService: ClientException');
      throw ApiException(
        statusCode: 0,
        message: 'Could not connect to the server. Please try again.',
      );
    } catch (e, s) {
      debugPrint('ApiService._makeRequest unexpected error: $e\n$s');
      rethrow;
    }
  }

  static Future<dynamic> get(String endpoint, {Map<String, String>? queryParams}) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}$endpoint')
        .replace(queryParameters: queryParams);
    return _makeRequest(() => http.get(uri, headers: _headers()));
  }

  static Future<dynamic> post(String endpoint, {dynamic body}) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}$endpoint');
    return _makeRequest(() => http.post(
      uri,
      headers: _headers(),
      body: body != null ? json.encode(body) : null,
    ));
  }

  static Future<dynamic> put(String endpoint, {dynamic body}) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}$endpoint');
    return _makeRequest(() => http.put(
      uri,
      headers: _headers(),
      body: body != null ? json.encode(body) : null,
    ));
  }

  static Future<dynamic> patch(String endpoint, {dynamic body}) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}$endpoint');
    return _makeRequest(() => http.patch(
      uri,
      headers: _headers(),
      body: body != null ? json.encode(body) : null,
    ));
  }

  static Future<dynamic> delete(String endpoint) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}$endpoint');
    return _makeRequest(() => http.delete(uri, headers: _headers()));
  }

  // ─── Service bookings ─────────────────────────────────────────────────

  /// Price quote for a service at an optional destination. Public.
  static Future<Map<String, dynamic>> fetchQuote(
    String slug, {
    double? latitude,
    double? longitude,
  }) async {
    final response = await get('/services/$slug/quote', queryParams: {
      if (latitude != null) 'latitude': latitude.toString(),
      if (longitude != null) 'longitude': longitude.toString(),
    });
    return Map<String, dynamic>.from((response as Map)['data'] as Map);
  }

  /// Availability for every date in a range keyed by `YYYY-MM-DD`. Auth required.
  static Future<Map<String, Map<String, dynamic>>> fetchAvailabilityRange({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final response = await get('/bookings/availability', queryParams: {
      if (startDate != null) 'start_date': _dateStr(startDate),
      if (endDate != null) 'end_date': _dateStr(endDate),
    });
    final data = Map<String, dynamic>.from((response as Map)['data'] as Map);
    final dates = data['dates'] is Map
        ? Map<String, dynamic>.from(data['dates'] as Map)
        : <String, dynamic>{};
    return dates.map((key, value) =>
        MapEntry(key, Map<String, dynamic>.from(value as Map)));
  }

  /// Create a service booking. Auth required. Returns the persisted booking map.
  static Future<Map<String, dynamic>> createServiceBooking({
    required String slug,
    required DateTime bookingDate,
    required String timeSlot,
    double? latitude,
    double? longitude,
    String? address,
    String? notes,
    String? orchardDetails,
  }) async {
    final response = await post('/services/$slug/book', body: {
      'booking_date': _dateStr(bookingDate),
      'booking_time': timeSlot,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (address != null && address.isNotEmpty) 'address': address,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
      if (orchardDetails != null && orchardDetails.isNotEmpty)
        'orchard_details': orchardDetails,
    });
    final body = Map<String, dynamic>.from(response as Map);
    return Map<String, dynamic>.from(body['data'] as Map);
  }

  /// List the authenticated user's bookings.
  static Future<List<ServiceBookingModel>> fetchMyBookings() async {
    final response = await get('/bookings');
    final body = Map<String, dynamic>.from(response as Map);
    final data = body['data'] is Map
        ? Map<String, dynamic>.from(body['data'] as Map)
        : body;

    final list = (data['data'] is List)
        ? (data['data'] as List)
        : (data['bookings'] is List ? data['bookings'] as List : <dynamic>[]);

    return list
        .map((item) => ServiceBookingModel.fromJson(
            Map<String, dynamic>.from(item as Map)))
        .toList();
  }

  /// Create a Razorpay order for a booking. Auth required.
  static Future<Map<String, dynamic>> createBookingPayment(int bookingId) async {
    final response = await post('/bookings/$bookingId/payment/create', body: {});
    final body = Map<String, dynamic>.from(response as Map);
    return Map<String, dynamic>.from(body['data'] as Map);
  }

  /// Verify a completed Razorpay payment for a booking. Auth required.
  static Future<Map<String, dynamic>> verifyBookingPayment(
    int bookingId, {
    required String razorpayOrderId,
    required String razorpayPaymentId,
    required String razorpaySignature,
  }) async {
    final response = await post('/bookings/$bookingId/payment/verify', body: {
      'razorpay_order_id': razorpayOrderId,
      'razorpay_payment_id': razorpayPaymentId,
      'razorpay_signature': razorpaySignature,
    });
    return Map<String, dynamic>.from(response as Map);
  }

  /// Resolve a text address to coordinates. Public.
  static Future<Map<String, dynamic>> geocodeAddress(String address) async {
    final response = await get('/geocode', queryParams: {'address': address});
    return Map<String, dynamic>.from((response as Map)['data'] as Map);
  }

  /// Resolve coordinates to a human readable address. Public.
  static Future<Map<String, dynamic>> reverseGeocode(
      double latitude, double longitude) async {
    final response = await get('/geocode/reverse', queryParams: {
      'latitude': latitude.toString(),
      'longitude': longitude.toString(),
    });
    return Map<String, dynamic>.from((response as Map)['data'] as Map);
  }

  static String _dateStr(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}

class ApiException implements Exception {
  final int statusCode;
  final String message;

  ApiException({required this.statusCode, required this.message});

  bool get isNetworkError => statusCode == 0;
  bool get isUnauthorized => statusCode == 401;

  @override
  String toString() => message;
}
