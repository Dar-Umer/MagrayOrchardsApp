import 'dart:async';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/app_network_image.dart';
import '../providers/auth_provider.dart';
import '../providers/product_provider.dart';
import '../providers/cart_provider.dart';
import '../providers/address_provider.dart';
import '../providers/notification_provider.dart';
import '../config/api_config.dart';
import '../models/product.dart';
import '../models/home_section.dart';
import '../services/api_service.dart';
import '../services/shop_config.dart';
import 'login_screen.dart';
import 'register_screen.dart';
import 'product_detail_screen.dart';
import 'service_detail_screen.dart';
import 'category_products_screen.dart';
import 'brand_products_screen.dart';
import 'reels_screen.dart';
import 'product_search_screen.dart';
import 'edit_profile_screen.dart';
import 'orders_screen.dart';
import 'address_screen.dart';
import 'address_form_screen.dart';
import 'wishlist_screen.dart';
import 'subscription_screen.dart';
import 'wallet_screen.dart';
import 'my_bookings_screen.dart';
import 'notifications_screen.dart';
import '../widgets/pro_member_badge.dart';
import '../widgets/section_header.dart';
import '../widgets/app_card.dart';
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshShopConfig();
      final pp = context.read<ProductProvider>();
      if (pp.products.isEmpty) {
        pp.fetchProducts(isFeatured: true, page: 1);
        pp.fetchCategories();
        pp.fetchServices();
        pp.fetchBanners();
        pp.fetchOfferProducts();
        pp.fetchBrands();
      }
      _fetchSectionProducts(pp);
      final auth = context.read<AuthProvider>();
      if (auth.isLoggedIn) {
        context.read<NotificationProvider>().loadUnreadCount();
      }
    });
  }

  /// Re-fetch the remote shop config (home layout, maintenance, versions) so
  /// admin changes appear without a full app restart. Rebuilds the sections.
  Future<void> _refreshShopConfig() async {
    await ShopConfig.load();
    if (mounted) setState(() {});
  }

  /// Trigger fetches for any admin-configured category/brand product sections.
  void _fetchSectionProducts(ProductProvider pp) {
    final seen = <String>{};
    for (final section in ShopConfig.homeSections) {
      if (!section.enabled || section.type != 'products') continue;
      // Fetch enough items to fill the configured rows.
      final perPage = section.isGrid
          ? (section.rowCount * 2)
          : (section.rowCount * 6);
      final fetchLimit = perPage < 12 ? 12 : perPage;
      if (section.source == 'category' && section.categoryId != null) {
        final key = 'category_${section.categoryId}';
        if (seen.add(key) && pp.sectionProducts(key).isEmpty) {
          pp.fetchSectionProducts(key,
              categoryId: section.categoryId, limit: fetchLimit);
        }
      } else if (section.source == 'brand' && section.brandId != null) {
        final key = 'brand_${section.brandId}';
        if (seen.add(key) && pp.sectionProducts(key).isEmpty) {
          pp.fetchSectionProducts(key,
              brandId: section.brandId, limit: fetchLimit);
        }
      }
    }
  }

  @override
  void dispose() {
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

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final cartCount = context.watch<CartProvider>().itemCount;

    if (_currentIndex != 0) return _legacyBuild(context);

    return Scaffold(
      body: RefreshIndicator(
        color: scheme.primary,
        onRefresh: () async {
          await _refreshShopConfig();
          final pp = context.read<ProductProvider>();
          await Future.wait([
            pp.fetchProducts(isFeatured: true, page: 1),
            pp.fetchCategories(),
            pp.fetchServices(),
            pp.fetchBanners(),
            pp.fetchOfferProducts(),
            pp.fetchBrands(),
          ]);
          _fetchSectionProducts(pp);
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
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
          if (index == 0) _refreshShopConfig();
        },
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

  Widget _shimmerCard() {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Container(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
    );
  }

  Future<void> _openPromoLink(BuildContext context) async {
    final link = ShopConfig.promoBannerLink;
    if (link.startsWith('http://') || link.startsWith('https://')) {
      final uri = Uri.tryParse(link);
      if (uri != null && await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }
    }
    if (context.mounted) {
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
        top: MediaQuery.paddingOf(context).top + 10,
        left: 18,
        right: 12,
        bottom: 16,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Magray Orchards',
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
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.68,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              delegate: SliverChildBuilderDelegate(
                (_, __) => _shimmerCard(),
                childCount: 6,
              ),
            ),
          );
        }
        if (pp.searchProducts.isEmpty) {
          return SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.search_off_rounded, size: 64, color: Colors.grey.shade400),
                    const SizedBox(height: 12),
                    const Text(
                      'No products found',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Try a different search term',
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        return SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.68,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
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
          slivers.add(SliverToBoxAdapter(child: _buildPromoStrip(context)));
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
      title: title,
      products: products,
      loading: loading,
      grid: section.isGrid,
      rows: section.rowCount,
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
    if (pp.brands.isEmpty) return const SizedBox.shrink();
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
    if (pp.banners.isEmpty) return const SizedBox(height: 8);
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
              (banner) => ClipRRect(
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
            )
            .toList(),
      ),
    );
  }

  Widget _buildCategoriesRail(BuildContext context) {
    final pp = context.watch<ProductProvider>();
    if (pp.categories.isEmpty) return const SizedBox.shrink();
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
              child: Text(
                ShopConfig.promoBannerTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
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
    required String title,
    required List<Product> products,
    required bool loading,
    bool grid = false,
    int rows = 1,
  }) {
    if (!loading && products.isEmpty)
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    if (loading && products.isEmpty)
      return SliverToBoxAdapter(
        child: SizedBox(
          height: 230,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: 3,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, __) => SizedBox(width: 158, child: _shimmerCard()),
          ),
        ),
      );

    final header = Padding(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w800,
            ),
          ),
          TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const ProductSearchScreen(),
              ),
            ),
            child: const Text('View all'),
          ),
        ],
      ),
    );

    if (grid) {
      // Grid: 2 items per row, `rows` rows total.
      final rowCount = rows.clamp(1, 6);
      final visible = products.take(rowCount * 2).toList();
      final cards = visible
          .map((product) => ProductCard(
                product: product,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ProductDetailScreen(product: product),
                  ),
                ),
              ))
          .toList();
      return SliverToBoxAdapter(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            header,
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                childAspectRatio: 0.62,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                children: cards,
              ),
            ),
          ],
        ),
      );
    }

    // Carousel: stack `rows` horizontal lists vertically.
    final rowCount = rows.clamp(1, 6);
    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          header,
          ...List.generate(rowCount, (rowIndex) {
            final start = rowIndex * 6;
            final end = (start + 6).clamp(0, products.length);
            final rowProducts = products.sublist(start, end);
            return SizedBox(
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
            );
          }),
        ],
      ),
    );
  }

  Widget _buildServicesSection(BuildContext context) {
    final services = context.watch<ProductProvider>().services;
    if (services.isEmpty)
      return const SliverToBoxAdapter(child: SizedBox.shrink());
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
                    width: 190,
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
                          child: Text(
                            service.name,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
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

  Widget _legacyBuild(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final tabs = [
      const _HomeTab(),
      const ReelsScreen(),
      const _ServicesTab(),
      const _CartTab(),
      const _ProfileTab(),
    ];

    return Scaffold(
      body: tabs[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        indicatorColor: primary.withValues(alpha: 0.2),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home, color: primary),
            label: 'Home',
          ),
          NavigationDestination(
            icon: const Icon(Icons.slow_motion_video_outlined),
            selectedIcon: Icon(Icons.slow_motion_video, color: primary),
            label: 'Reels',
          ),
          NavigationDestination(
            icon: const Icon(Icons.construction_outlined),
            selectedIcon: Icon(Icons.construction, color: primary),
            label: 'Services',
          ),
          NavigationDestination(
            icon: const Icon(Icons.shopping_cart_outlined),
            selectedIcon: Icon(Icons.shopping_cart, color: primary),
            label: 'Cart',
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outlined),
            selectedIcon: Icon(Icons.person, color: primary),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// HOME TAB
// ─────────────────────────────────────────────
class _HomeTab extends StatefulWidget {
  const _HomeTab();

  @override
  State<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab> {
  List<Product> _latestProducts = [];
  bool _loadingLatest = false;
  bool _dismissedSoftUpdate = false;

  // Soft update shows when installed >= min but < latest.
  bool get showSoftUpdate {
    if (_dismissedSoftUpdate) return false;
    final minV = ShopConfig.minVersion;
    final latestV = ShopConfig.latestVersion;
    if (minV.isEmpty || latestV.isEmpty || minV == latestV) return false;
    return _installedVersion != null &&
        ShopConfig.compareVersions(_installedVersion!, minV) >= 0 &&
        ShopConfig.compareVersions(_installedVersion!, latestV) < 0;
  }

  String? _installedVersion;

  Future<void> _resolveInstalledVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      _installedVersion = info.version;
    } catch (_) {}
  }

  Future<void> _openStore() async {
    final url = ShopConfig.storeUrl;
    if (url.isEmpty) return;
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  void initState() {
    super.initState();
    _resolveInstalledVersion();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final pp = context.read<ProductProvider>();
      if (pp.products.isEmpty) {
        pp.fetchProducts(isFeatured: true, page: 1);
        pp.fetchCategories();
        pp.fetchServices();
        pp.fetchBanners();
        pp.fetchOfferProducts();
        pp.fetchBrands();
      }
      _fetchLatest();
    });
  }

  Future<void> _fetchLatest() async {
    setState(() => _loadingLatest = true);
    try {
      final response = await ApiService.get(
        '/products',
        queryParams: {'sort_by': 'newest', 'page': '1'},
      );
      final envelope = response['data'];
      List<dynamic> items;
      if (envelope is Map && envelope.containsKey('data')) {
        items = envelope['data'] ?? [];
      } else if (envelope is List) {
        items = envelope;
      } else {
        items = [];
      }
      if (mounted) {
        setState(() {
          _latestProducts = items.map((p) => Product.fromJson(p)).toList();
          _loadingLatest = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadingLatest = false);
    }
  }

  Future<void> _openPromoLink(BuildContext context) async {
    final link = ShopConfig.promoBannerLink;
    if (link.isNotEmpty) {
      if (link.startsWith('http://') || link.startsWith('https://')) {
        final uri = Uri.parse(link);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          return;
        }
      } else if (link.startsWith('/')) {
        // Internal app route, e.g. /products
        switch (link) {
          case '/products':
            if (context.mounted) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProductSearchScreen()),
              );
            }
            return;
          case '/services':
            if (context.mounted) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const _ServicesTab()),
              );
            }
            return;
        }
      }
    }
    // Default: open product search
    if (context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ProductSearchScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final primaryDark = Theme.of(context).colorScheme.onPrimaryContainer;
    return RefreshIndicator(
      onRefresh: () async {
        final pp = context.read<ProductProvider>();
        await Future.wait([
          pp.fetchProducts(isFeatured: true, page: 1),
          pp.fetchCategories(),
          pp.fetchServices(),
          pp.fetchBanners(),
          pp.fetchOfferProducts(),
          pp.fetchBrands(),
          _fetchLatest(),
        ]);
      },
      child: CustomScrollView(
        slivers: [
          // ── App Bar ──
          SliverAppBar(
            expandedHeight: 56,
            pinned: true,
            floating: true,
            backgroundColor: primary,
            foregroundColor: Colors.white,
            title: Consumer<AuthProvider>(
              builder: (context, auth, _) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.eco, color: Colors.white, size: 22),
                    const SizedBox(width: 8),
                    Text(
                      'Magray Orchards',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    if (auth.user?.isProMember == true) ...[
                      const SizedBox(width: 8),
                      const ProMemberBadge(isProMember: true, compact: true),
                    ],
                  ],
                );
              },
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.search, color: Colors.white),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ProductSearchScreen(),
                  ),
                ),
              ),
            ],
          ),

          // ── 1. Announcement Bar ──
          // ── Soft Update Banner (non-forced, dismissible) ──
          if (showSoftUpdate) ...[
            SliverToBoxAdapter(
              child: Material(
                color: Colors.amber.shade50,
                child: InkWell(
                  onTap: _openStore,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.system_update_alt,
                          color: Colors.amber.shade800,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'A new version is available. Update for the latest features.',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: _openStore,
                          child: Text(
                            'Update',
                            style: TextStyle(
                              color: Colors.amber.shade900,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () =>
                              setState(() => _dismissedSoftUpdate = true),
                          child: Icon(
                            Icons.close,
                            size: 18,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],

          SliverToBoxAdapter(
            child: Container(
              width: double.infinity,
              color: Theme.of(context).colorScheme.secondaryContainer,
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.campaign,
                    color: Theme.of(context).colorScheme.onSecondaryContainer,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      ShopConfig.announcementMessage,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSecondaryContainer,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── 2. Banner Carousel ──
          Consumer<ProductProvider>(
            builder: (context, pp, _) {
              if (pp.banners.isEmpty) return const SliverToBoxAdapter();
              return SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: CarouselSlider(
                    options: CarouselOptions(
                      height: 180,
                      autoPlay: true,
                      autoPlayInterval: const Duration(seconds: 4),
                      viewportFraction: 0.92,
                      enlargeCenterPage: true,
                    ),
                    items: pp.banners.map((banner) {
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            if (banner.image != null)
                              AppNetworkImage(
                                imageUrl:
                                    '${ApiConfig.imageBaseUrl}${banner.image}',
                                fit: BoxFit.cover,
                                placeholder: (_, __) => Container(
                                  color: primary.withValues(alpha: 0.2),
                                  child: Icon(Icons.image, color: primary),
                                ),
                                errorWidget: (_, __, ___) => Container(
                                  color: primary.withValues(alpha: 0.2),
                                  child: Icon(Icons.image, color: primary),
                                ),
                              )
                            else
                              Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      primary,
                                      primary.withValues(alpha: 0.7),
                                    ],
                                  ),
                                ),
                              ),
                            if (banner.title != null)
                              Positioned(
                                bottom: 0,
                                left: 0,
                                right: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.bottomCenter,
                                      end: Alignment.topCenter,
                                      colors: [
                                        Colors.black.withValues(alpha: 0.7),
                                        Colors.transparent,
                                      ],
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        banner.title!,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      if (banner.subtitle != null)
                                        Text(
                                          banner.subtitle!,
                                          style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 12,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              );
            },
          ),

          // ── 3. Subscription / Pro Membership (hidden for guests and pro members) ──
          Consumer<AuthProvider>(
            builder: (context, auth, _) {
              final user = auth.user;
              if (!auth.isLoggedIn || user?.isProMember == true) {
                return const SliverToBoxAdapter(child: SizedBox.shrink());
              }
              final isPro = user?.isProMember == true;
              final planName = user?.currentPlan;
              return SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: isPro
                            ? [primaryDark, primary]
                            : [Theme.of(context).colorScheme.tertiary, primary],
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
                              child: const Icon(
                                Icons.workspace_premium,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isPro
                                        ? '${planName ?? 'Pro'} Member'
                                        : 'Go Pro with Magray Orchards',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 17,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    isPro
                                        ? 'You\'re enjoying premium perks'
                                        : 'Free delivery, fast support & premium content',
                                    style: TextStyle(
                                      color: Colors.white.withValues(
                                        alpha: 0.85,
                                      ),
                                      fontSize: 12,
                                    ),
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
                            onPressed: () {
                              if (!auth.isLoggedIn) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const LoginScreen(),
                                  ),
                                );
                                return;
                              }
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const SubscriptionScreen(),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: primaryDark,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: Text(
                              isPro ? 'Manage Subscription' : 'Explore Plans',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),

          // ── 4. Shop by Category ──
          const SliverToBoxAdapter(
            child: SectionHeader(title: 'Shop by Category'),
          ),
          Consumer<ProductProvider>(
            builder: (context, pp, _) {
              if (pp.categories.isEmpty) {
                return const SliverToBoxAdapter(child: SizedBox.shrink());
              }
              return SliverToBoxAdapter(
                child: SizedBox(
                  height: 120,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
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
                        child: Container(
                          width: 100,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          child: Column(
                            children: [
                              Container(
                                width: 72,
                                height: 72,
                                decoration: BoxDecoration(
                                  color: primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: cat.image != null
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(16),
                                        child: AppNetworkImage(
                                          imageUrl:
                                              '${ApiConfig.imageBaseUrl}${cat.image}',
                                          fit: BoxFit.cover,
                                          errorWidget: (_, __, ___) => Icon(
                                            Icons.category,
                                            color: primary,
                                          ),
                                        ),
                                      )
                                    : Icon(
                                        Icons.category,
                                        color: primary,
                                        size: 32,
                                      ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                cat.name,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
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
              );
            },
          ),

          // ── 5. Shop by Brand ──
          Consumer<ProductProvider>(
            builder: (context, pp, _) {
              if (pp.brands.isEmpty) {
                return const SliverToBoxAdapter(child: SizedBox.shrink());
              }
              return SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionHeader(title: 'Shop by Brand'),
                    SizedBox(
                      height: 96,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: pp.brands.length,
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
                            child: Container(
                              width: 110,
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              child: Column(
                                children: [
                                  Container(
                                    width: 64,
                                    height: 64,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: Theme.of(context).dividerColor,
                                      ),
                                    ),
                                    child: brand.logo != null
                                        ? ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                            child: AppNetworkImage(
                                              imageUrl:
                                                  '${ApiConfig.imageBaseUrl}${brand.logo}',
                                              fit: BoxFit.contain,
                                              errorWidget: (_, __, ___) => Icon(
                                                Icons.business,
                                                color: primary,
                                              ),
                                              placeholder: (_, __) => Icon(
                                                Icons.business,
                                                color: primary,
                                              ),
                                            ),
                                          )
                                        : Icon(
                                            Icons.business,
                                            color: primary,
                                            size: 30,
                                          ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    brand.name,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
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
                ),
              );
            },
          ),

          // ── 6. Today's Offers ──
          Consumer<ProductProvider>(
            builder: (context, pp, _) {
              if (!pp.offerLoading && pp.offerProducts.isEmpty) {
                return const SliverToBoxAdapter(child: SizedBox.shrink());
              }
              return const SliverToBoxAdapter(
                child: SectionHeader(title: 'Today\'s Offers'),
              );
            },
          ),
          Consumer<ProductProvider>(
            builder: (context, pp, _) {
              if (pp.offerLoading && pp.offerProducts.isEmpty) {
                return SliverToBoxAdapter(
                  child: SizedBox(
                    height: 240,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: 4,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (_, __) =>
                          SizedBox(width: 160, child: _shimmerCard()),
                    ),
                  ),
                );
              }
              if (pp.offerProducts.isEmpty) {
                return const SliverToBoxAdapter(child: SizedBox.shrink());
              }
              return SliverToBoxAdapter(
                child: SizedBox(
                  height: 260,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: pp.offerProducts.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (context, index) => SizedBox(
                      width: 160,
                      child: ProductCard(
                        product: pp.offerProducts[index],
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ProductDetailScreen(
                              product: pp.offerProducts[index],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),

          // ── 7. Offer Promo Banner ──
          if (ShopConfig.promoBannerEnabled) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color.lerp(
                              ShopConfig.promoBannerColor,
                              Colors.black,
                              0.15,
                            ) ??
                            ShopConfig.promoBannerColor,
                        ShopConfig.promoBannerColor,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.4),
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.local_fire_department,
                              color: Colors.white,
                              size: 14,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Limited Time Offer',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        ShopConfig.promoBannerTitle,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          height: 1.25,
                        ),
                      ),
                      if (ShopConfig.promoBannerSubtitle.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          ShopConfig.promoBannerSubtitle,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 13,
                          ),
                        ),
                      ],
                      const SizedBox(height: 14),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: ElevatedButton(
                          onPressed: () => _openPromoLink(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: ShopConfig.promoBannerColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text('Shop Offers'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],

          // ── 8. Featured Products ──
          const SliverToBoxAdapter(
            child: SectionHeader(title: 'Featured Products'),
          ),
          Consumer<ProductProvider>(
            builder: (context, pp, _) {
              if (pp.featuredLoading && pp.featuredProducts.isEmpty) {
                return SliverToBoxAdapter(
                  child: SizedBox(
                    height: 240,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: 6,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (_, __) =>
                          SizedBox(width: 160, child: _shimmerCard()),
                    ),
                  ),
                );
              }
              if (pp.errorMessage != null && pp.featuredProducts.isEmpty) {
                return SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.cloud_off,
                            size: 40,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            pp.errorMessage!,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextButton.icon(
                            onPressed: () {
                              pp.clearError();
                              pp.fetchProducts(isFeatured: true, page: 1);
                            },
                            icon: const Icon(Icons.refresh, size: 18),
                            label: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }
              if (pp.featuredProducts.isEmpty) {
                return const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(
                      child: Text(
                        'No products available',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  ),
                );
              }
              return SliverToBoxAdapter(
                child: SizedBox(
                  height: 260,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: pp.featuredProducts.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (context, index) => SizedBox(
                      width: 160,
                      child: ProductCard(
                        product: pp.featuredProducts[index],
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ProductDetailScreen(
                              product: pp.featuredProducts[index],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),

          // ── 9. Latest Products ──
          const SliverToBoxAdapter(
            child: SectionHeader(title: 'Latest Products'),
          ),
          if (_loadingLatest && _latestProducts.isEmpty)
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.62,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                delegate: SliverChildBuilderDelegate(
                  (_, __) => _shimmerCard(),
                  childCount: 6,
                ),
              ),
            )
          else if (_latestProducts.isEmpty)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Center(
                  child: Text(
                    'No products available',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.62,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) => ProductCard(
                    product: _latestProducts[index],
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ProductDetailScreen(
                          product: _latestProducts[index],
                        ),
                      ),
                    ),
                  ),
                  childCount: _latestProducts.length,
                ),
              ),
            ),

          // ── 10. Our Services ──
          const SliverToBoxAdapter(child: SectionHeader(title: 'Our Services')),
          Consumer<ProductProvider>(
            builder: (context, pp, _) {
              if (pp.services.isEmpty) {
                return const SliverToBoxAdapter(child: SizedBox.shrink());
              }
              return SliverToBoxAdapter(
                child: SizedBox(
                  height: 160,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: pp.services.length,
                    itemBuilder: (context, index) {
                      final service = pp.services[index];
                      return GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                ServiceDetailScreen(service: service),
                          ),
                        ),
                        child: Container(
                          width: 170,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          child: Card(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: primary.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: service.image != null
                                        ? ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            child: AppNetworkImage(
                                              imageUrl:
                                                  '${ApiConfig.imageBaseUrl}${service.image}',
                                              fit: BoxFit.cover,
                                              errorWidget: (_, __, ___) => Icon(
                                                Icons.construction,
                                                color: primary,
                                              ),
                                            ),
                                          )
                                        : Icon(
                                            Icons.construction,
                                            color: primary,
                                          ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    service.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Rs. ${service.basePrice.toStringAsFixed(0)}',
                                    style: TextStyle(
                                      color: primary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              );
            },
          ),

          // ── 11. How It Works ──
          const SliverToBoxAdapter(child: SectionHeader(title: 'How It Works')),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 170,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: const [
                  _HowItWorksCard(
                    step: 1,
                    icon: Icons.search,
                    title: 'Browse & Select',
                    desc: 'Explore our wide range of orchard essentials',
                  ),
                  _HowItWorksCard(
                    step: 2,
                    icon: Icons.shopping_bag_outlined,
                    title: 'Place Order',
                    desc: 'Add to cart and checkout with secure payment',
                  ),
                  _HowItWorksCard(
                    step: 3,
                    icon: Icons.local_shipping_outlined,
                    title: 'Fast Delivery',
                    desc: 'Get your products delivered to your doorstep',
                  ),
                ],
              ),
            ),
          ),

          // ── 12. CTA Banner ──
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [primary, primaryDark],
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Ready to Transform Your Orchard?',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Premium products and expert services for healthier orchards',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 13,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              final pp = context.read<ProductProvider>();
                              if (pp.products.isNotEmpty) {
                                Scrollable.ensureVisible(
                                  context,
                                  duration: const Duration(milliseconds: 500),
                                );
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: primary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: const Text('Shop Now'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              final pp = context.read<ProductProvider>();
                              if (pp.services.isNotEmpty) {
                                Scrollable.ensureVisible(
                                  context,
                                  duration: const Duration(milliseconds: 500),
                                );
                              }
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: Colors.white),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: const Text('Explore Services'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 16)),
        ],
      ),
    );
  }

  Widget _shimmerCard() {
    final theme = Theme.of(context);
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// HOW IT WORKS CARD
// ─────────────────────────────────────────────
class _HowItWorksCard extends StatelessWidget {
  final int step;
  final IconData icon;
  final String title;
  final String desc;

  const _HowItWorksCard({
    required this.step,
    required this.icon,
    required this.title,
    required this.desc,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      width: 160,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: primary,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '$step',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Icon(icon, color: primary, size: 24),
              const SizedBox(height: 6),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 3),
              Text(
                desc,
                style: const TextStyle(fontSize: 10, color: Colors.grey),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// CATEGORIES TAB
// ─────────────────────────────────────────────
class _CategoriesTab extends StatefulWidget {
  const _CategoriesTab();

  @override
  State<_CategoriesTab> createState() => _CategoriesTabState();
}

class _CategoriesTabState extends State<_CategoriesTab> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProductProvider>().fetchCategories();
    });
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Scaffold(
      appBar: AppBar(title: const Text('Categories')),
      body: Consumer<ProductProvider>(
        builder: (context, pp, _) {
          if (pp.isLoading && pp.categories.isEmpty) {
            return Center(child: CircularProgressIndicator(color: primary));
          }
          if (pp.categories.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.category_outlined, size: 80, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No categories available',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                ],
              ),
            );
          }
          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 1.1,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
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
                child: Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: cat.image != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: AppNetworkImage(
                                  imageUrl:
                                      '${ApiConfig.imageBaseUrl}${cat.image}',
                                  fit: BoxFit.cover,
                                  errorWidget: (_, __, ___) =>
                                      Icon(Icons.category, color: primary),
                                ),
                              )
                            : Icon(Icons.category, color: primary, size: 32),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        cat.name,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      Text(
                        '${cat.productCount} products',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────
// SERVICES TAB
// ─────────────────────────────────────────────
class _ServicesTab extends StatefulWidget {
  const _ServicesTab();

  @override
  State<_ServicesTab> createState() => _ServicesTabState();
}

class _ServicesTabState extends State<_ServicesTab> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProductProvider>().fetchServices();
    });
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Scaffold(
      appBar: AppBar(title: const Text('Services')),
      body: Consumer<ProductProvider>(
        builder: (context, pp, _) {
          if (pp.isLoading && pp.services.isEmpty) {
            return Center(child: CircularProgressIndicator(color: primary));
          }
          if (pp.services.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.construction_outlined,
                    size: 80,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'No services available',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: pp.services.length,
            itemBuilder: (context, index) {
              final service = pp.services[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  leading: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: service.image != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: AppNetworkImage(
                              imageUrl:
                                  '${ApiConfig.imageBaseUrl}${service.image}',
                              fit: BoxFit.cover,
                              errorWidget: (_, __, ___) =>
                                  Icon(Icons.construction, color: primary),
                            ),
                          )
                        : Icon(Icons.construction, color: primary),
                  ),
                  title: Text(
                    service.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(
                        service.description ?? '',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Rs. ${service.basePrice.toStringAsFixed(0)}${service.priceUnit != null ? '/${service.priceUnit}' : ''}',
                        style: TextStyle(
                          color: primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ServiceDetailScreen(service: service),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────
// CART TAB
// ─────────────────────────────────────────────
class _CartTab extends StatefulWidget {
  const _CartTab();

  @override
  State<_CartTab> createState() => _CartTabState();
}

class _CartTabState extends State<_CartTab> {
  final _pincodeController = TextEditingController();
  bool _usingDefaultPincode = false;
  bool _shippingLoading = false;
  Map<String, dynamic>? _shippingResult;

  @override
  void dispose() {
    _pincodeController.dispose();
    super.dispose();
  }

  Future<void> _fetchShipping(String pincode) async {
    if (pincode.length != 6) return;
    setState(() {
      _shippingLoading = true;
      _shippingResult = null;
    });
    try {
      final cart = context.read<CartProvider>();
      final data = await ApiService.fetchShippingRate(
        pincode: pincode,
        items: cart.toOrderItems(),
        subtotal: cart.total,
      );
      if (mounted) setState(() => _shippingResult = data);
    } catch (e) {
      if (mounted) {
        setState(
          () => _shippingResult = {
            'serviceable': false,
            'message': e is ApiException
                ? e.message
                : 'Could not check delivery',
          },
        );
      }
    }
    if (mounted) setState(() => _shippingLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final auth = context.watch<AuthProvider>();
    final primary = Theme.of(context).colorScheme.primary;
    final double freeDeliveryThreshold = ShopConfig.freeDeliveryThreshold;

    if (cart.items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.shopping_cart_outlined,
              size: 80,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 16),
            const Text(
              'Your cart is empty',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            const Text(
              'Browse products and add items',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    final subtotal = cart.total;
    final amountNeeded = freeDeliveryThreshold - subtotal;
    final freeShippingReached = amountNeeded <= 0;

    // Auto-check shipping with the default address once when logged in.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      if (_usingDefaultPincode) return;
      final authNow = context.read<AuthProvider>();
      if (!authNow.isLoggedIn) return;

      var pin = authNow.user?.defaultPincode;
      if (pin == null) {
        await authNow.loadProfile();
        if (!mounted) return;
        pin = authNow.user?.defaultPincode;
      }

      final defaultPin = pin;
      if (defaultPin != null && defaultPin.length == 6) {
        _pincodeController.text = defaultPin;
        _usingDefaultPincode = true;
        _fetchShipping(defaultPin);
      }
    });

    return Column(
      children: [
        const SizedBox(height: 40),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Cart (${cart.itemCount} items)',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton(
                onPressed: () => cart.clearCart(),
                child: const Text(
                  'Clear All',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
        ),

        // ── Free shipping progress ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: freeShippingReached
                      ? 1.0
                      : (subtotal / freeDeliveryThreshold).clamp(0.0, 1.0),
                  minHeight: 8,
                  backgroundColor: Colors.grey[200],
                  color: freeShippingReached ? Colors.green : primary,
                ),
              ),
              const SizedBox(height: 6),
              if (freeShippingReached)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.check_circle,
                      color: Colors.green,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'You\'ve unlocked free delivery!',
                      style: TextStyle(
                        color: Colors.green[700],
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                )
              else
                Text(
                  'Add Rs. ${amountNeeded.toStringAsFixed(0)} more for free delivery!',
                  style: TextStyle(
                    color: primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
        ),

        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: cart.items.length,
            itemBuilder: (context, index) {
              final item = cart.items[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: primary.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: item.product.image != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: AppNetworkImage(
                                  imageUrl:
                                      '${ApiConfig.imageBaseUrl}${item.product.image}',
                                  fit: BoxFit.cover,
                                  errorWidget: (_, __, ___) =>
                                      Icon(Icons.eco, color: primary),
                                ),
                              )
                            : Icon(Icons.eco, color: primary),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.product.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              'Rs. ${item.product.price.toStringAsFixed(0)}',
                              style: TextStyle(
                                color: primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.remove_circle_outline,
                              size: 24,
                            ),
                            onPressed: () => cart.updateQuantity(
                              item.product.id,
                              item.quantity - 1,
                            ),
                          ),
                          Text(
                            '${item.quantity}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.add_circle_outline,
                              size: 24,
                              color: primary,
                            ),
                            onPressed: () => cart.updateQuantity(
                              item.product.id,
                              item.quantity + 1,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),

        // ── Total & Checkout ──
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Shipping estimate ──
                if (_usingDefaultPincode)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.location_on_outlined,
                              size: 16,
                              color: primary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Delivering to ${_pincodeController.text}',
                              style: const TextStyle(fontSize: 13),
                            ),
                          ],
                        ),
                        GestureDetector(
                          onTap: () => setState(() {
                            _usingDefaultPincode = false;
                            _shippingResult = null;
                          }),
                          child: Text(
                            'Change',
                            style: TextStyle(
                              color: primary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _pincodeController,
                            keyboardType: TextInputType.number,
                            maxLength: 6,
                            decoration: InputDecoration(
                              hintText: 'Enter pincode',
                              counterText: '',
                              isDense: true,
                              prefixIcon: const Icon(
                                Icons.location_on_outlined,
                                size: 18,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          height: 40,
                          child: ElevatedButton(
                            onPressed: _shippingLoading
                                ? null
                                : () => _fetchShipping(
                                    _pincodeController.text.trim(),
                                  ),
                            child: _shippingLoading
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text('Check'),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (_shippingResult != null) ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Shipping',
                          style: TextStyle(color: Colors.grey, fontSize: 14),
                        ),
                        if (_shippingResult!['serviceable'] == true)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                _shippingResult!['free_delivery'] == true
                                    ? 'Free'
                                    : 'Rs. ${(_shippingResult!['delivery_charge'] ?? 0).toStringAsFixed(0)}',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color:
                                      _shippingResult!['free_delivery'] == true
                                      ? Colors.green
                                      : null,
                                ),
                              ),
                              if (_shippingResult!['estimated_days'] != null)
                                Text(
                                  'Est. ${_shippingResult!['estimated_days']} days',
                                  style: const TextStyle(
                                    color: Colors.grey,
                                    fontSize: 11,
                                  ),
                                ),
                            ],
                          )
                        else
                          Flexible(
                            child: Text(
                              _shippingResult!['message']?.toString() ??
                                  'Not serviceable',
                              style: const TextStyle(
                                color: Colors.red,
                                fontSize: 12,
                              ),
                              textAlign: TextAlign.right,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Rs. ${cart.total.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () {
                      if (!auth.isLoggedIn) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Login to place order'),
                            backgroundColor: Colors.orange,
                          ),
                        );
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const LoginScreen(),
                          ),
                        );
                        return;
                      }
                      Navigator.pushNamed(context, '/checkout');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      auth.isLoggedIn
                          ? 'Proceed to Checkout'
                          : 'Login to Checkout',
                      style: const TextStyle(fontSize: 16, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// PROFILE TAB
// ─────────────────────────────────────────────
class _ProfileTab extends StatelessWidget {
  const _ProfileTab();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    final primary = Theme.of(context).colorScheme.primary;

    if (!auth.isLoggedIn) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const SizedBox(height: 40),
            CircleAvatar(
              radius: 50,
              backgroundColor: Colors.grey.withValues(alpha: 0.2),
              child: const Icon(Icons.person, size: 50, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            const Text(
              'Guest',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const Text(
              'Login to access your account',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Login',
                  style: TextStyle(fontSize: 16, color: Colors.white),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const RegisterScreen()),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: primary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Create Account',
                  style: TextStyle(fontSize: 16, color: primary),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const SizedBox(height: 40),
          CircleAvatar(
            radius: 50,
            backgroundColor: primary.withValues(alpha: 0.1),
            child: Text(
              (user?.name ?? 'U')[0].toUpperCase(),
              style: TextStyle(fontSize: 36, color: primary),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                user?.name ?? '',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (user?.isProMember == true) ...[
                const SizedBox(width: 8),
                const ProMemberBadge(isProMember: true, compact: true),
              ],
            ],
          ),
          Text(user?.email ?? '', style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 24),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.edit, color: primary),
                  title: const Text('Edit Profile'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const EditProfileScreen(),
                    ),
                  ),
                ),
                const Divider(indent: 52),
                ListTile(
                  leading: Icon(Icons.workspace_premium, color: primary),
                  title: const Text('My Subscription'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const SubscriptionScreen(),
                    ),
                  ),
                ),
                const Divider(indent: 52),
                ListTile(
                  leading: Icon(Icons.shopping_bag, color: primary),
                  title: const Text('My Orders'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const OrdersScreen()),
                  ),
                ),
                const Divider(indent: 52),
                ListTile(
                  leading: Icon(Icons.calendar_month, color: primary),
                  title: const Text('My Bookings'),
                  subtitle: const Text('Service visits & payments'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const MyBookingsScreen()),
                  ),
                ),
                const Divider(indent: 52),
                ListTile(
                  leading: Icon(Icons.account_balance_wallet, color: primary),
                  title: const Text('My Wallet'),
                  subtitle: const Text('View balance & transactions'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const WalletScreen()),
                  ),
                ),
                const Divider(indent: 52),
                ListTile(
                  leading: Icon(Icons.notifications_none, color: primary),
                  title: const Text('Notifications'),
                  subtitle: const Text('Order updates & offers'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const NotificationsScreen()),
                  ),
                ),
                const Divider(indent: 52),
                ListTile(
                  leading: Icon(Icons.location_on, color: primary),
                  title: const Text('Addresses'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AddressScreen()),
                  ),
                ),
                const Divider(indent: 52),
                ListTile(
                  leading: Icon(Icons.favorite, color: primary),
                  title: const Text('Wishlist'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const WishlistScreen()),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => auth.logout(),
              icon: const Icon(Icons.logout, color: Colors.red),
              label: const Text('Logout', style: TextStyle(color: Colors.red)),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
