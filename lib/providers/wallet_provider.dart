import 'package:flutter/material.dart';
import '../models/wallet.dart';
import '../services/api_service.dart';

class WalletProvider extends ChangeNotifier {
  double _balance = 0;
  List<WalletTransaction> _transactions = [];
  bool _isLoading = false;
  bool _isLoadingTransactions = false;
  String? _errorMessage;
  int _currentPage = 1;
  bool _hasMore = true;

  double get balance => _balance;
  List<WalletTransaction> get transactions => _transactions;
  bool get isLoading => _isLoading;
  bool get isLoadingTransactions => _isLoadingTransactions;
  String? get errorMessage => _errorMessage;
  bool get hasMore => _hasMore;

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> fetchBalance() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final response = await ApiService.get('/wallet');
      final data = response['data'] ?? response;
      _balance = (data['balance'] ?? 0).toDouble();
      final recent = data['recent_transactions'] as List<dynamic>? ?? [];
      _transactions = recent.map((t) => WalletTransaction.fromJson(t)).toList();
      _isLoading = false;
      notifyListeners();
    } catch (e, s) {
      _isLoading = false;
      debugPrint('WalletProvider.fetchBalance error: $e\n$s');
      _errorMessage = e is ApiException ? e.message : 'Could not load wallet balance.';
      notifyListeners();
    }
  }

  Future<void> fetchTransactions({String? type, bool append = false}) async {
    if (_isLoadingTransactions) return;
    _isLoadingTransactions = true;
    notifyListeners();
    try {
      final params = <String, String>{'per_page': '20'};
      if (type != null) params['type'] = type;
      if (append) params['page'] = (_currentPage + 1).toString();

      final response = await ApiService.get('/wallet/transactions', queryParams: params);
      final data = response['data'];
      final items = (data is Map ? data['data'] : data) as List<dynamic>? ?? [];
      final newTransactions = items.map((t) => WalletTransaction.fromJson(t)).toList();

      if (append) {
        _transactions.addAll(newTransactions);
        _currentPage++;
      } else {
        _transactions = newTransactions;
        _currentPage = 1;
      }

      _hasMore = items.length >= 20;
      _isLoadingTransactions = false;
      notifyListeners();
    } catch (e, s) {
      _isLoadingTransactions = false;
      debugPrint('WalletProvider.fetchTransactions error: $e\n$s');
      _errorMessage = e is ApiException ? e.message : 'Could not load transactions.';
      notifyListeners();
    }
  }

  Future<bool> topUp(double amount) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final response = await ApiService.post('/wallet/topup', body: {'amount': amount});
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e is ApiException ? e.message : 'Could not initiate top-up. Please try again.';
      notifyListeners();
      return false;
    }
  }

  Future<bool> verifyTopUp({
    required String razorpayOrderId,
    required String razorpayPaymentId,
    required String razorpaySignature,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final response = await ApiService.post('/wallet/topup/verify', body: {
        'razorpay_order_id': razorpayOrderId,
        'razorpay_payment_id': razorpayPaymentId,
        'razorpay_signature': razorpaySignature,
      });
      final data = response['data'] ?? response;
      _balance = (data['balance'] ?? _balance).toDouble();
      final txData = data['transaction'];
      if (txData != null) {
        _transactions.insert(0, WalletTransaction.fromJson(txData));
      }
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e is ApiException ? e.message : 'Payment could not be verified. Please check your balance.';
      notifyListeners();
      return false;
    }
  }
}
