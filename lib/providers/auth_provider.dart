import 'package:flutter/material.dart';
import '../models/user.dart';
import '../services/api_service.dart';
import '../services/push_service.dart';

class AuthProvider extends ChangeNotifier {
  User? _user;
  String? _token;
  bool _isLoading = false;
  String? _otpPhone;
  String? _otpMaskedPhone;
  String? _otpType;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;
  void clearError() { _errorMessage = null; notifyListeners(); }

  User? get user => _user;
  String? get token => _token;
  bool get isLoading => _isLoading;
  bool get isLoggedIn => _token != null && _user != null;
  bool get isPhoneVerified => _user?.phoneVerifiedAt != null;
  String? get otpPhone => _otpPhone;
  String? get otpMaskedPhone => _otpMaskedPhone;

  bool _isHandlingUnauthorized = false;

  AuthProvider() {
    ApiService.setOnUnauthorized(_handleUnauthorized);
    loadToken();
  }

  /// Clears the local session when the API reports an expired/invalid token.
  /// Does not call the logout endpoint (that would 401 again and recurse).
  Future<void> _handleUnauthorized() async {
    if (_isHandlingUnauthorized) return;
    _isHandlingUnauthorized = true;
    try {
      _user = null;
      _token = null;
      await ApiService.setToken(null);
      notifyListeners();
    } finally {
      _isHandlingUnauthorized = false;
    }
  }

  Future<void> loadToken() async {
    _isLoading = true;
    notifyListeners();
    await ApiService.loadToken();
    _token = ApiService.token;
    if (_token != null) {
      try {
        await loadProfile();
      } catch (e) {
        await logout();
      }
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> sendOtp(String phone, {String type = 'login', String? name, String? email, String? password}) async {
    _isLoading = true;
    notifyListeners();
    try {
      final body = <String, dynamic>{
        'phone': phone,
        'type': type,
      };
      if (name != null && name.isNotEmpty) body['name'] = name;
      if (email != null && email.isNotEmpty) body['email'] = email;
      if (password != null && password.isNotEmpty) body['password'] = password;
      final response = await ApiService.post('/auth/send-otp', body: body);
      _otpPhone = phone;
      _otpMaskedPhone = response['masked_phone'] ?? phone;
      _otpType = type;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> resendOtp() async {
    _isLoading = true;
    notifyListeners();
    try {
      await ApiService.post('/auth/resend-otp', body: {
        'phone': _otpPhone,
        'type': _otpType ?? 'login',
      });
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<bool> verifyOtp(String otp) async {
    _isLoading = true;
    notifyListeners();
    try {
      final response = await ApiService.post('/auth/verify-otp', body: {
        'phone': _otpPhone,
        'otp': otp,
      });
      _token = response['token'] ?? response['data']['token'];
      _user = User.fromJson(response['user'] ?? response['data']['user']);
      await ApiService.setToken(_token);
      await loadProfile();
      _registerPushToken();
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<bool> loginWithPassword(String phone, String password) async {
    _isLoading = true;
    notifyListeners();
    try {
      final response = await ApiService.post('/auth/password-login', body: {
        'phone': phone,
        'password': password,
      });
      _token = response['data']['token'];
      _user = User.fromJson(response['data']['user']);
      await ApiService.setToken(_token);
      await loadProfile();
      _registerPushToken();
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<bool> register({required String name, required String email, required String phone, required String password}) async {
    _isLoading = true;
    notifyListeners();
    try {
      final response = await ApiService.post('/register', body: {
        'name': name,
        'email': email,
        'phone': phone,
        'password': password,
        'password_confirmation': password,
      });
      _token = response['data']['token'];
      _user = User.fromJson(response['data']['user']);
      await ApiService.setToken(_token);
      await loadProfile();
      _registerPushToken();
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> forgotPassword(String phone) async {
    _isLoading = true;
    notifyListeners();
    try {
      final response = await ApiService.post('/auth/forgot-password', body: {
        'phone': phone,
      });
      _otpPhone = phone;
      _otpMaskedPhone = response['masked_phone'] ?? phone;
      _otpType = 'forgot';
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<bool> resetPassword(String otp, String newPassword) async {
    _isLoading = true;
    notifyListeners();
    try {
      final response = await ApiService.post('/auth/reset-password', body: {
        'phone': _otpPhone,
        'otp': otp,
        'password': newPassword,
      });
      _token = response['data']['token'];
      _user = User.fromJson(response['data']['user']);
      await ApiService.setToken(_token);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  void clearOtpState() {
    _otpPhone = null;
    _otpMaskedPhone = null;
    _otpType = null;
    notifyListeners();
  }

  Future<void> logout() async {
    try {
      await PushService.instance.unregisterToken();
      if (_token != null) {
        await ApiService.post('/logout');
      }
    } catch (_) {}
    _user = null;
    _token = null;
    await ApiService.setToken(null);
    notifyListeners();
  }

  Future<void> loadProfile() async {
    final response = await ApiService.get('/profile');
    final data = response['data'] ?? response;
    _user = User.fromJson(data['user'] ?? data);
    _registerPushToken();
    notifyListeners();
  }

  /// Registers the FCM token (and watcher) for the logged-in user, then
  /// refreshes the inbox unread badge.
  Future<void> _registerPushToken() async {
    await PushService.instance.registerToken(this);
    PushService.instance.watchTokenRefresh(this);
  }

  Future<bool> updateProfile({String? name, String? phone}) async {
    try {
      final body = <String, String>{};
      if (name != null) body['name'] = name;
      if (phone != null) body['phone'] = phone;
      final response = await ApiService.put('/profile', body: body);
      final data = response['data'] ?? response;
      _user = User.fromJson(data['user'] ?? data);
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e is ApiException ? e.message : 'Could not update profile. Please try again.';
      return false;
    }
  }

  /// Update the local user's default delivery address (pincode/city/state).
  void setDefaultAddress({
    String? pincode,
    String? city,
    String? state,
  }) {
    if (_user == null) return;
    _user = _user!.copyWith(
      defaultPincode: pincode,
      defaultCity: city,
      defaultState: state,
    );
    notifyListeners();
  }
}
