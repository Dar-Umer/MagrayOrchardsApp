import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/product.dart';
import '../models/product_variant.dart';
import '../services/api_service.dart';

class CartItem {
  final Product product;
  final ProductVariant? variant;
  int quantity;
  String? serverId;

  CartItem({
    required this.product,
    this.variant,
    this.quantity = 1,
    this.serverId,
  });

  double get unitPrice => variant?.price ?? product.price;
}

class CartProvider extends ChangeNotifier {
  final List<CartItem> _items = [];

  static const String _storageKey = 'local_cart_v1';

  List<CartItem> get items => _items;
  int get itemCount => _items.fold(0, (sum, item) => sum + item.quantity);
  double get total =>
      _items.fold(0, (sum, item) => sum + item.unitPrice * item.quantity);

  double get mrpSavings => _items.fold(0, (sum, item) {
    final compare = item.variant?.comparePrice ?? item.product.comparePrice;
    if (compare != null && compare > item.unitPrice) {
      return sum + (compare - item.unitPrice) * item.quantity;
    }
    return sum;
  });

  bool get isLoggedIn => ApiService.token != null;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;
  void clearError() { _errorMessage = null; notifyListeners(); }

  int _findIndex(int productId, int? variantId) {
    if (variantId == null) {
      return _items.indexWhere((item) => item.product.id == productId && item.variant == null);
    }
    return _items.indexWhere((item) => item.product.id == productId && item.variant?.id == variantId);
  }

  Future<void> addItem(Product product, {int quantity = 1, ProductVariant? variant}) async {
    final existingIndex = _findIndex(product.id, variant?.id);
    if (existingIndex >= 0) {
      _items[existingIndex].quantity += quantity;
    } else {
      _items.add(CartItem(product: product, variant: variant, quantity: quantity));
    }
    _persistLocal();
    notifyListeners();
    if (isLoggedIn) await _syncAddToServer(product.id, quantity, variantId: variant?.id);
  }

  void removeItem(int productId, {int? variantId}) {
    final idx = variantId != null
        ? _findIndex(productId, variantId)
        : _items.indexWhere((item) => item.product.id == productId);
    if (idx < 0) return;
    final item = _items[idx];
    if (isLoggedIn && item.serverId != null) {
      _syncRemoveFromServer(item.serverId!);
    }
    _items.removeAt(idx);
    _persistLocal();
    notifyListeners();
  }

  void updateQuantity(int productId, int quantity, {int? variantId}) {
    final index = variantId != null
        ? _findIndex(productId, variantId)
        : _items.indexWhere((item) => item.product.id == productId);
    if (index >= 0) {
      if (quantity <= 0) {
        removeItem(productId, variantId: variantId);
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
    final serverIds = _items
        .map((item) => item.serverId)
        .whereType<String>()
        .toList();
    _items.clear();
    _persistLocal();
    notifyListeners();
    if (isLoggedIn) {
      for (final serverId in serverIds) {
        try {
          await ApiService.delete('/cart/$serverId');
        } catch (_) {}
      }
    }
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
        final variantData = entry['variant'];
        final quantity = entry['quantity'] ?? 1;
        final serverId = entry['server_id'];
        if (productData is Map) {
          restored.add(CartItem(
            product: Product.fromJson(Map<String, dynamic>.from(productData)),
            variant: variantData is Map
                ? ProductVariant.fromJson(Map<String, dynamic>.from(variantData))
                : null,
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
                if (item.variant != null) 'variant': item.variant!.toJson(),
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

  static List<Map<String, dynamic>> itemsToOrderPayload(List<CartItem> items) {
    return items
        .map((item) => {
              'product_id': item.product.id,
              if (item.variant != null) 'variant_id': item.variant!.id,
              'quantity': item.quantity,
            })
        .toList();
  }

  List<Map<String, dynamic>> toOrderItems() => itemsToOrderPayload(_items);

  Future<void> syncWithServer() async {
    if (!isLoggedIn) return;
    try {
      final response = await ApiService.get('/cart');
      final data = response['data'];
      if (data is List && data.isNotEmpty) {
        _items.clear();
        for (final item in data) {
          final productData = item['product'];
          final variantData = item['variant'];
          if (productData != null) {
            _items.add(CartItem(
              product: Product.fromJson(productData),
              variant: variantData is Map
                  ? ProductVariant.fromJson(Map<String, dynamic>.from(variantData))
                  : null,
              quantity: item['quantity'] ?? 1,
              serverId: item['id'],
            ));
          }
        }
        _persistLocal();
        notifyListeners();
      }
    } catch (e) {
      _errorMessage = e is ApiException ? e.message : 'Could not sync cart with server.';
    }
  }

  Future<void> _syncAddToServer(int productId, int quantity, {int? variantId}) async {
    try {
      await ApiService.post('/cart', body: {
        'product_id': productId,
        if (variantId != null) 'variant_id': variantId,
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
