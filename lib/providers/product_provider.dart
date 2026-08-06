import 'package:flutter/material.dart';
import '../models/product.dart';
import '../models/category.dart';
import '../models/service_model.dart';
import '../models/banner.dart';
import '../services/api_service.dart';

class ProductProvider extends ChangeNotifier {
  List<Product> _products = [];
  List<Product> _featuredProducts = [];
  List<Product> _categoryProducts = [];
  List<Product> _searchProducts = [];
  List<Category> _categories = [];
  List<ServiceModel> _services = [];
  List<AppBanner> _banners = [];
  bool _isLoading = false;
  int _currentPage = 1;
  bool _hasMore = true;

  bool _featuredLoading = false;
  bool _categoryLoading = false;
  bool _searchLoading = false;

  List<Product> get products => _products;
  List<Product> get featuredProducts => _featuredProducts;
  List<Product> get categoryProducts => _categoryProducts;
  List<Product> get searchProducts => _searchProducts;
  List<Category> get categories => _categories;
  List<ServiceModel> get services => _services;
  List<AppBanner> get banners => _banners;
  bool get isLoading => _isLoading;
  bool get featuredLoading => _featuredLoading;
  bool get categoryLoading => _categoryLoading;
  bool get searchLoading => _searchLoading;
  bool get hasMore => _hasMore;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;
  void clearError() { _errorMessage = null; notifyListeners(); }

  Future<void> fetchProducts(
      {String? search,
      int? categoryId,
      bool? isFeatured,
      String? sortBy,
      int page = 1}) async {
    if (isFeatured == true) {
      _featuredLoading = true;
      notifyListeners();
    } else if (categoryId != null) {
      _categoryLoading = true;
      notifyListeners();
    } else if (search != null && search.isNotEmpty) {
      _searchLoading = true;
      notifyListeners();
    } else {
      _isLoading = true;
      notifyListeners();
    }

    try {
      final queryParams = <String, String>{};
      if (search != null && search.isNotEmpty) queryParams['search'] = search;
      if (categoryId != null) {
        queryParams['category_id'] = categoryId.toString();
      }
      if (isFeatured != null) {
        queryParams['is_featured'] = isFeatured.toString();
      }
      if (sortBy != null) queryParams['sort_by'] = sortBy;
      queryParams['page'] = page.toString();

      final response = await ApiService.get('/products', queryParams: queryParams);
      final envelope = response['data'];
      List<dynamic> items;
      if (envelope is Map && envelope.containsKey('data')) {
        items = envelope['data'] ?? [];
      } else if (envelope is List) {
        items = envelope;
      } else {
        items = [];
      }
      final loaded = items.map((p) => Product.fromJson(p)).toList();

      if (isFeatured == true) {
        _featuredProducts = loaded;
      } else if (categoryId != null) {
        _categoryProducts = loaded;
      } else if (search != null && search.isNotEmpty) {
        _searchProducts = loaded;
      } else {
        if (page == 1) {
          _products = loaded;
        } else {
          _products = [..._products, ...loaded];
        }
      }
      _currentPage = page;
      _hasMore = loaded.isNotEmpty;
    } catch (e) {
      _errorMessage = e is ApiException ? e.message : 'Could not load products. Please check your connection.';
    }

    _isLoading = false;
    _featuredLoading = false;
    _categoryLoading = false;
    _searchLoading = false;
    notifyListeners();
  }

  Future<void> loadMore(
      {String? search, int? categoryId, bool? isFeatured}) async {
    if (!_hasMore || _isLoading) return;
    await fetchProducts(
      search: search,
      categoryId: categoryId,
      isFeatured: isFeatured,
      page: _currentPage + 1,
    );
  }

  Future<Product?> fetchProductDetail(String slug) async {
    try {
      final response = await ApiService.get('/products/$slug');
      return Product.fromJson(response['data'] ?? response);
    } catch (e) {
      return null;
    }
  }

  Future<void> fetchCategories() async {
    try {
      final response = await ApiService.get('/categories');
      final data = response['data'];
      final List<dynamic> items;
      if (data is List) {
        items = data;
      } else {
        items = [];
      }
      _categories = items.map((c) => Category.fromJson(c)).toList();
      notifyListeners();
    } catch (e) {
      _errorMessage = e is ApiException ? e.message : 'Could not load categories.';
    }
  }

  Future<void> fetchServices() async {
    _isLoading = true;
    notifyListeners();
    try {
      final response = await ApiService.get('/services');
      final envelope = response['data'];
      List<dynamic> items;
      if (envelope is Map && envelope.containsKey('data')) {
        items = envelope['data'] ?? [];
      } else if (envelope is List) {
        items = envelope;
      } else {
        items = [];
      }
      _services = items.map((s) => ServiceModel.fromJson(s)).toList();
    } catch (e) {
      _errorMessage = e is ApiException ? e.message : 'Could not load services.';
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> fetchBanners() async {
    try {
      final response = await ApiService.get('/banners');
      final data = response['data'];
      if (data is List) {
        _banners = data.map((b) => AppBanner.fromJson(b)).toList();
        notifyListeners();
      }
    } catch (e) {
      _errorMessage = e is ApiException ? e.message : 'Could not load banners.';
    }
  }
}
