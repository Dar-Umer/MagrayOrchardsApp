import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';
import '../models/service_booking.dart';
import '../models/service_model.dart';

class ApiService {
  static const String _tokenKey = 'auth_token';
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  static final http.Client _client = http.Client();

  static String? _token;
  static VoidCallback? _onUnauthorized;

  static void setOnUnauthorized(voidCallback) {
    _onUnauthorized = voidCallback;
  }

  static bool get _isFlutterTest {
    try {
      return !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');
    } catch (_) {
      return false;
    }
  }

  static http.Client get _httpClient => _isFlutterTest ? http.Client() : _client;

  static Future<void> loadToken() async {
    if (!_isFlutterTest) {
      try {
        final secureToken = await _secureStorage.read(key: _tokenKey);
        if (secureToken != null && secureToken.isNotEmpty) {
          _token = secureToken;
          return;
        }
        // Migrate legacy token out of plaintext SharedPreferences if present.
        final prefs = await SharedPreferences.getInstance();
        final legacyToken = prefs.getString(_tokenKey);
        if (legacyToken != null && legacyToken.isNotEmpty) {
          _token = legacyToken;
          await _secureStorage.write(key: _tokenKey, value: legacyToken);
          await prefs.remove(_tokenKey);
          return;
        }
        _token = null;
        return;
      } catch (_) {
        // Fallback when secure storage channel is unavailable.
      }
    }
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(_tokenKey);
  }

  static Future<void> setToken(String? token) async {
    _token = token;
    if (!_isFlutterTest) {
      try {
        if (token != null && token.isNotEmpty) {
          await _secureStorage.write(key: _tokenKey, value: token);
        } else {
          await _secureStorage.delete(key: _tokenKey);
        }
        final prefs = await SharedPreferences.getInstance();
        if (prefs.containsKey(_tokenKey)) {
          await prefs.remove(_tokenKey);
        }
        return;
      } catch (_) {}
    }
    final prefs = await SharedPreferences.getInstance();
    if (token != null && token.isNotEmpty) {
      await prefs.setString(_tokenKey, token);
    } else {
      await prefs.remove(_tokenKey);
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
      // Prefer specific field errors (e.g. "The email has already been taken.")
      if (body['errors'] is Map) {
        final errors = body['errors'] as Map;
        final first = errors.values.first;
        if (first is List && first.isNotEmpty) {
          return first.first.toString();
        }
      }
      if (body['message'] is String && (body['message'] as String).isNotEmpty) {
        return body['message'] as String;
      }
    }
    return fallback;
  }

  static dynamic _tryDecodeJson(String body) {
    if (body.isEmpty) return null;
    try {
      return json.decode(body);
    } on FormatException {
      return null;
    }
  }

