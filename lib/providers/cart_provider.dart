import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/product.dart';
import '../services/api_service.dart';

class CartItem {
  final Product product;
  int quantity;
  String? serverId;

  CartItem({required this.product, this.quantity = 1, this.serverId});
}

class CartProvider extends ChangeNotifier {
  final List<CartItem> _items = [];

  static const String _storageKey = 'local_cart_v1';

  List<CartItem> get items => _items;
  int get itemCount => _items.fold(0, (sum, item) => sum + item.quantity);
  double get total =>
      _items.fold(0, (sum, item) => sum + item.product.price * item.quantity);

  bool get isLoggedIn => ApiService.token != null;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;
  void clearError() { _errorMessage = null; notifyListeners(); }

  void addItem(Product product, {int quantity = 1}) {
    final existingIndex =
        _items.indexWhere((item) => item.product.id == product.id);
    if (existingIndex >= 0) {
      _items[existingIndex].quantity += quantity;
    } else {
      _items.add(CartItem(product: product, quantity: quantity));
    }
    if (isLoggedIn) _syncAddToServer(product.id, quantity);
    _persistLocal();
    notifyListeners();
  }

  void removeItem(int productId) {
    final item =
        _items.firstWhere((item) => item.product.id == productId);
    if (isLoggedIn && item.serverId != null) {
      _syncRemoveFromServer(item.serverId!);
    }
    _items.removeWhere((item) => item.product.id == productId);
    _persistLocal();
    notifyListeners();
  }

  void updateQuantity(int productId, int quantity) {
    final index =
        _items.indexWhere((item) => item.product.id == productId);
    if (index >= 0) {
      if (quantity <= 0) {
        removeItem(productId);
        return;
      }
      _items[index].quantity = quantity;
      if (isLoggedIn && _items[index].serverId != null) {
        _syncUpdateOnServer(_items[index].serverId!, quantity);
      }
      _persistLocal();
      notifyListeners();
    }
  }

  Future<void> clearCart() async {
    if (isLoggedIn) {
      final serverItems =
          _items.where((item) => item.serverId != null).toList();
      for (final item in serverItems) {
        try {
          await ApiService.delete('/cart/${item.serverId}');
        } catch (_) {}
      }
    }
    _items.clear();
    _persistLocal();
    notifyListeners();
  }

  /// Restore a guest cart saved locally (survives app close / reload).
  Future<void> loadFromLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw == null || raw.isEmpty) return;
      final decoded = json.decode(raw);
      if (decoded is! List) return;
      final restored = <CartItem>[];
      for (final entry in decoded) {
        if (entry is! Map) continue;
        final productData = entry['product'];
        final quantity = entry['quantity'] ?? 1;
        final serverId = entry['server_id'];
        if (productData is Map) {
          restored.add(CartItem(
            product: Product.fromJson(Map<String, dynamic>.from(productData)),
            quantity: quantity is num ? quantity.toInt() : 1,
            serverId: serverId?.toString(),
          ));
        }
      }
      if (restored.isNotEmpty) {
        _items
          ..clear()
          ..addAll(restored);
        notifyListeners();
      }
    } catch (_) {
      // Ignore corrupt local cart data.
    }
  }

  Future<void> _persistLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = _items
          .map((item) => {
                'product': item.product.toJson(),
                'quantity': item.quantity,
                'server_id': item.serverId,
              })
          .toList();
      await prefs.setString(_storageKey, json.encode(data));
    } catch (_) {}
  }

  int getQuantity(int productId) {
    final item = _items
        .where((item) => item.product.id == productId)
        .toList();
    return item.isNotEmpty ? item.first.quantity : 0;
  }

  List<Map<String, dynamic>> toOrderItems() {
    return _items
        .map((item) => {
              'product_id': item.product.id,
              'quantity': item.quantity,
            })
        .toList();
  }

  Future<void> syncWithServer() async {
    if (!isLoggedIn) return;
    try {
      final response = await ApiService.get('/cart');
      final data = response['data'];
      if (data is List && data.isNotEmpty) {
        _items.clear();
        for (final item in data) {
          final productData = item['product'];
          if (productData != null) {
            _items.add(CartItem(
              product: Product.fromJson(productData),
              quantity: item['quantity'] ?? 1,
              serverId: item['id'],
            ));
          }
        }
        notifyListeners();
      }
    } catch (e) {
      _errorMessage = e is ApiException ? e.message : 'Could not sync cart with server.';
    }
  }

  Future<void> _syncAddToServer(int productId, int quantity) async {
    try {
      await ApiService.post('/cart', body: {
        'product_id': productId,
        'quantity': quantity,
      });
      await syncWithServer();
    } catch (e) {
      _errorMessage = e is ApiException ? e.message : 'Could not sync cart with server.';
    }
  }

  Future<void> _syncRemoveFromServer(String serverId) async {
    try {
      await ApiService.delete('/cart/$serverId');
    } catch (e) {
      // ignore
    }
  }

  Future<void> _syncUpdateOnServer(String serverId, int quantity) async {
    try {
      await ApiService.put('/cart/$serverId', body: {
        'quantity': quantity,
      });
    } catch (e) {
      // ignore
    }
  }
}
