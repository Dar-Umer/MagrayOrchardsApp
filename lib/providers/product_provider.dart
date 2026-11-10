import 'package:flutter/material.dart';
import '../models/product.dart';
import '../models/category.dart';
import '../models/service_model.dart';
import '../models/banner.dart';
import '../models/brand.dart';
import '../services/api_service.dart';

class ProductProvider extends ChangeNotifier {
  List<Product> _products = [];
  List<Product> _featuredProducts = [];
  List<Product> _offerProducts = [];
  List<Product> _categoryProducts = [];
  List<Product> _brandProducts = [];
  List<Product> _searchProducts = [];
  List<Product> _catalogProducts = [];
  List<Category> _categories = [];
  List<Brand> _brands = [];
  List<ServiceModel> _services = [];
  List<AppBanner> _banners = [];
  bool _isLoading = false;
  int _currentPage = 1;
  bool _hasMore = true;

  bool _featuredLoading = false;
  bool _offerLoading = false;
  bool _categoryLoading = false;
  bool _brandLoading = false;
  bool _searchLoading = false;
  bool _catalogLoading = false;

  int? _activeCategoryId;
  int _categoryPage = 1;
  bool _categoryHasMore = true;

  int? _activeBrandId;
  int _brandPage = 1;
  bool _brandHasMore = true;

  int _catalogPage = 1;
  bool _catalogHasMore = true;

  List<Product> get products => _products;
  List<Product> get featuredProducts => _featuredProducts;
  List<Product> get offerProducts => _offerProducts;
  List<Product> get categoryProducts => _categoryProducts;
  List<Product> get brandProducts => _brandProducts;
  List<Product> get searchProducts => _searchProducts;
  List<Product> get catalogProducts => _catalogProducts;
  List<Category> get categories => _categories;
  List<Brand> get brands => _brands;
  List<ServiceModel> get services => _services;
  List<AppBanner> get banners => _banners;
  bool get isLoading => _isLoading;
  bool get featuredLoading => _featuredLoading;
  bool get offerLoading => _offerLoading;
  bool get categoryLoading => _categoryLoading;
  bool get brandLoading => _brandLoading;
  bool get searchLoading => _searchLoading;
  bool get catalogLoading => _catalogLoading;
  bool get hasMore => _hasMore;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;
  void clearError() { _errorMessage = null; notifyListeners(); }

  List<Product> _extractProducts(dynamic response) {
    final envelope = response['data'];
    final List<dynamic> items;
    if (envelope is Map && envelope.containsKey('data')) {
      items = envelope['data'] ?? [];
    } else if (envelope is List) {
      items = envelope;
    } else {
      items = [];
    }
    return items.map((p) => Product.fromJson(p)).toList();
  }

  bool _parseHasMore(dynamic response, int loadedCount) {
    final envelope = response['data'];
    if (envelope is Map &&
        envelope['current_page'] is num &&
        envelope['last_page'] is num) {
      return (envelope['current_page'] as num).toInt() <
          (envelope['last_page'] as num).toInt();
    }
    return loadedCount > 0;
  }

  Future<void> fetchProducts(
      {String? search,
      int? categoryId,
      int? brandId,
      bool? isFeatured,
      String? sortBy,
      int? perPage,
      int page = 1}) async {
    if (isFeatured == true) {
      _featuredLoading = true;
      notifyListeners();
    } else if (categoryId != null) {
      if (page == 1 && _activeCategoryId != categoryId) {
        _categoryProducts = [];
      }
      _activeCategoryId = categoryId;
      _categoryLoading = true;
      notifyListeners();
    } else if (brandId != null) {
      if (page == 1 && _activeBrandId != brandId) {
        _brandProducts = [];
      }
      _activeBrandId = brandId;
      _brandLoading = true;
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
      if (brandId != null) {
        queryParams['brand_id'] = brandId.toString();
      }
      if (isFeatured != null) {
        queryParams['is_featured'] = isFeatured.toString();
      }
      if (sortBy != null) queryParams['sort_by'] = sortBy;
      if (perPage != null) queryParams['per_page'] = perPage.toString();
      queryParams['page'] = page.toString();
      if (search != null && search.isNotEmpty) {
        // Search results keep out-of-stock visible so users can see them.
      } else {
        queryParams['in_stock'] = 'true';
      }

      final response = await ApiService.get('/products', queryParams: queryParams);
      final loaded = _extractProducts(response);
      final more = _parseHasMore(response, loaded.length);

      if (isFeatured == true) {
        _featuredProducts = loaded;
      } else if (categoryId != null) {
        _categoryProducts =
            page == 1 ? loaded : [..._categoryProducts, ...loaded];
        _categoryPage = page;
        _categoryHasMore = more;
      } else if (brandId != null) {
        _brandProducts = page == 1 ? loaded : [..._brandProducts, ...loaded];
        _brandPage = page;
        _brandHasMore = more;
      } else if (search != null && search.isNotEmpty) {
        _searchProducts = page == 1 ? loaded : [..._searchProducts, ...loaded];
        _currentPage = page;
        _hasMore = more;
      } else {
        _products = page == 1 ? loaded : [..._products, ...loaded];
        _currentPage = page;
        _hasMore = more;
      }
    } catch (e) {
      debugPrint('ProductProvider.fetchProducts error: $e');
      _errorMessage = e is ApiException ? e.message : 'Could not load products. Please check your connection.';
    }

    _isLoading = false;
    _featuredLoading = false;
    _categoryLoading = false;
    _brandLoading = false;
    _searchLoading = false;
    notifyListeners();
  }

