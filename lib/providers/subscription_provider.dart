import 'package:flutter/foundation.dart';
import '../models/subscription_plan.dart';
import '../models/paid_content.dart';
import '../services/api_service.dart';

class SubscriptionProvider extends ChangeNotifier {
  List<SubscriptionPlan> _plans = [];
  List<PaidContent> _paidContents = [];
  Map<String, dynamic>? _currentSubscription;
  Map<String, dynamic>? _lastSubscription;
  bool _isLoading = false;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;
  void clearError() { _errorMessage = null; notifyListeners(); }

  List<SubscriptionPlan> get plans => _plans;
  List<PaidContent> get paidContents => _paidContents;
  Map<String, dynamic>? get currentSubscription => _currentSubscription;
  Map<String, dynamic>? get lastSubscription => _lastSubscription;
  bool get isLoading => _isLoading;

  Future<void> loadPlans() async {
    _errorMessage = null;
    _isLoading = true;
    notifyListeners();
    try {
      final response = await ApiService.get('/subscription-plans');
      final data = response['data'] as List? ?? [];
      _plans = data.map((e) => SubscriptionPlan.fromJson(e)).toList();
    } catch (e) {
      _errorMessage = e is ApiException ? e.message : 'Could not load data. Please try again.';
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadMySubscription() async {
    _errorMessage = null;
    notifyListeners();
    try {
      final response = await ApiService.get('/subscriptions');
      final data = response['data'] as Map<String, dynamic>?;
      _currentSubscription = data?['current'];
      _lastSubscription = data?['latest'];
    } catch (e) {
      _errorMessage = e is ApiException ? e.message : 'Could not load data. Please try again.';
    }
    notifyListeners();
  }

  Future<void> loadPaidContents() async {
    _errorMessage = null;
    _isLoading = true;
    notifyListeners();
    try {
      final response = await ApiService.get('/paid-contents');
      final data = response['data'] as List? ?? [];
      _paidContents = data.map((e) => PaidContent.fromJson(e)).toList();
    } catch (e) {
      _errorMessage = e is ApiException ? e.message : 'Could not load data. Please try again.';
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<bool> subscribe(int planId, {String paymentMethod = 'razorpay'}) async {
    try {
      await ApiService.post('/subscriptions', body: {
        'plan_id': planId,
        'payment_method': paymentMethod,
      });
      await loadMySubscription();
      return true;
    } catch (e) {
      _errorMessage = e is ApiException ? e.message : 'Could not load data. Please try again.';
      return false;
    }
  }

  /// Cancels a subscription. Returns the server message on success, or null on failure.
  Future<String?> cancelSubscription(int subscriptionId, {String? reason}) async {
    try {
      final response = await ApiService.post('/subscriptions/$subscriptionId/cancel', body: {
        'reason': reason ?? '',
      });
      await loadMySubscription();
      return (response['message'] as String?) ?? 'Subscription cancelled successfully.';
    } catch (e) {
      _errorMessage = e is ApiException ? e.message : 'Could not cancel subscription. Please try again.';
      return null;
    }
  }
}
