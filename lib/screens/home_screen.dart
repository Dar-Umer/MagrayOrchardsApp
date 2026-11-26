import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/app_network_image.dart';
import '../widgets/app_loading_indicator.dart';
import '../widgets/empty_state.dart';
import '../widgets/maintenance_screen.dart';
import '../widgets/skeleton_box.dart';
import '../widgets/update_required_screen.dart';
import '../providers/auth_provider.dart';
import '../providers/product_provider.dart';
import '../providers/cart_provider.dart';
import '../providers/address_provider.dart';
import '../providers/notification_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/wishlist_provider.dart';
import '../providers/personalization_provider.dart';
import '../config/api_config.dart';
import '../models/product.dart';
import '../models/home_section.dart';
import '../services/shop_config.dart';
import '../services/location_service.dart';
import '../services/analytics_service.dart';
import '../utils/app_navigation.dart';
import 'login_screen.dart';
import 'phone_input_screen.dart';
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

  // ── Infinite scroll & controller ──
  final ScrollController _scrollController = ScrollController();

  // ── Inline search state ──
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;
  String _searchQuery = '';
  bool _isListening = false;
  bool _showingGateScreen = false;
  final SpeechToText _speech = SpeechToText();

  @override
  void initState() {
    super.initState();
    AnalyticsService.instance.trackScreen('HomeScreen');
    _scrollController.addListener(_onScroll);
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
      context.read<PersonalizationProvider>().fetchPersonalizedFeed();
    });
  }

  void _handleExternalTabRequest() {
    final tab = AppNavigation.requestedTab.value;
    if (tab == null || !mounted) return;
    AppNavigation.requestedTab.value = null;
    if (tab >= 0 && tab < 5) {
      setState(() => _currentIndex = tab);
      if (tab == 0) _refreshShopConfig(fetchSections: true);
      if (tab == 2) {
        LocationService.instance.promptAndDetectLocation(context, force: true, showGpsDialog: true);
      }
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
          isFeatured: true, page: 1, perPage: math.max(_sourcePerPage('featured'), 20)),
      pp.fetchProducts(
          sortBy: 'newest', page: 1, perPage: math.max(_sourcePerPage('newest'), 20)),
      pp.fetchCategories(),
      pp.fetchServices(),
      pp.fetchBanners(),
      pp.fetchOfferProducts(perPage: math.max(_sourcePerPage('offers'), 20)),
      pp.fetchBrands(),
    ]);
  }

  /// Re-fetch the remote shop config (home layout, theme, maintenance, versions)
  /// so admin changes appear without a full app restart. Rebuilds the sections.
  Future<void> _refreshShopConfig({bool fetchSections = false}) async {
    if (mounted) {
      context.read<ThemeProvider>().refresh();
      context.read<PersonalizationProvider>().fetchPersonalizedFeed(force: true);
    }
    final ok = await ShopConfig.load();
    if (!mounted) return;
    if (ok && !_showingGateScreen) {
      if (ShopConfig.maintenanceEnabled) {
        _showingGateScreen = true;
        Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const MaintenanceScreen()))
            .whenComplete(() => _showingGateScreen = false);
        return;
      }
      try {
        final info = await PackageInfo.fromPlatform();
        if (mounted &&
            ShopConfig.compareVersions(info.version, ShopConfig.minVersion) < 0) {
          _showingGateScreen = true;
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => UpdateRequiredScreen(installedVersion: info.version),
            ),
          );
          return;
        }
      } catch (_) {}
    }
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
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    AppNavigation.requestedTab.removeListener(_handleExternalTabRequest);
    _searchDebounce?.cancel();
    _searchController.dispose();
    _speech.stop();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    if (maxScroll > 0 && currentScroll >= maxScroll - 350) {
      final pp = context.read<ProductProvider>();
      if (!pp.infiniteLoading && pp.infiniteHasMore) {
        pp.loadMoreInfiniteProducts();
      }
    }
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
    if (index == 2) {
      LocationService.instance.promptAndDetectLocation(context, force: true, showGpsDialog: true);
    }
    const tabNames = ['HomeScreen', 'ReelsScreen', 'ServicesTab', 'CartTab', 'ProfileTab'];
    if (index >= 0 && index < tabNames.length) {
      AnalyticsService.instance.trackScreen(tabNames[index]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final Widget homeBody = Align(
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
            child: _buildHomeBody(context, scheme),
          ),
        ),
      ),
    );

    final Widget activeBody = IndexedStack(
      index: _currentIndex,
      children: [
        homeBody,
        _currentIndex == 1 ? const ReelsScreen() : const SizedBox.shrink(),
        const ServicesTab(),
        const CartTab(),
        const ProfileTab(),
      ],
    );

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
                      selectedIcon: Icon(Icons.home_rounded, color: scheme.primary),
                      label: const Text('Home'),
                    ),
                    NavigationRailDestination(
                      icon: const Icon(Icons.play_circle_outline_rounded),
                      selectedIcon: Icon(Icons.play_circle_rounded, color: scheme.primary),
                      label: const Text('Reels'),
                    ),
                    NavigationRailDestination(
                      icon: const ImageIcon(AssetImage('assets/icons/services_quality.png'), size: 24),
                      selectedIcon: ImageIcon(const AssetImage('assets/icons/services_quality.png'), size: 24, color: scheme.primary),
                      label: const Text('Services'),
                    ),
                    NavigationRailDestination(
                      icon: _cartNavigationIcon(context, false),
                      selectedIcon: _cartNavigationIcon(context, true),
                      label: const Text('Cart'),
                    ),
                    NavigationRailDestination(
                      icon: const Icon(Icons.person_outline_rounded),
                      selectedIcon: Icon(Icons.person_rounded, color: scheme.primary),
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
                selectedIcon: Icon(Icons.home_rounded, color: scheme.primary),
                label: 'Home',
              ),
              NavigationDestination(
                icon: const Icon(Icons.play_circle_outline_rounded),
                selectedIcon: Icon(Icons.play_circle_rounded, color: scheme.primary),
                label: 'Reels',
              ),
              NavigationDestination(
                icon: const ImageIcon(AssetImage('assets/icons/services_quality.png'), size: 24),
                selectedIcon: ImageIcon(const AssetImage('assets/icons/services_quality.png'), size: 24, color: scheme.primary),
                label: 'Services',
              ),
              NavigationDestination(
                icon: _cartNavigationIcon(context, false),
                selectedIcon: _cartNavigationIcon(context, true),
                label: 'Cart',
              ),
              NavigationDestination(
                icon: const Icon(Icons.person_outline_rounded),
                selectedIcon: Icon(Icons.person_rounded, color: scheme.primary),
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
  ) {
    return RefreshIndicator(
      color: scheme.primary,
      onRefresh: () async {
        final pp = context.read<ProductProvider>();
        pp.resetInfiniteProducts();
        await _refreshShopConfig();
        if (!mounted) return;
        await _fetchAllHomeFeeds(pp);
        _fetchSectionProducts(pp, forceRefresh: true);
      },
      child: ValueListenableBuilder<int>(
        valueListenable: ShopConfig.revision,
        builder: (context, _, _) {
          return CustomScrollView(
            controller: _scrollController,
            slivers: [
              if (_isSectionEnabled('announcement'))
                SliverToBoxAdapter(child: _buildAnnouncementBar(context)),
              SliverToBoxAdapter(
                child: _buildReferenceHeader(context),
              ),
              SliverToBoxAdapter(child: _buildSearchBar(context)),
              if (_searchQuery.isNotEmpty)
                _buildSearchResults(context)
              else ...[
                ..._buildHomeSections(context),
                ..._buildInfiniteFeedSlivers(context, scheme),
                const SliverToBoxAdapter(child: SizedBox(height: 24)),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _cartNavigationIcon(BuildContext context, bool selected) {
    return Selector<CartProvider, int>(
      selector: (_, cart) => cart.itemCount,
      builder: (context, count, child) {
        final icon = Icon(
          selected ? Icons.shopping_cart_rounded : Icons.shopping_cart_outlined,
          color: selected ? Theme.of(context).colorScheme.primary : null,
        );
        if (count == 0) return icon;
        return Badge(label: Text('$count'), child: icon);
      },
    );
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

  Widget _buildReferenceHeader(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      color: primary,
      padding: const EdgeInsets.only(
        top: 14,
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
    final pers = context.watch<PersonalizationProvider>();
    final sections = ShopConfig.homeSections
        .where((s) => s.enabled && s.type != 'announcement')
        .toList();

    final slivers = <Widget>[];
    final displayedProductIds = <int>{};

    final hasExplicitRecentlyViewed = sections.any((s) => s.type == 'recently_viewed');
    final hasExplicitRecommended = sections.any((s) => s.type == 'recommended');
    final hasExplicitBuyAgain = sections.any((s) => s.type == 'buy_again');
    final hasExplicitWishlist = sections.any((s) => s.type == 'wishlist_picks');
    final hasExplicitSeasonal = sections.any((s) => s.type == 'seasonal_orchard');

    for (var i = 0; i < sections.length; i++) {
      final section = sections[i];
      final hasSpacerBefore =
          (section.type == 'products' ||
           section.type == 'services' ||
           section.type == 'recently_viewed' ||
           section.type == 'recommended' ||
           section.type == 'buy_again' ||
           section.type == 'wishlist_picks' ||
           section.type == 'seasonal_orchard') &&
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
          // If recently viewed is not explicitly in layout, seamlessly inject it right after categories
          if (!hasExplicitRecentlyViewed) {
            final recViewed = pers.recentlyViewed
                .where((p) => !displayedProductIds.contains(p.id))
                .toList();
            if (recViewed.isNotEmpty) {
              slivers.add(const SliverToBoxAdapter(child: SizedBox(height: 8)));
              slivers.add(_buildRecentlyViewedSliver(context, pers, null, displayedProductIds));
            }
          }
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
          slivers.add(_buildConfiguredProductSection(context, pp, section, displayedProductIds));
          break;
        case 'recently_viewed':
          final recViewed = pers.recentlyViewed
              .where((p) => !displayedProductIds.contains(p.id))
              .toList();
          if (recViewed.isNotEmpty) {
            slivers.add(_buildRecentlyViewedSliver(context, pers, section, displayedProductIds));
          }
          break;
        case 'recommended':
          final recs = pers.recommendedProducts
              .where((p) => !displayedProductIds.contains(p.id))
              .toList();
          final recsToDisplay = recs.isNotEmpty ? recs : pers.recommendedProducts;
          if (recsToDisplay.isNotEmpty) {
            displayedProductIds.addAll(recsToDisplay.map((p) => p.id));
            slivers.add(_buildPersonalizedProductSection(
              context,
              title: section.title ?? 'Recommended For Your Orchard',
              products: recsToDisplay,
              section: section,
            ));
          }
          break;
        case 'buy_again':
          final buyAgain = pers.buyAgainProducts
              .where((p) => !displayedProductIds.contains(p.id))
              .toList();
          if (buyAgain.isNotEmpty) {
            displayedProductIds.addAll(buyAgain.map((p) => p.id));
            slivers.add(_buildPersonalizedProductSection(
              context,
              title: section.title ?? 'Buy It Again',
              products: buyAgain,
              section: section,
            ));
          }
          break;
        case 'wishlist_picks':
          final wl = pers.wishlistPicks
              .where((p) => !displayedProductIds.contains(p.id))
              .toList();
          if (wl.isNotEmpty) {
            displayedProductIds.addAll(wl.map((p) => p.id));
            slivers.add(_buildPersonalizedProductSection(
              context,
              title: section.title ?? 'From Your Wishlist & Similar',
              products: wl,
              section: section,
            ));
          }
          break;
        case 'seasonal_orchard':
          final seasonal = pers.seasonalProducts
              .where((p) => !displayedProductIds.contains(p.id))
              .toList();
          final seasonalToDisplay = seasonal.isNotEmpty ? seasonal : pers.seasonalProducts;
          if (seasonalToDisplay.isNotEmpty) {
            displayedProductIds.addAll(seasonalToDisplay.map((p) => p.id));
            slivers.add(_buildPersonalizedProductSection(
              context,
              title: section.title ?? 'Seasonal Kashmiri Orchard Care',
              products: seasonalToDisplay,
              section: section,
            ));
          }
          break;
      }
    }

    // Auto-inject buy-again, recommended & seasonal if not in explicit layout and items exist
    if (!hasExplicitBuyAgain) {
      final buyAgain = pers.buyAgainProducts
          .where((p) => !displayedProductIds.contains(p.id))
          .toList();
      if (buyAgain.isNotEmpty) {
        displayedProductIds.addAll(buyAgain.map((p) => p.id));
        slivers.add(const SliverToBoxAdapter(child: SizedBox(height: 8)));
        slivers.add(_buildPersonalizedProductSection(
          context,
          title: 'Buy It Again',
          products: buyAgain,
        ));
      }
    }

    if (!hasExplicitRecommended) {
      final recs = pers.recommendedProducts
          .where((p) => !displayedProductIds.contains(p.id))
          .toList();
      if (recs.isNotEmpty) {
        displayedProductIds.addAll(recs.map((p) => p.id));
        slivers.add(const SliverToBoxAdapter(child: SizedBox(height: 8)));
        slivers.add(_buildPersonalizedProductSection(
          context,
          title: 'Recommended For Your Orchard',
          products: recs,
        ));
      }
    }

    if (!hasExplicitSeasonal) {
      final seasonal = pers.seasonalProducts
          .where((p) => !displayedProductIds.contains(p.id))
          .toList();
      if (seasonal.isNotEmpty) {
        displayedProductIds.addAll(seasonal.map((p) => p.id));
        slivers.add(const SliverToBoxAdapter(child: SizedBox(height: 8)));
        slivers.add(_buildPersonalizedProductSection(
          context,
          title: 'Seasonal Kashmiri Orchard Care',
          products: seasonal,
        ));
      }
    }

    return slivers;
  }

  List<Widget> _buildInfiniteFeedSlivers(BuildContext context, ColorScheme scheme) {
    final pp = context.watch<ProductProvider>();
    final slivers = <Widget>[];

    // If infinite feed hasn't been initialized yet and isn't currently loading:
    if (!pp.infiniteInitialized && !pp.infiniteLoading) {
      slivers.add(
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(top: 16, bottom: 8),
            child: Center(
              child: TextButton.icon(
                key: const Key('infinite_scroll_sentinel_btn'),
                onPressed: () => context.read<ProductProvider>().loadMoreInfiniteProducts(),
                icon: const Icon(Icons.keyboard_arrow_down_rounded),
                label: const Text('Scroll to load more products'),
              ),
            ),
          ),
        ),
      );
      return slivers;
    }

    // Initial loading indicator when user reaches the bottom for the first time
    if (pp.infiniteProducts.isEmpty && pp.infiniteLoading) {
      slivers.add(
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppLoadingIndicator(
                    size: 24,
                    strokeWidth: 2.5,
                    color: scheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Loading fresh orchard harvest...',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      return slivers;
    }

    // If we have loaded infinite products:
    if (pp.infiniteProducts.isNotEmpty) {
      slivers.add(
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.eco_rounded, size: 18, color: scheme.primary),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Explore All Products',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: scheme.onSurface,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: scheme.secondaryContainer.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${pp.infiniteProducts.length} items',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: scheme.onSecondaryContainer,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Fresh Kashmiri harvest • Top rated reviews first',
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      slivers.add(
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverGrid(
            gridDelegate: responsiveProductGridDelegate(),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final product = pp.infiniteProducts[index];
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
              childCount: pp.infiniteProducts.length,
            ),
          ),
        ),
      );

      if (pp.infiniteLoading) {
        slivers.add(
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppLoadingIndicator(
                      size: 20,
                      strokeWidth: 2.2,
                      color: scheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Loading 10 more products...',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }

      if (!pp.infiniteHasMore) {
        slivers.add(
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 24, 16, 12),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: scheme.outlineVariant.withValues(alpha: 0.4),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer.withValues(alpha: 0.4),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.check_circle_outline_rounded, color: scheme.primary, size: 28),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "You've reached the end of our orchard catalog",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurface,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Showing all ${pp.infiniteProducts.length} verified products sorted by rating',
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 14),
                  FilledButton.tonalIcon(
                    key: const Key('infinite_back_to_top_btn'),
                    onPressed: () {
                      _scrollController.animateTo(
                        0,
                        duration: const Duration(milliseconds: 600),
                        curve: Curves.easeOutCubic,
                      );
                    },
                    icon: const Icon(Icons.arrow_upward_rounded, size: 16),
                    label: const Text('Back to Top'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }
    }

    return slivers;
  }

  Widget _buildRecentlyViewedSliver(
    BuildContext context,
    PersonalizationProvider pers, [
    HomeSection? section,
    Set<int>? displayedProductIds,
  ]) {
    final title = section?.title ?? 'Recently Viewed';
    final limit = section?.limit ?? 10;
    final items = (displayedProductIds != null
            ? pers.recentlyViewed.where((p) => !displayedProductIds.contains(p.id))
            : pers.recentlyViewed)
        .take(limit)
        .toList();
    if (items.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());

    displayedProductIds?.addAll(items.map((p) => p.id));

    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.history_rounded, size: 20, color: Color(0xFF800020)),
                    const SizedBox(width: 8),
                    Text(
                      title,
                      style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700, letterSpacing: -0.2),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: () => pers.clearRecentlyViewed(),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: Colors.grey[600],
                  ),
                  child: const Text('Clear', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 230,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final product = items[index];
                return SizedBox(
                  width: 145,
                  child: ProductCard(
                    product: product,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ProductDetailScreen(product: product),
                      ),
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

  Widget _buildPersonalizedProductSection(
    BuildContext context, {
    required String title,
    required List<Product> products,
    HomeSection? section,
  }) {
    final sec = section ?? HomeSection(
      type: 'products',
      title: title,
      layout: 'carousel',
      rows: 1,
      limit: 10,
    );

    final limit = sec.fetchLimit;
    final items = products.take(limit).toList();

    return _buildProductSection(
      context,
      section: sec,
      title: title,
      products: items,
      loading: false,
    );
  }

  Widget _buildConfiguredProductSection(
      BuildContext context, ProductProvider pp, HomeSection section,
      [Set<int>? displayedProductIds]) {
    final String title;
    final List<Product> rawProducts;
    final bool loading;

    switch (section.source) {
      case 'offers':
        title = section.title ?? "Today's Offers";
        rawProducts = pp.offerProducts;
        loading = pp.offerLoading;
        break;
      case 'featured':
        title = section.title ?? 'Featured Products';
        rawProducts = pp.featuredProducts;
        loading = pp.featuredLoading;
        break;
      case 'newest':
        title = section.title ?? 'Newly Added';
        rawProducts = pp.products;
        loading = pp.isLoading;
        break;
      case 'category':
        title = section.title ?? 'Products';
        final key = 'category_${section.categoryId}';
        rawProducts = pp.sectionProducts(key);
        loading = pp.isSectionLoading(key);
        break;
      case 'brand':
        title = section.title ?? 'Products';
        final key = 'brand_${section.brandId}';
        rawProducts = pp.sectionProducts(key);
        loading = pp.isSectionLoading(key);
        break;
      default:
        title = section.title ?? 'Products';
        rawProducts = pp.products;
        loading = pp.isLoading;
    }

    if (loading && rawProducts.isEmpty) {
      return _buildProductSection(
        context,
        section: section,
        title: title,
        products: const [],
        loading: true,
      );
    }

    final uniqueProducts = displayedProductIds != null
        ? rawProducts.where((p) => !displayedProductIds.contains(p.id)).toList()
        : rawProducts;

    final List<Product> productsToDisplay;
    if (uniqueProducts.isNotEmpty) {
      productsToDisplay = uniqueProducts;
    } else {
      // If all candidates were shown in prior sections, still display rawProducts
      // so the admin's section configured in tab=home NEVER disappears from the screen!
      productsToDisplay = rawProducts;
    }

    if (productsToDisplay.isEmpty && !loading) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    displayedProductIds?.addAll(productsToDisplay.map((p) => p.id));

    return _buildProductSection(
      context,
      section: section,
      title: title,
      products: productsToDisplay,
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
            style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700, letterSpacing: -0.2),
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
                                imageUrl: ApiConfig.resolveImageUrl(brand.logo),
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
                              child: AppLoadingIndicator.medium(),
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
                          imageUrl: ApiConfig.resolveImageUrl(banner.image),
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
      height: 200,
      padding: const EdgeInsets.only(top: 10, bottom: 4),
      child: GridView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisExtent: 88,
          mainAxisSpacing: 6,
          crossAxisSpacing: 4,
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
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  padding: const EdgeInsets.all(2.5),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: primary, width: 1.8),
                  ),
                  child: ClipOval(
                    child: cat.image != null
                        ? AppNetworkImage(
                            imageUrl: ApiConfig.resolveImageUrl(cat.image),
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
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 16.5,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
                height: 1.2,
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
              style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700, letterSpacing: -0.2),
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
                  onTap: () async {
                    final loc = LocationService.instance;
                    if (!loc.hasLocation) {
                      await loc.promptAndDetectLocation(context, force: true, showGpsDialog: true);
                    }
                    if (context.mounted) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ServiceDetailScreen(service: service),
                        ),
                      );
                    }
                  },
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
                                        ApiConfig.resolveImageUrl(service.image),
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
