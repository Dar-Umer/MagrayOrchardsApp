import 'package:flutter/material.dart';
import '../models/product.dart';
import '../services/api_service.dart';

class WishlistItem {
  final int id;
  final Product product;

  WishlistItem({required this.id, required this.product});
}

class WishlistProvider extends ChangeNotifier {
  List<WishlistItem> _items = [];
  Set<int> _wishlistProductIds = {};
  bool _isLoading = false;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;
  void clearError() { _errorMessage = null; notifyListeners(); }

  List<WishlistItem> get items => _items;
  bool get isLoading => _isLoading;

  bool isInWishlist(int productId) => _wishlistProductIds.contains(productId);

  Future<void> fetchWishlist() async {
    _isLoading = true;
    notifyListeners();
    try {
      final response = await ApiService.get('/wishlist');
      final data = response['data'] ?? response;
      _items = (data as List).map((item) {
        return WishlistItem(
          id: item['id'] ?? 0,
          product: Product.fromJson(item['product']),
        );
      }).toList();
      _wishlistProductIds = _items.map((w) => w.product.id).toSet();
    } catch (e) {
      _errorMessage = e is ApiException ? e.message : 'Could not load wishlist.';
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<bool> toggleWishlist(int productId) async {
    try {
      final response = await ApiService.post('/wishlist/$productId');
      final isInWishlist = response['data']?['is_in_wishlist'] ?? false;
      if (isInWishlist) {
        _wishlistProductIds.add(productId);
      } else {
        _wishlistProductIds.remove(productId);
        _items.removeWhere((w) => w.product.id == productId);
      }
      notifyListeners();
      return isInWishlist;
    } catch (e) {
      _errorMessage = e is ApiException ? e.message : 'Could not load wishlist.';
      return false;
    }
  }
}
