import 'package:flutter/foundation.dart';
import '../models/product.dart';
import '../services/api_service.dart';
import '../services/user_activity_service.dart';

class PersonalizationProvider extends ChangeNotifier {
  List<Product> _recentlyViewed = [];
  List<Product> _recommendedProducts = [];
  List<Product> _buyAgainProducts = [];
  List<Product> _wishlistPicks = [];
  List<Product> _seasonalProducts = [];

  bool _isEnabled = true;
  bool _isLoading = false;
  String? _errorMessage;

  List<Product> get recentlyViewed => _recentlyViewed;
  List<Product> get recommendedProducts => _recommendedProducts;
  List<Product> get buyAgainProducts => _buyAgainProducts;
  List<Product> get wishlistPicks => _wishlistPicks;
  List<Product> get seasonalProducts => _seasonalProducts;

  bool get isEnabled => _isEnabled;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  PersonalizationProvider() {
    _loadLocalCache();
  }

  Future<void> _loadLocalCache() async {
    try {
      final cached = await UserActivityService.getLocalRecentProducts();
      if (cached.isNotEmpty) {
        _recentlyViewed = cached;
        notifyListeners();
      }
    } catch (_) {}
  }

  /// Log a viewed product both locally and to the backend
  Future<void> logProductView(Product product) async {
    // Optimistically update in-memory list
    _recentlyViewed.removeWhere((p) => p.id == product.id);
    _recentlyViewed.insert(0, product);
    if (_recentlyViewed.length > 20) {
      _recentlyViewed.removeRange(20, _recentlyViewed.length);
    }
    notifyListeners();

    // Persist locally and sync
    await UserActivityService.recordProductView(product);
  }

  /// Clear recently viewed history
  Future<void> clearRecentlyViewed() async {
    _recentlyViewed.clear();
    notifyListeners();
    await UserActivityService.clearLocalHistory();
  }

  void reset() {
    _recentlyViewed = [];
    _buyAgainProducts = [];
    _wishlistPicks = [];
    _errorMessage = null;
    notifyListeners();
  }

  /// Fetch the server-computed personalized feed bundle
  Future<void> fetchPersonalizedFeed({bool force = false}) async {
    if (_isLoading && !force) return;
    _isLoading = true;
    _errorMessage = null;

    try {
      final sessionId = await UserActivityService.getSessionId();
      final res = await ApiService.get('/home/personalized?session_id=$sessionId');

      if (res['success'] == true && res['data'] != null) {
        final data = res['data'] as Map<String, dynamic>;
        _isEnabled = data['enabled'] ?? true;

        final sections = (data['sections'] as List<dynamic>?) ?? [];

        for (final sec in sections) {
          if (sec is! Map) continue;
          final type = sec['type']?.toString();
          final rawProducts = (sec['products'] as List<dynamic>?) ?? [];
          final products = rawProducts
              .whereType<Map<String, dynamic>>()
              .map((e) => Product.fromJson(e))
              .toList();

          switch (type) {
            case 'recently_viewed':
              if (products.isNotEmpty) _recentlyViewed = products;
              break;
            case 'recommended':
              _recommendedProducts = products;
              break;
            case 'buy_again':
              _buyAgainProducts = products;
              break;
            case 'wishlist_picks':
              _wishlistPicks = products;
              break;
            case 'seasonal_orchard':
              _seasonalProducts = products;
              break;
          }
        }
      }
    } catch (e) {
      _errorMessage = e.toString();
      if (kDebugMode) debugPrint('PersonalizationProvider.fetchPersonalizedFeed error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
