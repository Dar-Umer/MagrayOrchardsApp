import 'package:flutter/material.dart';
import '../models/order.dart';
import '../services/api_service.dart';

class OrderProvider extends ChangeNotifier {
  List<Order> _orders = [];
  bool _isLoading = false;
  Order? _lastCreatedOrder;
  String? _statusFilter;
  String _searchQuery = '';

  List<Order> get orders => _orders;
  bool get isLoading => _isLoading;
  Order? get lastCreatedOrder => _lastCreatedOrder;
  String? get statusFilter => _statusFilter;
  String get searchQuery => _searchQuery;

  List<Order> get filteredOrders {
    var result = _orders;
    if (_statusFilter != null) {
      result = result.where((o) => o.status == _statusFilter).toList();
    }
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      result = result.where((o) => o.orderNumber.toLowerCase().contains(q)).toList();
    }
    return result;
  }

  String? _errorMessage;
  String? get errorMessage => _errorMessage;
  void clearError() { _errorMessage = null; notifyListeners(); }

  void setStatusFilter(String? status) {
    _statusFilter = status;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  Future<Order?> createOrder({
    required int addressId,
    required String paymentMethod,
    required List<Map<String, dynamic>> items,
    String? notes,
    String? razorpayOrderId,
    String? razorpayPaymentId,
    double? walletAmountUsed,
  }) async {
    _isLoading = true;
    notifyListeners();
    try {
      final body = <String, dynamic>{
        'address_id': addressId,
        'payment_method': paymentMethod,
        'items': items,
      };
      if (notes != null) body['notes'] = notes;
      if (razorpayOrderId != null) body['razorpay_order_id'] = razorpayOrderId;
      if (razorpayPaymentId != null) {
        body['razorpay_payment_id'] = razorpayPaymentId;
      }
      if (walletAmountUsed != null) {
        body['wallet_amount_used'] = walletAmountUsed;
      }

      final response = await ApiService.post('/orders', body: body);
      final order = Order.fromJson(response['data']);
      _lastCreatedOrder = order;
      _isLoading = false;
      notifyListeners();
      return order;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> fetchOrders() async {
    _isLoading = true;
    notifyListeners();
    try {
      final response = await ApiService.get('/orders');
      final data = response['data'];
      final List<dynamic> items;
      if (data is Map && data.containsKey('data')) {
        items = data['data'] ?? [];
      } else if (data is List) {
        items = data;
      } else {
        items = [];
      }
      _orders = items.map((o) => Order.fromJson(o)).toList();
    } catch (e) {
      _errorMessage = e is ApiException ? e.message : 'Could not load your orders. Please try again.';
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<Order?> fetchOrderDetail(int id) async {
    try {
      final response = await ApiService.get('/orders/$id');
      return Order.fromJson(response['data']);
    } catch (e) {
      return null;
    }
  }
}