  static dynamic _handleResponse(http.Response response) {
    final decoded = _tryDecodeJson(response.body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded;
    }

    if (response.statusCode == 401) {
      _onUnauthorized?.call();
      final message = _extractMessage(
        decoded,
        'Your session has expired. Please log in again.',
      );
      throw ApiException(
        statusCode: 401,
        message: message.isNotEmpty
            ? message
            : 'Your session has expired. Please log in again.',
      );
    }

    if (response.statusCode == 429) {
      final retryAfter = response.headers['retry-after'];
      final fallback = (retryAfter != null && retryAfter.isNotEmpty)
          ? 'Too many requests. Please wait ${retryAfter}s and try again.'
          : _defaultMessage(429);
      throw ApiException(
        statusCode: 429,
        message: _extractMessage(decoded, fallback),
      );
    }

    final message = _extractMessage(decoded, _defaultMessage(response.statusCode));

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
      if (kDebugMode) debugPrint('ApiService: SocketException');
      throw ApiException(
        statusCode: 0,
        message: 'No internet connection. Please check your network and try again.',
      );
    } on TimeoutException {
      if (kDebugMode) debugPrint('ApiService: TimeoutException');
      throw ApiException(
        statusCode: 0,
        message: 'Request timed out. Please try again.',
      );
    } on HandshakeException {
      if (kDebugMode) debugPrint('ApiService: HandshakeException');
      throw ApiException(
        statusCode: 0,
        message: 'Secure connection failed. Please try again.',
      );
    } on http.ClientException {
      if (kDebugMode) debugPrint('ApiService: ClientException');
      throw ApiException(
        statusCode: 0,
        message: 'Could not connect to the server. Please try again.',
      );
    } catch (e, s) {
      if (kDebugMode) {
        debugPrint('ApiService._makeRequest unexpected error: $e\n$s');
      }
      rethrow;
    }
  }

  static Future<dynamic> get(String endpoint, {Map<String, String>? queryParams}) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}$endpoint')
        .replace(queryParameters: queryParams);
    return _makeRequest(() => _httpClient.get(uri, headers: _headers()));
  }

  static Future<dynamic> post(String endpoint, {dynamic body}) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}$endpoint');
    return _makeRequest(() => _httpClient.post(
      uri,
      headers: _headers(),
      body: body != null ? json.encode(body) : null,
    ));
  }

  static Future<dynamic> put(String endpoint, {dynamic body}) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}$endpoint');
    return _makeRequest(() => _httpClient.put(
      uri,
      headers: _headers(),
      body: body != null ? json.encode(body) : null,
    ));
  }

  static Future<dynamic> patch(String endpoint, {dynamic body}) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}$endpoint');
    return _makeRequest(() => _httpClient.patch(
      uri,
      headers: _headers(),
      body: body != null ? json.encode(body) : null,
    ));
  }

  static Future<dynamic> delete(String endpoint) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}$endpoint');
    return _makeRequest(() => _httpClient.delete(uri, headers: _headers()));
  }

  static Future<dynamic> uploadMultipart(
    String endpoint, {
    required String fieldName,
    required Uint8List bytes,
    required String filename,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}$endpoint');
    return _makeRequest(() async {
      final request = http.MultipartRequest('POST', uri);
      request.headers['Accept'] = 'application/json';
      if (_token != null) {
        request.headers['Authorization'] = 'Bearer $_token';
      }
      request.files.add(
        http.MultipartFile.fromBytes(fieldName, bytes, filename: filename),
      );
      final streamed = await _httpClient.send(request);
      return http.Response.fromStream(streamed);
    });
  }

  // ─── Service bookings ─────────────────────────────────────────────────

  /// Fetch complete service detail including active tier rates, plant types, and age groups.
  static Future<ServiceModel> fetchServiceDetail(String slug) async {
    final response = await get('/services/$slug');
    final data = Map<String, dynamic>.from((response as Map)['data'] as Map);
    return ServiceModel.fromJson(data);
  }

  /// Price quote for a service at an optional destination, quantity or itemized tree breakdown. Public.
  static Future<Map<String, dynamic>> fetchQuote(
    String slug, {
    double? latitude,
    double? longitude,
    int? quantity,
    List<Map<String, dynamic>>? treeItems,
  }) async {
    final response = await get('/services/$slug/quote', queryParams: {
      if (latitude != null) 'latitude': latitude.toString(),
      if (longitude != null) 'longitude': longitude.toString(),
      if (quantity != null) 'quantity': quantity.toString(),
      if (treeItems != null && treeItems.isNotEmpty)
        'tree_items': jsonEncode(treeItems),
    });
    return Map<String, dynamic>.from((response as Map)['data'] as Map);
  }

  /// Availability for every date in a range keyed by `YYYY-MM-DD`. Auth required.
  static Future<Map<String, Map<String, dynamic>>> fetchAvailabilityRange({
    DateTime? startDate,
    DateTime? endDate,
    int? serviceId,
    String? serviceSlug,
    double? latitude,
    double? longitude,
  }) async {
    final response = await get('/bookings/availability', queryParams: {
      if (startDate != null) 'start_date': _dateStr(startDate),
      if (endDate != null) 'end_date': _dateStr(endDate),
      if (serviceId != null) 'service_id': serviceId.toString(),
      if (serviceSlug != null && serviceSlug.isNotEmpty)
        'service_slug': serviceSlug,
      if (latitude != null) 'latitude': latitude.toString(),
      if (longitude != null) 'longitude': longitude.toString(),
    });
    final data = Map<String, dynamic>.from((response as Map)['data'] as Map);
    final dates = data['dates'] is Map
        ? Map<String, dynamic>.from(data['dates'] as Map)
        : <String, dynamic>{};
    return dates.map((key, value) =>
        MapEntry(key, Map<String, dynamic>.from(value as Map)));
  }

  /// Check slot capacity and availability for a single date.
  static Future<Map<String, dynamic>> fetchDateAvailability(
    DateTime date, {
    int? serviceId,
    String? serviceSlug,
    double? latitude,
    double? longitude,
  }) async {
    final response = await get('/bookings/availability', queryParams: {
      'date': _dateStr(date),
      if (serviceId != null) 'service_id': serviceId.toString(),
      if (serviceSlug != null && serviceSlug.isNotEmpty)
        'service_slug': serviceSlug,
      if (latitude != null) 'latitude': latitude.toString(),
      if (longitude != null) 'longitude': longitude.toString(),
    });
    return Map<String, dynamic>.from((response as Map)['data'] as Map);
  }

  /// Create a service booking. Auth required. Returns the persisted booking map.
  static Future<Map<String, dynamic>> createServiceBooking({
    required String slug,
    required DateTime bookingDate,
    String? timeSlot,
    double? latitude,
    double? longitude,
    String? address,
    String? notes,
    String? orchardDetails,
    int? quantity,
    List<Map<String, dynamic>>? treeItems,
    String paymentMethod = 'visit',
  }) async {
    final response = await post('/services/$slug/book', body: {
      'booking_date': _dateStr(bookingDate),
      'booking_time': timeSlot ?? 'full_day',
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (address != null && address.isNotEmpty) 'address': address,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
      if (orchardDetails != null && orchardDetails.isNotEmpty)
        'orchard_details': orchardDetails,
      if (quantity != null && quantity > 0) 'quantity': quantity,
      if (treeItems != null && treeItems.isNotEmpty)
        'tree_items': treeItems,
      'payment_method': paymentMethod,
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

  /// Fetch a single booking by ID. Auth required.
  static Future<ServiceBookingModel> fetchBookingDetail(int bookingId) async {
    final response = await get('/bookings/$bookingId');
    final body = Map<String, dynamic>.from(response as Map);
    final data = Map<String, dynamic>.from(body['data'] as Map);
    return ServiceBookingModel.fromJson(data);
  }

  /// Cancel a pending unpaid booking. Auth required.
  static Future<ServiceBookingModel> cancelBooking(int bookingId) async {
    final response = await patch('/bookings/$bookingId/cancel', body: {});
    final body = Map<String, dynamic>.from(response as Map);
    final data = Map<String, dynamic>.from(body['data'] as Map);
    return ServiceBookingModel.fromJson(data);
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

  /// Fetch active brands. Public.
  static Future<List<dynamic>> fetchBrands() async {
    final response = await get('/brands');
    return ((response as Map)['data'] as List?) ?? [];
  }

  /// Get a shipping estimate for a pincode. Auth required.
  static Future<Map<String, dynamic>> fetchShippingRate({
    required String pincode,
    required List<Map<String, dynamic>> items,
    double subtotal = 0,
  }) async {
    final response = await post('/shipping-rate', body: {
      'pincode': pincode,
      'items': items,
      'subtotal': subtotal,
    });
    return Map<String, dynamic>.from(response['data'] ?? response);
  }

  /// Look up city/state details for a pincode. Public.
  static Future<Map<String, dynamic>> fetchPincodeDetails(String pincode) async {
    final response = await get('/pincodes/$pincode/check');
    return Map<String, dynamic>.from(response['data'] ?? response);
  }

  // ─── Push notifications ────────────────────────────────────────────────

  /// Register (or refresh) the FCM device token. Auth required.
  static Future<void> registerDeviceToken(String token, {String deviceType = 'android'}) async {
    await post('/notifications/device-token', body: {
      'token': token,
      'device_type': deviceType,
    });
  }

  /// Unregister the FCM device token (e.g. on logout). Auth required.
  static Future<void> unregisterDeviceToken(String token) async {
    await delete('/notifications/device-token?token=${Uri.encodeComponent(token)}');
  }

  /// The user's notification inbox. Auth required.
  static Future<List<dynamic>> fetchNotifications({int page = 1, int perPage = 15}) async {
    final response = await get('/notifications', queryParams: {
      'page': page.toString(),
      'per_page': perPage.toString(),
    });
    final body = response is Map ? response['data'] : response;
    final items = body is Map && body['data'] is List ? body['data'] : <dynamic>[];
    return items;
  }

  /// Unread notification count. Auth required.
  static Future<int> fetchUnreadCount() async {
    final response = await get('/notifications/unread-count');
    final data = response is Map && response['data'] is Map
        ? (response['data'] as Map)['unread_count']
        : null;
    return (data is num) ? data.toInt() : 0;
  }

  /// Mark a single notification as read. Auth required.
  static Future<void> markNotificationRead(int id) async {
    await post('/notifications/$id/read');
  }

  /// Mark all notifications as read. Auth required.
  static Future<void> markAllNotificationsRead() async {
    await post('/notifications/read-all');
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