  Future<void> loadMore(
      {String? search, int? categoryId, int? brandId, bool? isFeatured}) async {
    if (categoryId != null) {
      if (!_categoryHasMore || _categoryLoading) return;
      await fetchProducts(categoryId: categoryId, page: _categoryPage + 1);
      return;
    }
    if (brandId != null) {
      if (!_brandHasMore || _brandLoading) return;
      await fetchProducts(brandId: brandId, page: _brandPage + 1);
      return;
    }
    if (!_hasMore || _isLoading) return;
    await fetchProducts(
      search: search,
      isFeatured: isFeatured,
      page: _currentPage + 1,
    );
  }

  /// Dedicated search/filter catalog feed for ProductSearchScreen so filtering
  /// never clobbers the Home screen's product carousels.
  Future<void> fetchCatalog({
    String? search,
    int? categoryId,
    int? brandId,
    String sortBy = 'newest',
    int page = 1,
  }) async {
    _catalogLoading = true;
    notifyListeners();
    try {
      final queryParams = <String, String>{
        'sort_by': sortBy,
        'page': page.toString(),
      };
      if (search != null && search.isNotEmpty) {
        queryParams['search'] = search;
      } else {
        queryParams['in_stock'] = 'true';
      }
      if (categoryId != null) queryParams['category_id'] = categoryId.toString();
      if (brandId != null) queryParams['brand_id'] = brandId.toString();

      final response = await ApiService.get('/products', queryParams: queryParams);
      final loaded = _extractProducts(response);
      _catalogProducts =
          page == 1 ? loaded : [..._catalogProducts, ...loaded];
      _catalogPage = page;
      _catalogHasMore = _parseHasMore(response, loaded.length);
    } catch (e) {
      debugPrint('ProductProvider.fetchCatalog error: $e');
      _errorMessage = e is ApiException ? e.message : 'Could not load products.';
    }
    _catalogLoading = false;
    notifyListeners();
  }

  Future<void> loadMoreCatalog({
    String? search,
    int? categoryId,
    int? brandId,
    String sortBy = 'newest',
  }) async {
    if (!_catalogHasMore || _catalogLoading) return;
    await fetchCatalog(
      search: search,
      categoryId: categoryId,
      brandId: brandId,
      sortBy: sortBy,
      page: _catalogPage + 1,
    );
  }

  Future<void> fetchOfferProducts({int? perPage}) async {
    _offerLoading = true;
    notifyListeners();
    try {
      final queryParams = <String, String>{
        'is_offer': 'true',
        'page': '1',
        'in_stock': 'true',
      };
      if (perPage != null) queryParams['per_page'] = perPage.toString();
      final response =
          await ApiService.get('/products', queryParams: queryParams);
      final envelope = response['data'];
      List<dynamic> items;
      if (envelope is Map && envelope.containsKey('data')) {
        items = envelope['data'] ?? [];
      } else if (envelope is List) {
        items = envelope;
      } else {
        items = [];
      }
      _offerProducts = items.map((p) => Product.fromJson(p)).toList();
    } catch (e) {
      debugPrint('ProductProvider.fetchOfferProducts error: $e');
      _errorMessage =
          e is ApiException ? e.message : 'Could not load offers.';
    }
    _offerLoading = false;
    notifyListeners();
  }

  /// Fetch products for a custom home section (category / brand sources).
  /// Results are stored under [key] so different sections don't clobber each
  /// other. `sortBy` uses the same allowed values as the API (`newest`,
  /// `price_asc`, `price_desc`, `name`).
  final Map<String, List<Product>> _sectionProducts = {};
  final Map<String, bool> _sectionLoading = {};

  List<Product> sectionProducts(String key) => _sectionProducts[key] ?? const [];
  bool isSectionLoading(String key) => _sectionLoading[key] ?? false;

  Future<void> fetchSectionProducts(
    String key, {
    int? categoryId,
    int? brandId,
    String? sortBy,
    int? limit,
  }) async {
    if (categoryId == null && brandId == null) return;
    _sectionLoading[key] = true;
    notifyListeners();
    try {
      final queryParams = <String, String>{
        'page': '1',
        'in_stock': 'true',
      };
      if (categoryId != null) queryParams['category_id'] = categoryId.toString();
      if (brandId != null) queryParams['brand_id'] = brandId.toString();
      if (sortBy != null && sortBy.isNotEmpty) queryParams['sort_by'] = sortBy;
      if (limit != null) queryParams['per_page'] = limit.toString();

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
      _sectionProducts[key] = items.map((p) => Product.fromJson(p)).toList();
    } catch (e) {
      debugPrint('ProductProvider.fetchSectionProducts error: $e');
      _sectionProducts[key] = [];
    }
    _sectionLoading[key] = false;
    notifyListeners();
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
      debugPrint('ProductProvider.fetchCategories error: $e');
      _errorMessage = e is ApiException ? e.message : 'Could not load categories.';
    }
  }

  Future<void> fetchBrands() async {
    try {
      final items = await ApiService.fetchBrands();
      _brands = items
          .map((b) => Brand.fromJson(b as Map<String, dynamic>))
          .toList();
      notifyListeners();
    } catch (e) {
      debugPrint('ProductProvider.fetchBrands error: $e');
      _errorMessage = e is ApiException ? e.message : 'Could not load brands.';
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
      debugPrint('ProductProvider.fetchServices error: $e');
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
