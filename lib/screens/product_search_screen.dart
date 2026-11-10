import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import '../providers/product_provider.dart';
import '../widgets/product_card.dart';
import 'product_detail_screen.dart';

class ProductSearchScreen extends StatefulWidget {
  const ProductSearchScreen({super.key});

  @override
  State<ProductSearchScreen> createState() => _ProductSearchScreenState();
}

class _ProductSearchScreenState extends State<ProductSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  String _currentSearch = '';
  String _selectedSort = 'newest';
  int? _selectedCategoryId;
  int? _selectedBrandId;

  static const Map<String, String> _sortOptions = {
    'newest': 'Newest',
    'price_asc': 'Price: Low to High',
    'price_desc': 'Price: High to Low',
    'name': 'Name',
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final pp = context.read<ProductProvider>();
      pp.fetchCategories();
      pp.fetchBrands();
      _fetchProducts();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      setState(() => _currentSearch = query.trim());
      _fetchProducts();
    });
  }

  void _fetchProducts() {
    final provider = context.read<ProductProvider>();
    provider.fetchCatalog(
      search: _currentSearch.isNotEmpty ? _currentSearch : null,
      categoryId: _selectedCategoryId,
      brandId: _selectedBrandId,
      sortBy: _selectedSort,
      page: 1,
    );
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Search Products'),
      ),
      body: Column(
        children: [
          _buildSearchBar(primary),
          _buildFilters(),
          Expanded(
            child: Consumer<ProductProvider>(
              builder: (context, provider, child) {
                if (provider.catalogLoading && provider.catalogProducts.isEmpty) {
                  return _buildShimmer();
                }

                if (!provider.catalogLoading && provider.catalogProducts.isEmpty) {
                  return _buildEmpty();
                }

                return RefreshIndicator(
                  color: primary,
                  onRefresh: () async {
                    _fetchProducts();
                  },
                  child: NotificationListener<ScrollNotification>(
                    onNotification: (notification) {
                      if (notification is ScrollEndNotification &&
                          notification.metrics.pixels >=
                              notification.metrics.maxScrollExtent - 200) {
                        provider.loadMoreCatalog(
                          search: _currentSearch.isNotEmpty
                              ? _currentSearch
                              : null,
                          categoryId: _selectedCategoryId,
                          brandId: _selectedBrandId,
                          sortBy: _selectedSort,
                        );
                      }
                      return false;
                    },
                    child: GridView.builder(
                      padding: const EdgeInsets.all(12),
                      gridDelegate: responsiveProductGridDelegate(),
                      itemCount: provider.catalogProducts.length,
                      itemBuilder: (context, index) {
                        final product = provider.catalogProducts[index];
                        return ProductCard(
                          product: product,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) =>
                                    ProductDetailScreen(product: product)),
                          ),
                        );
                      },
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(Color primary) {
    return Container(
      padding: const EdgeInsets.all(12),
      color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
      child: TextField(
        controller: _searchController,
        onChanged: _onSearchChanged,
        decoration: InputDecoration(
          hintText: 'Search products...',
          prefixIcon: Icon(Icons.search, color: primary),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, color: Colors.grey),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _currentSearch = '');
                    _fetchProducts();
                  },
                )
              : null,
          filled: true,
          fillColor: Colors.white,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: primary),
          ),
        ),
      ),
    );
  }

  Widget _buildFilters() {
    final categories = context.watch<ProductProvider>().categories;
    final brands = context.watch<ProductProvider>().brands;
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: _selectedSort,
                      hint: const Text('Sort By'),
                      items: _sortOptions.entries
                          .map(
                            (e) => DropdownMenuItem(
                              value: e.key,
                              child: Text(e.value, style: const TextStyle(fontSize: 13)),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _selectedSort = value);
                          _fetchProducts();
                        }
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int?>(
                      isExpanded: true,
                      value: _selectedCategoryId,
                      hint: const Text('Category'),
                      items: [
                        const DropdownMenuItem<int?>(
                          value: null,
                          child: Text('All Categories', style: TextStyle(fontSize: 13)),
                        ),
                        ...categories.map(
                          (cat) => DropdownMenuItem<int?>(
                            value: cat.id,
                            child: Text(cat.name, style: const TextStyle(fontSize: 13)),
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() => _selectedCategoryId = value);
                        _fetchProducts();
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (brands.isNotEmpty)
          Container(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int?>(
                        isExpanded: true,
                        value: _selectedBrandId,
                        hint: const Text('Brand'),
                        items: [
                          const DropdownMenuItem<int?>(
                            value: null,
                            child: Text('All Brands', style: TextStyle(fontSize: 13)),
                          ),
                          ...brands.map(
                            (b) => DropdownMenuItem<int?>(
                              value: b.id,
                              child: Text(b.name, style: const TextStyle(fontSize: 13)),
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() => _selectedBrandId = value);
                          _fetchProducts();
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildShimmer() {
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: responsiveProductGridDelegate(),
      itemCount: 6,
      itemBuilder: (context, index) {
        return Shimmer.fromColors(
          baseColor: Colors.grey[300]!,
          highlightColor: Colors.grey[100]!,
          child: Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 14,
                        width: double.infinity,
                        color: Colors.white,
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 14,
                        width: 80,
                        color: Colors.white,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          const Text(
            'No products found',
            style: TextStyle(fontSize: 18, color: Colors.grey, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          const Text(
            'Try a different search or filter',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
