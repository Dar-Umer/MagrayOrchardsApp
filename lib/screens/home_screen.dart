import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/app_network_image.dart';
import '../widgets/empty_state.dart';
import '../widgets/skeleton_box.dart';
import '../providers/auth_provider.dart';
import '../providers/product_provider.dart';
import '../providers/cart_provider.dart';
import '../providers/address_provider.dart';
import '../providers/notification_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/wishlist_provider.dart';
import '../config/api_config.dart';
import '../models/product.dart';
import '../models/home_section.dart';
import '../services/shop_config.dart';
import '../utils/app_navigation.dart';
import 'login_screen.dart';
import 'product_detail_screen.dart';
import 'service_detail_screen.dart';
import 'category_products_screen.dart';
import 'brand_products_screen.dart';
import 'reels_screen.dart';
import 'product_search_screen.dart';
import 'address_form_screen.dart';
import 'subscription_screen.dart';
import 'tabs/services_tab.dart';
import 'tabs/cart_tab.dart';
import 'tabs/profile_tab.dart';
import '../widgets/product_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  // ── Inline search state ──
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;
  String _searchQuery = '';
  bool _isListening = false;
  final SpeechToText _speech = SpeechToText();

  @override
  void initState() {
    super.initState();
    AppNavigation.requestedTab.addListener(_handleExternalTabRequest);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshShopConfig(fetchSections: true);
      final pp = context.read<ProductProvider>();
      if (pp.products.isEmpty) {
        _fetchAllHomeFeeds(pp);
      }
      final auth = context.read<AuthProvider>();
      if (auth.isLoggedIn) {
        context.read<NotificationProvider>().loadUnreadCount();
        context.read<WishlistProvider>().fetchWishlist();
      }
    });
  }

  void _handleExternalTabRequest() {
    final tab = AppNavigation.requestedTab.value;
    if (tab == null || !mounted) return;
    AppNavigation.requestedTab.value = null;
    if (tab >= 0 && tab < 5) {
      setState(() => _currentIndex = tab);
      if (tab == 0) _refreshShopConfig(fetchSections: true);
    }
  }

  int _sourcePerPage(String source, [int minimum = 15]) {
    var maxItems = minimum;
    for (final section in ShopConfig.homeSections) {
      if (section.enabled &&
          section.type == 'products' &&
          section.source == source &&
          section.fetchLimit > maxItems) {
        maxItems = section.fetchLimit;
      }
    }
    return maxItems;
  }

  Future<void> _fetchAllHomeFeeds(ProductProvider pp) async {
    await Future.wait([
      pp.fetchProducts(
          isFeatured: true, page: 1, perPage: _sourcePerPage('featured')),
      pp.fetchProducts(
          sortBy: 'newest', page: 1, perPage: _sourcePerPage('newest')),
      pp.fetchCategories(),
      pp.fetchServices(),
      pp.fetchBanners(),
      pp.fetchOfferProducts(perPage: _sourcePerPage('offers')),
      pp.fetchBrands(),
    ]);
  }

  /// Re-fetch the remote shop config (home layout, theme, maintenance, versions)
  /// so admin changes appear without a full app restart. Rebuilds the sections.
  Future<void> _refreshShopConfig({bool fetchSections = false}) async {
    if (mounted) {
      context.read<ThemeProvider>().refresh();
    }
    await ShopConfig.load();
    if (!mounted) return;
    if (fetchSections) {
      final pp = context.read<ProductProvider>();
      _fetchSectionProducts(pp, forceRefresh: true);
    }
    setState(() {});
  }

  /// Trigger fetches for any admin-configured category/brand product sections.
  void _fetchSectionProducts(ProductProvider pp, {bool forceRefresh = false}) {
    final seen = <String>{};
    for (final section in ShopConfig.homeSections) {
      if (!section.enabled || section.type != 'products') continue;
      final fetchLimit = section.fetchLimit < 12 ? 12 : section.fetchLimit;
      if (section.source == 'category' && section.categoryId != null) {
        final key = 'category_${section.categoryId}';
        if (seen.add(key) &&
            (forceRefresh || pp.sectionProducts(key).length < fetchLimit)) {
          pp.fetchSectionProducts(key,
              categoryId: section.categoryId, limit: fetchLimit);
        }
      } else if (section.source == 'brand' && section.brandId != null) {
        final key = 'brand_${section.brandId}';
        if (seen.add(key) &&
            (forceRefresh || pp.sectionProducts(key).length < fetchLimit)) {
          pp.fetchSectionProducts(key,
              brandId: section.brandId, limit: fetchLimit);
        }
      }
    }
  }

  @override
  void dispose() {
    AppNavigation.requestedTab.removeListener(_handleExternalTabRequest);
    _searchDebounce?.cancel();
    _searchController.dispose();
    _speech.stop();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() => _searchQuery = query.trim());
      final pp = context.read<ProductProvider>();
      if (_searchQuery.isNotEmpty) {
        pp.fetchProducts(search: _searchQuery, page: 1);
      }
    });
  }

  Future<void> _toggleVoiceSearch() async {
    if (_isListening) {
      await _speech.stop();
      if (mounted) setState(() => _isListening = false);
      return;
    }
    try {
      final available = await _speech.initialize(
        onStatus: (status) {
          if (status == 'done' || status == 'notListening') {
            if (mounted) setState(() => _isListening = false);
          }
        },
      );
      if (!available) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Voice search is not available on this device')),
          );
        }
        return;
      }
      if (mounted) setState(() => _isListening = true);
      await _speech.listen(
        listenOptions: SpeechListenOptions(
          partialResults: false,
          cancelOnError: true,
          localeId: 'en_IN',
        ),
        onResult: (result) {
          if (result.recognizedWords.isNotEmpty) {
            _searchController.text = result.recognizedWords;
            _searchController.selection = TextSelection.collapsed(
              offset: _searchController.text.length,
            );
            _onSearchChanged(result.recognizedWords);
          }
        },
      );
    } catch (_) {
      if (mounted) setState(() => _isListening = false);
    }
  }

  void _clearSearch() {
    _searchDebounce?.cancel();
    _searchController.clear();
    setState(() => _searchQuery = '');
  }

  void _selectTab(int index) {
    setState(() => _currentIndex = index);
    if (index == 0) _refreshShopConfig(fetchSections: true);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final cartCount = context.watch<CartProvider>().itemCount;

    final Widget activeBody = switch (_currentIndex) {
      1 => const ReelsScreen(),
      2 => const ServicesTab(),
      3 => const CartTab(),
      4 => const ProfileTab(),
      _ => Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: AnnotatedRegion<SystemUiOverlayStyle>(
              value: SystemUiOverlayStyle(
                statusBarColor: Colors.transparent,
                statusBarIconBrightness: scheme.brightness == Brightness.dark
                    ? Brightness.light
                    : Brightness.dark,
                statusBarBrightness: scheme.brightness,
              ),
              child: SafeArea(
                top: true,
                bottom: false,
                child: _buildHomeBody(context, scheme, cartCount),
              ),
            ),
          ),
        ),
    };

    return LayoutBuilder(
      builder: (context, constraints) {
        final useRail = constraints.maxWidth >= 840;
        if (useRail) {
          return Scaffold(
            body: Row(
              children: [
                NavigationRail(
                  extended: constraints.maxWidth >= 1120,
                  selectedIndex: _currentIndex,
                  onDestinationSelected: _selectTab,
                  backgroundColor: scheme.surfaceContainerLowest,
                  indicatorColor: scheme.secondaryContainer,
                  leading: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Icon(Icons.eco_rounded, color: scheme.primary, size: 28),
                  ),
                  destinations: [
                    NavigationRailDestination(
                      icon: const Icon(Icons.home_outlined),
                      selectedIcon: Icon(Icons.home, color: scheme.primary),
                      label: const Text('Home'),
                    ),
                    NavigationRailDestination(
                      icon: const Icon(Icons.slow_motion_video_outlined),
                      selectedIcon: Icon(Icons.slow_motion_video, color: scheme.primary),
                      label: const Text('Reels'),
                    ),
                    NavigationRailDestination(
                      icon: const Icon(Icons.construction_outlined),
                      selectedIcon: Icon(Icons.construction, color: scheme.primary),
                      label: const Text('Services'),
                    ),
                    NavigationRailDestination(
                      icon: _cartNavigationIcon(context, false),
                      selectedIcon: _cartNavigationIcon(context, true),
                      label: const Text('Cart'),
                    ),
                    NavigationRailDestination(
                      icon: const Icon(Icons.person_outlined),
                      selectedIcon: Icon(Icons.person, color: scheme.primary),
                      label: const Text('Profile'),
                    ),
                  ],
                ),
                const VerticalDivider(width: 1),
                Expanded(child: activeBody),
              ],
            ),
          );
        }

        return Scaffold(
          body: activeBody,
          bottomNavigationBar: NavigationBar(
            selectedIndex: _currentIndex,
            onDestinationSelected: _selectTab,
            destinations: [
              NavigationDestination(
                icon: const Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home, color: scheme.primary),
                label: 'Home',
              ),
              NavigationDestination(
                icon: const Icon(Icons.slow_motion_video_outlined),
                selectedIcon: Icon(Icons.slow_motion_video, color: scheme.primary),
                label: 'Reels',
              ),
              NavigationDestination(
                icon: const Icon(Icons.construction_outlined),
                selectedIcon: Icon(Icons.construction, color: scheme.primary),
                label: 'Services',
              ),
              NavigationDestination(
                icon: _cartNavigationIcon(context, false),
                selectedIcon: _cartNavigationIcon(context, true),
                label: 'Cart',
              ),
              NavigationDestination(
                icon: const Icon(Icons.person_outlined),
                selectedIcon: Icon(Icons.person, color: scheme.primary),
                label: 'Profile',
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHomeBody(
    BuildContext context,
    ColorScheme scheme,
    int cartCount,
  ) {
    return RefreshIndicator(
      color: scheme.primary,
      onRefresh: () async {
        final pp = context.read<ProductProvider>();
        await _refreshShopConfig();
        if (!mounted) return;
        await _fetchAllHomeFeeds(pp);
        _fetchSectionProducts(pp, forceRefresh: true);
      },
      child: ValueListenableBuilder<int>(
        valueListenable: ShopConfig.revision,
        builder: (context, _, _) {
          return CustomScrollView(
            slivers: [
              if (_isSectionEnabled('announcement'))
                SliverToBoxAdapter(child: _buildAnnouncementBar(context)),
              SliverToBoxAdapter(
                child: _buildReferenceHeader(context, cartCount),
              ),
              SliverToBoxAdapter(child: _buildSearchBar(context)),
              if (_searchQuery.isNotEmpty)
                _buildSearchResults(context)
              else ...[
                ..._buildHomeSections(context),
                const SliverToBoxAdapter(child: SizedBox(height: 24)),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _cartNavigationIcon(BuildContext context, bool selected) {
    final count = context.watch<CartProvider>().itemCount;
    final icon = Icon(
      selected ? Icons.shopping_cart : Icons.shopping_cart_outlined,
      color: selected ? Theme.of(context).colorScheme.primary : null,
    );
    if (count == 0) return icon;
    return Badge(label: Text('$count'), child: icon);
  }

  Widget _shimmerCard() => const ShimmerProductCard();

  Future<void> _openPromoLink(BuildContext context) =>
      _openAppLink(context, ShopConfig.promoBannerLink, fallbackToSearch: true);

  Future<void> _openAppLink(BuildContext context, String? rawLink,
      {bool fallbackToSearch = false}) async {
    final link = rawLink?.trim() ?? '';
    if (link.isEmpty) {
      if (fallbackToSearch && context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ProductSearchScreen()),
        );
      }
      return;
    }

    if (link.startsWith('http://') || link.startsWith('https://')) {
      final uri = Uri.tryParse(link);
      if (uri != null && await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }
    }

    final uri = Uri.tryParse(link);
    final path = uri?.path ?? link;
    if (path.startsWith('/services')) {
      if (mounted) setState(() => _currentIndex = 2);
      return;
    }
    if (path.startsWith('/subscription')) {
      if (context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
        );
      }
      return;
    }
    if (path.startsWith('/products')) {
      final categorySlug = uri?.queryParameters['category']?.toLowerCase();
      if (categorySlug != null && categorySlug.isNotEmpty && context.mounted) {
        final cats = context.read<ProductProvider>().categories;
        for (final cat in cats) {
          if (cat.slug.toLowerCase() == categorySlug) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CategoryProductsScreen(
                  categoryId: cat.id,
                  categoryName: cat.name,
                ),
              ),
            );
            return;
          }
        }
      }
      if (context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ProductSearchScreen()),
        );
      }
      return;
    }

    if (fallbackToSearch && context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ProductSearchScreen()),
      );
    }
  }

  Widget _buildReferenceHeader(BuildContext context, int cartCount) {
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      color: primary,
      padding: EdgeInsets.only(
        top: MediaQuery.paddingOf(context).top + 12,
        left: 18,
        right: 12,
        bottom: 16,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              ShopConfig.siteName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 22,
                letterSpacing: 0.3,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Wishlist',
            onPressed: () => Navigator.pushNamed(context, '/wishlist'),
            icon: const Icon(
              Icons.favorite_border_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          Consumer<NotificationProvider>(
            builder: (context, notificationProvider, _) {
              final unread = notificationProvider.unreadCount;
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  IconButton(
                    tooltip: 'Notifications',
                    onPressed: () {
                      Navigator.pushNamed(context, '/notifications').then((_) {
                        notificationProvider.loadUnreadCount();
                      });
                    },
                    icon: const Icon(
                      Icons.notifications_none_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  if (unread > 0)
                    Positioned(
                      right: 2,
                      top: 0,
                      child: Container(
                        constraints: const BoxConstraints(
                          minWidth: 18,
                          minHeight: 18,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          color: Colors.redAccent,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                        child: Text(
                          unread > 99 ? '99+' : '$unread',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                tooltip: 'Cart',
                onPressed: () => setState(() => _currentIndex = 3),
                icon: const Icon(
                  Icons.shopping_cart_outlined,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              if (cartCount > 0)
                Positioned(
                  right: 2,
                  top: 0,
                  child: Container(
                    constraints: const BoxConstraints(
                      minWidth: 18,
                      minHeight: 18,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$cartCount',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: primary,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      color: primary,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      child: TextField(
        controller: _searchController,
        onChanged: _onSearchChanged,
        textInputAction: TextInputAction.search,
        style: const TextStyle(fontSize: 15),
        decoration: InputDecoration(
          hintText: 'Search products, brands or crops',
          hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),
          prefixIcon: Icon(Icons.search_rounded, color: primary, size: 24),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.close_rounded, color: Colors.grey.shade500),
                  onPressed: _clearSearch,
                )
              : IconButton(
                  tooltip: _isListening ? 'Stop listening' : 'Voice search',
                  icon: Icon(
                    _isListening ? Icons.mic_rounded : Icons.mic_none_rounded,
                    color: _isListening ? Colors.red : Colors.grey.shade500,
                    size: 24,
                  ),
                  onPressed: _toggleVoiceSearch,
                ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 0),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(17),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(17),
            borderSide: BorderSide(color: primary, width: 1.5),
          ),
        ),
      ),
    );
  }

  /// Inline search results grid (shown instead of home content while typing).
  Widget _buildSearchResults(BuildContext context) {
    return Consumer<ProductProvider>(
      builder: (context, pp, _) {
        if (pp.searchLoading && pp.searchProducts.isEmpty) {
          return SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverGrid(
              gridDelegate: responsiveProductGridDelegate(),
              delegate: SliverChildBuilderDelegate(
                (_, __) => _shimmerCard(),
                childCount: 6,
              ),
            ),
          );
        }
        if (pp.searchProducts.isEmpty) {
          return SliverToBoxAdapter(
            child: EmptyState(
              icon: Icons.search_off_rounded,
              title: 'No products found',
              message: 'Try a different search term',
              actionLabel: 'Clear Search',
              actionIcon: Icons.close_rounded,
              onAction: _clearSearch,
            ),
          );
        }
        return SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverGrid(
            gridDelegate: responsiveProductGridDelegate(),
            delegate: SliverChildBuilderDelegate(
              (context, index) => ProductCard(
                product: pp.searchProducts[index],
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ProductDetailScreen(product: pp.searchProducts[index]),
                  ),
                ),
              ),
              childCount: pp.searchProducts.length,
            ),
          ),
        );
      },
    );
  }

  /// Build the home page body sections in the admin-configured order.
  bool _isSectionEnabled(String type) =>
      ShopConfig.homeSections.any((s) => s.type == type && s.enabled);

  List<Widget> _buildHomeSections(BuildContext context) {
    final pp = context.watch<ProductProvider>();
    final sections = ShopConfig.homeSections
        .where((s) => s.enabled && s.type != 'announcement')
        .toList();

    final slivers = <Widget>[];

    for (var i = 0; i < sections.length; i++) {
      final section = sections[i];
      final hasSpacerBefore =
          (section.type == 'products' || section.type == 'services') &&
              slivers.isNotEmpty;
      if (hasSpacerBefore) {
        slivers.add(const SliverToBoxAdapter(child: SizedBox(height: 6)));
      }

      switch (section.type) {
        case 'announcement':
          break;
        case 'delivery':
          slivers.add(SliverToBoxAdapter(child: _buildDeliveryBar(context)));
          break;
        case 'banner_carousel':
          slivers.add(SliverToBoxAdapter(child: _buildReferenceBanners(context)));
          break;
        case 'categories':
          slivers.add(SliverToBoxAdapter(child: _buildCategoriesRail(context)));
          break;
        case 'brands':
          slivers.add(SliverToBoxAdapter(child: _buildBrandRail(context)));
          break;
        case 'promo':
          if (ShopConfig.promoBannerEnabled) {
            slivers.add(SliverToBoxAdapter(child: _buildPromoStrip(context)));
          }
          break;
        case 'subscription':
          slivers.add(SliverToBoxAdapter(child: _buildSubscriptionBanner(context)));
          break;
        case 'services':
          slivers.add(_buildServicesSection(context));
          break;
        case 'products':
          slivers.add(_buildConfiguredProductSection(context, pp, section));
          break;
      }
    }

    return slivers;
  }

  Widget _buildConfiguredProductSection(
      BuildContext context, ProductProvider pp, HomeSection section) {
    final String title;
    final List<Product> products;
    final bool loading;

    switch (section.source) {
      case 'offers':
        title = section.title ?? "Today's Offers";
        products = pp.offerProducts;
        loading = pp.offerLoading;
        break;
      case 'featured':
        title = section.title ?? 'Featured Products';
        products = pp.featuredProducts;
        loading = pp.featuredLoading;
        break;
      case 'newest':
        title = section.title ?? 'Newly Added';
        products = pp.products;
        loading = pp.isLoading;
        break;
      case 'category':
        title = section.title ?? 'Products';
        final key = 'category_${section.categoryId}';
        products = pp.sectionProducts(key);
        loading = pp.isSectionLoading(key);
        break;
      case 'brand':
        title = section.title ?? 'Products';
        final key = 'brand_${section.brandId}';
        products = pp.sectionProducts(key);
        loading = pp.isSectionLoading(key);
        break;
      default:
        title = section.title ?? 'Products';
        products = pp.products;
        loading = pp.isLoading;
    }

    return _buildProductSection(
      context,
      section: section,
      title: title,
      products: products,
      loading: loading,
    );
  }

  Widget _buildAnnouncementBar(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final message = ShopConfig.announcementMessage;
    if (message.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      color: scheme.primaryContainer.withValues(alpha: 0.5),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.campaign_rounded, color: scheme.primary, size: 16),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              message,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: scheme.onPrimaryContainer,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubscriptionBanner(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    if (!auth.isLoggedIn || user?.isProMember == true) {
      return const SizedBox.shrink();
    }
    final primary = Theme.of(context).colorScheme.primary;
    final primaryDark = Theme.of(context).colorScheme.onPrimaryContainer;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Theme.of(context).colorScheme.tertiary, primary],
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.workspace_premium, color: Colors.white),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Go Pro with Magray Orchards',
                        style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Free delivery, fast support & premium content',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: primaryDark,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Explore Plans'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBrandRail(BuildContext context) {
    final pp = context.watch<ProductProvider>();
    if (pp.brands.isEmpty) {
      if (pp.brandsLoading) {
        return const ShimmerBrandRail();
      }
      return const SizedBox.shrink();
    }
    final primary = Theme.of(context).colorScheme.primary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(18, 20, 18, 4),
          child: Text(
            'Shop by Brand',
            style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
          ),
        ),
        SizedBox(
          height: 96,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: pp.brands.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final brand = pp.brands[index];
              return GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => BrandProductsScreen(
                      brandId: brand.id,
                      brandName: brand.name,
                    ),
                  ),
                ),
                child: SizedBox(
                  width: 96,
                  child: Column(
                    children: [
                      Container(
                        width: 68,
                        height: 68,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: Theme.of(context).dividerColor),
                        ),
                        padding: const EdgeInsets.all(8),
                        child: brand.logo != null
                            ? AppNetworkImage(
                                imageUrl: '${ApiConfig.imageBaseUrl}${brand.logo}',
                                fit: BoxFit.contain,
                                errorWidget: (_, __, ___) => Icon(Icons.business, color: primary),
                                placeholder: (_, __) => Icon(Icons.business, color: primary),
                              )
                            : Icon(Icons.business, color: primary, size: 32),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        brand.name,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDeliveryBar(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final pin = auth.user?.defaultPincode;
    final primary = Theme.of(context).colorScheme.primary;
    return GestureDetector(
      onTap: () => _openDeliveryAddressPicker(context),
      child: Container(
        color: primary,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
        child: Row(
          children: [
            const Icon(Icons.location_on_rounded, color: Colors.white, size: 22),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                pin == null ? 'Delivering across Kashmir' : 'Delivering to $pin',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: Colors.white,
              size: 24,
            ),
          ],
        ),
      ),
    );
  }

  /// Show a bottom sheet to pick a delivery address or add a new one.
  Future<void> _openDeliveryAddressPicker(BuildContext context) async {
    final auth = context.read<AuthProvider>();

    if (!auth.isLoggedIn) {
      final goToLogin = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Login required'),
          content: const Text('Please login to choose a delivery address.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Login'),
            ),
          ],
        ),
      );
      if (goToLogin == true && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      }
      return;
    }

    final addressProvider = context.read<AddressProvider>();
    if (addressProvider.addresses.isEmpty) {
      await addressProvider.fetchAddresses();
    }
    if (!mounted) return;

    final scheme = Theme.of(context).colorScheme;
    final primary = scheme.primary;
    final primaryContainer = scheme.primaryContainer;

    // Track whether an address was added from within the sheet so we refresh.
    var added = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: scheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.location_on_outlined, color: primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Deliver to',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: scheme.onSurface,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Close',
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(sheetContext),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Consumer<AddressProvider>(
                      builder: (ctx, ap, _) {
                        if (ap.isLoading && ap.addresses.isEmpty) {
                          return const Padding(
                            padding: EdgeInsets.all(24),
                            child: Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          );
                        }
                        if (ap.addresses.isEmpty) {
                          return Padding(
                            padding: const EdgeInsets.all(16),
                            child: Center(
                              child: Text(
                                'No saved addresses yet. Add one to get delivery estimates.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.grey.shade600),
                              ),
                            ),
                          );
                        }
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: ap.addresses.map((address) {
                            final isSelected = ap.selectedAddress?.id ==
                                address.id;
                            return Card(
                              elevation: 0,
                              margin:
                                  const EdgeInsets.only(bottom: 8),
                              color: isSelected
                                  ? primaryContainer.withValues(alpha: 0.4)
                                  : scheme.surfaceContainerHighest
                                      .withValues(alpha: 0.4),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(
                                  color: isSelected
                                      ? primary
                                      : scheme.outlineVariant,
                                  width: isSelected ? 1.5 : 1,
                                ),
                              ),
                              child: ListTile(
                                onTap: () {
                                  ap.selectAddress(address.id);
                                  auth.setDefaultAddress(
                                    pincode: address.pincode,
                                    city: address.city,
                                    state: address.state,
                                  );
                                  Navigator.pop(sheetContext);
                                },
                                title: Text(
                                  address.addressLine1,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: scheme.onSurface,
                                  ),
                                ),
                                subtitle: Text(
                                  '${address.city}, ${address.state} ${address.pincode}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                                leading: Icon(Icons.home_outlined, color: primary),
                                trailing: isSelected
                                    ? Icon(Icons.check_circle, color: primary)
                                    : null,
                              ),
                            );
                          }).toList(),
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          added = true;
                          await Navigator.push(
                            sheetContext,
                            MaterialPageRoute(
                              builder: (_) => const AddressFormScreen(),
                            ),
                          );
                          if (sheetContext.mounted) {
                            await addressProvider.fetchAddresses();
                            setSheetState(() {});
                          }
                        },
                        icon: const Icon(Icons.add_location_alt_outlined),
                        label: const Text('Add New Address'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: primary,
                          side: BorderSide(color: primary),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (added && mounted) {
      // A new address was added: use it as the delivery default.
      final newDefault = addressProvider.selectedAddress;
      if (newDefault != null) {
        auth.setDefaultAddress(
          pincode: newDefault.pincode,
          city: newDefault.city,
          state: newDefault.state,
        );
      }
    }
  }

  Widget _buildReferenceBanners(BuildContext context) {
    final pp = context.watch<ProductProvider>();
    if (pp.banners.isEmpty) {
      if (pp.bannersLoading) {
        return const ShimmerBannerCarousel();
      }
      return const SizedBox(height: 8);
    }
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      color: primary,
      padding: const EdgeInsets.only(bottom: 14),
      child: CarouselSlider(
        options: CarouselOptions(
          height: 152,
          autoPlay: true,
          viewportFraction: .92,
          enlargeCenterPage: true,
          autoPlayInterval: const Duration(seconds: 4),
        ),
        items: pp.banners
            .map(
              (banner) => GestureDetector(
                onTap: () =>
                    _openAppLink(context, banner.link ?? banner.linkValue),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (banner.image != null)
                        AppNetworkImage(
                          imageUrl: '${ApiConfig.imageBaseUrl}${banner.image}',
                          fit: BoxFit.cover,
                        )
                      else
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [primary, primary.withValues(alpha: .65)],
                            ),
                          ),
                        ),
                      if (banner.title != null)
                        Positioned(
                          left: 16,
                          right: 16,
                          bottom: 13,
                          child: Text(
                            banner.title!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 18,
                              shadows: [
                                Shadow(color: Colors.black54, blurRadius: 5),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildCategoriesRail(BuildContext context) {
    final pp = context.watch<ProductProvider>();
    if (pp.categories.isEmpty) {
      if (pp.categoriesLoading) {
        return const ShimmerCategoriesRail();
      }
      return const SizedBox.shrink();
    }
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      color: Colors.white,
      height: 190,
      padding: const EdgeInsets.only(top: 12, bottom: 4),
      child: GridView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisExtent: 90,
          mainAxisSpacing: 5,
          crossAxisSpacing: 2,
        ),
        itemCount: pp.categories.length,
        itemBuilder: (context, index) {
          final cat = pp.categories[index];
          return GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CategoryProductsScreen(
                  categoryId: cat.id,
                  categoryName: cat.name,
                ),
              ),
            ),
            child: Column(
              children: [
                Container(
                  width: 62,
                  height: 62,
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: primary, width: 2),
                  ),
                  child: ClipOval(
                    child: cat.image != null
                        ? AppNetworkImage(
                            imageUrl: '${ApiConfig.imageBaseUrl}${cat.image}',
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) =>
                                Icon(Icons.eco, color: primary),
                          )
                        : Icon(Icons.eco, color: primary),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  cat.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPromoStrip(BuildContext context) {
    final color = ShopConfig.promoBannerColor;
    return GestureDetector(
      onTap: () => _openPromoLink(context),
      child: Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: color,
          gradient: LinearGradient(
            colors: [color, Color.lerp(color, Colors.white, .18) ?? color],
          ),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.local_fire_department_rounded,
              color: Colors.white,
              size: 27,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    ShopConfig.promoBannerTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                  if (ShopConfig.promoBannerSubtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      ShopConfig.promoBannerSubtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_rounded, color: Colors.white),
          ],
        ),
      ),
    );
  }

  Widget _buildProductSection(
    BuildContext context, {
    required HomeSection section,
    required String title,
    required List<Product> products,
    required bool loading,
  }) {
    if (!loading && products.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }
    if (loading && products.isEmpty) {
      return SliverToBoxAdapter(
        child: ShimmerProductSection(
          title: title,
          layout: section.layout ?? 'carousel',
        ),
      );
    }

    final header = Padding(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              if (section.source == 'category' && section.categoryId != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CategoryProductsScreen(
                      categoryId: section.categoryId!,
                      categoryName: title,
                    ),
                  ),
                );
              } else if (section.source == 'brand' && section.brandId != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => BrandProductsScreen(
                      brandId: section.brandId!,
                      brandName: title,
                    ),
                  ),
                );
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ProductSearchScreen(),
                  ),
                );
              }
            },
            child: const Text('View all'),
          ),
        ],
      ),
    );

    final rowCount = section.rowCount;
    if (section.isGrid) {
      return SliverToBoxAdapter(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final columns = ((constraints.maxWidth - 32) / 215).floor().clamp(2, 5);
            final visible = products.take(rowCount * columns).toList();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                header,
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: responsiveProductGridDelegate(spacing: 10),
                    itemCount: visible.length,
                    itemBuilder: (_, index) {
                      final product = visible[index];
                      return ProductCard(
                        product: product,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ProductDetailScreen(product: product),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      );
    }

    // Carousel: stack up to `rows` horizontal lists with `itemsPerRow` cards each.
    final perRow = section.itemsPerRow;
    final carouselRows = <Widget>[];
    for (var rowIndex = 0; rowIndex < rowCount; rowIndex++) {
      final start = rowIndex * perRow;
      if (start >= products.length) break;
      final end = (start + perRow).clamp(start, products.length);
      final rowProducts = products.sublist(start, end);
      carouselRows.add(
        SizedBox(
          height: 290,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: rowProducts.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, index) => SizedBox(
              width: 158,
              child: ProductCard(
                product: rowProducts[index],
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        ProductDetailScreen(product: rowProducts[index]),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          header,
          ...carouselRows,
        ],
      ),
    );
  }

  Widget _buildServicesSection(BuildContext context) {
    final pp = context.watch<ProductProvider>();
    final services = pp.services;
    if (services.isEmpty) {
      if (pp.servicesLoading) {
        return const SliverToBoxAdapter(child: ShimmerServicesRail());
      }
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }
    final primary = Theme.of(context).colorScheme.primary;
    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(18, 22, 18, 10),
            child: Text(
              'Orchard Services',
              style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
            ),
          ),
          SizedBox(
            height: 116,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: services.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final service = services[index];
                return GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ServiceDetailScreen(service: service),
                    ),
                  ),
                  child: Container(
                    width: 205,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: primary.withValues(alpha: .08),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: service.image != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(14),
                                  child: AppNetworkImage(
                                    imageUrl:
                                        '${ApiConfig.imageBaseUrl}${service.image}',
                                    fit: BoxFit.cover,
                                  ),
                                )
                              : Icon(Icons.eco, color: primary),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                service.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                service.formattedPrice,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
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

}
