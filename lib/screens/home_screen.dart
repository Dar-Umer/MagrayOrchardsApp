import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/app_network_image.dart';
import '../providers/auth_provider.dart';
import '../providers/product_provider.dart';
import '../providers/cart_provider.dart';
import '../config/api_config.dart';
import '../models/product.dart';
import '../services/api_service.dart';
import '../services/shop_config.dart';
import 'login_screen.dart';
import 'register_screen.dart';
import 'product_detail_screen.dart';
import 'service_detail_screen.dart';
import 'category_products_screen.dart';
import 'brand_products_screen.dart';
import 'product_search_screen.dart';
import 'edit_profile_screen.dart';
import 'orders_screen.dart';
import 'address_screen.dart';
import 'wishlist_screen.dart';
import 'subscription_screen.dart';
import 'wallet_screen.dart';
import 'my_bookings_screen.dart';
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

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final tabs = [
      const _HomeTab(),
      const _CategoriesTab(),
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
              label: 'Home'),
          NavigationDestination(
              icon: const Icon(Icons.category_outlined),
              selectedIcon: Icon(Icons.category, color: primary),
              label: 'Categories'),
          NavigationDestination(
              icon: const Icon(Icons.construction_outlined),
              selectedIcon: Icon(Icons.construction, color: primary),
              label: 'Services'),
          NavigationDestination(
              icon: const Icon(Icons.shopping_cart_outlined),
              selectedIcon: Icon(Icons.shopping_cart, color: primary),
              label: 'Cart'),
          NavigationDestination(
              icon: const Icon(Icons.person_outlined),
              selectedIcon: Icon(Icons.person, color: primary),
              label: 'Profile'),
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
      final response = await ApiService.get('/products',
          queryParams: {'sort_by': 'newest', 'page': '1'});
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
                MaterialPageRoute(
                    builder: (_) => const ProductSearchScreen()),
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
                    Text('Magray Orchards',
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, color: Colors.white)),
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
                      builder: (_) => const ProductSearchScreen()),
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
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: Row(
                      children: [
                        Icon(Icons.system_update_alt, color: Colors.amber.shade800, size: 20),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'A new version is available. Update for the latest features.',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                          ),
                        ),
                        GestureDetector(
                          onTap: _openStore,
                          child: Text('Update',
                              style: TextStyle(
                                  color: Colors.amber.shade900,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13)),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => setState(() => _dismissedSoftUpdate = true),
                          child: Icon(Icons.close, size: 18, color: Colors.grey.shade600),
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
                  Icon(Icons.campaign,
                      color: Theme.of(context).colorScheme.onSecondaryContainer,
                      size: 16),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      ShopConfig.announcementMessage,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: Theme.of(context)
                              .colorScheme
                              .onSecondaryContainer,
                          fontSize: 13,
                          fontWeight: FontWeight.w600),
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
                                      Text(banner.title!,
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold)),
                                      if (banner.subtitle != null)
                                        Text(banner.subtitle!,
                                            style: const TextStyle(
                                                color: Colors.white70,
                                                fontSize: 12)),
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

          // ── 3. Subscription / Pro Membership (hidden for pro members) ──
          Consumer<AuthProvider>(
            builder: (context, auth, _) {
              final user = auth.user;
              if (user?.isProMember == true) {
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
                              child: const Icon(Icons.workspace_premium,
                                  color: Colors.white),
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
                                        fontWeight: FontWeight.w700),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    isPro
                                        ? 'You\'re enjoying premium perks'
                                        : 'Free delivery, fast support & premium content',
                                    style: TextStyle(
                                        color: Colors.white.withValues(
                                            alpha: 0.85),
                                        fontSize: 12),
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
                                      builder: (_) => const LoginScreen()),
                                );
                                return;
                              }
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        const SubscriptionScreen()),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: primaryDark,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                            ),
                            child: Text(isPro
                                ? 'Manage Subscription'
                                : 'Explore Plans'),
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
                                        borderRadius:
                                            BorderRadius.circular(16),
                                        child: AppNetworkImage(
                                          imageUrl:
                                              '${ApiConfig.imageBaseUrl}${cat.image}',
                                          fit: BoxFit.cover,
                                          errorWidget: (_, __, ___) =>
                                              Icon(Icons.category,
                                                  color: primary),
                                        ),
                                      )
                                    : Icon(Icons.category,
                                        color: primary, size: 32),
                              ),
                              const SizedBox(height: 8),
                              Text(cat.name,
                                  style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center),
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
                                          color: Theme.of(context).dividerColor),
                                    ),
                                    child: brand.logo != null
                                        ? ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(16),
                                            child: AppNetworkImage(
                                              imageUrl:
                                                  '${ApiConfig.imageBaseUrl}${brand.logo}',
                                              fit: BoxFit.contain,
                                              errorWidget: (_, __, ___) => Icon(
                                                  Icons.business,
                                                  color: primary),
                                              placeholder: (_, __) => Icon(
                                                  Icons.business,
                                                  color: primary),
                                            ),
                                          )
                                        : Icon(Icons.business,
                                            color: primary, size: 30),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    brand.name,
                                    style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500),
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
                                  product: pp.offerProducts[index])),
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
                                0.15) ??
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
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.4)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.local_fire_department,
                                color: Colors.white, size: 14),
                            SizedBox(width: 4),
                            Text('Limited Time Offer',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600)),
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
                              fontSize: 13),
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
                                borderRadius: BorderRadius.circular(14)),
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
                      itemBuilder: (_, __) => SizedBox(width: 160, child: _shimmerCard()),
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
                          Icon(Icons.cloud_off, size: 40, color: Colors.grey[400]),
                          const SizedBox(height: 8),
                          Text(
                            pp.errorMessage!,
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey[600], fontSize: 13),
                          ),
                          const SizedBox(height: 12),
                          TextButton.icon(
                            onPressed: () { pp.clearError(); pp.fetchProducts(isFeatured: true, page: 1); },
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
                        child: Text('No products available',
                            style: TextStyle(color: Colors.grey))),
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
                    itemBuilder: (context, index) =>
                        SizedBox(
                          width: 160,
                          child: ProductCard(
                            product: pp.featuredProducts[index],
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => ProductDetailScreen(
                                      product: pp.featuredProducts[index])),
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
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
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
                    child: Text('No products available',
                        style: TextStyle(color: Colors.grey))),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverGrid(
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.62,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) =>
                      ProductCard(
                        product: _latestProducts[index],
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => ProductDetailScreen(
                                  product: _latestProducts[index])),
                        ),
                      ),
                  childCount: _latestProducts.length,
                ),
              ),
            ),

          // ── 10. Our Services ──
          const SliverToBoxAdapter(
            child: SectionHeader(title: 'Our Services'),
          ),
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
                            builder: (_) => ServiceDetailScreen(
                                service: service),
                          ),
                        ),
                        child: Container(
                          width: 170,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          child: Card(
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
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
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            child: AppNetworkImage(
                                              imageUrl:
                                                  '${ApiConfig.imageBaseUrl}${service.image}',
                                              fit: BoxFit.cover,
                                              errorWidget: (_, __, ___) =>
                                                  Icon(Icons.construction,
                                                      color: primary),
                                            ),
                                          )
                                        : Icon(Icons.construction,
                                            color: primary),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(service.name,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 12),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.center),
                                  const SizedBox(height: 4),
                                  Text(
                                      'Rs. ${service.basePrice.toStringAsFixed(0)}',
                                      style: TextStyle(
                                          color: primary,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12)),
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
          const SliverToBoxAdapter(
            child: SectionHeader(title: 'How It Works'),
          ),
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
                    colors: [
                      primary,
                      primaryDark,
                    ],
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
                          fontWeight: FontWeight.w700),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Premium products and expert services for healthier orchards',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 13),
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
                                  borderRadius: BorderRadius.circular(14)),
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
                                  borderRadius: BorderRadius.circular(14)),
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
                  child: Text('$step',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15)),
                ),
              ),
              const SizedBox(height: 8),
              Icon(icon, color: primary, size: 24),
              const SizedBox(height: 6),
              Text(title,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center),
              const SizedBox(height: 3),
              Text(desc,
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
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
            return Center(
                child: CircularProgressIndicator(color: primary));
          }
          if (pp.categories.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.category_outlined, size: 80, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No categories available',
                      style: TextStyle(fontSize: 18, color: Colors.grey)),
                ],
              ),
            );
          }
          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
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
                      borderRadius: BorderRadius.circular(12)),
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
                            : Icon(Icons.category,
                                color: primary, size: 32),
                      ),
                      const SizedBox(height: 8),
                      Text(cat.name,
                          style: const TextStyle(
                              fontWeight: FontWeight.w500)),
                      Text('${cat.productCount} products',
                          style: const TextStyle(
                              color: Colors.grey, fontSize: 12)),
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
            return Center(
                child: CircularProgressIndicator(color: primary));
          }
          if (pp.services.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.construction_outlined,
                      size: 80, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No services available',
                      style: TextStyle(fontSize: 18, color: Colors.grey)),
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
                    borderRadius: BorderRadius.circular(12)),
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
                                  Icon(Icons.construction,
                                      color: primary),
                            ),
                          )
                        : Icon(Icons.construction, color: primary),
                  ),
                  title: Text(service.name,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(service.description ?? '',
                          maxLines: 2, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      Text(
                          'Rs. ${service.basePrice.toStringAsFixed(0)}${service.priceUnit != null ? '/${service.priceUnit}' : ''}',
                          style: TextStyle(
                              color: primary, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          ServiceDetailScreen(service: service),
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
        setState(() => _shippingResult = {
          'serviceable': false,
          'message': e is ApiException ? e.message : 'Could not check delivery',
        });
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
            Icon(Icons.shopping_cart_outlined,
                size: 80, color: Colors.grey[300]),
            const SizedBox(height: 16),
            const Text('Your cart is empty',
                style: TextStyle(fontSize: 18, color: Colors.grey)),
            const SizedBox(height: 8),
            const Text('Browse products and add items',
                style: TextStyle(color: Colors.grey)),
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
              Text('Cart (${cart.itemCount} items)',
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.bold)),
              TextButton(
                onPressed: () => cart.clearCart(),
                child: const Text('Clear All',
                    style: TextStyle(color: Colors.red)),
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
                    const Icon(Icons.check_circle,
                        color: Colors.green, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      'You\'ve unlocked free delivery!',
                      style: TextStyle(
                          color: Colors.green[700],
                          fontSize: 12,
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                )
              else
                Text(
                  'Add Rs. ${amountNeeded.toStringAsFixed(0)} more for free delivery!',
                  style: TextStyle(
                      color: primary, fontSize: 12, fontWeight: FontWeight.w600),
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
                    borderRadius: BorderRadius.circular(12)),
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
                            Text(item.product.name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                            Text(
                                'Rs. ${item.product.price.toStringAsFixed(0)}',
                                style: TextStyle(
                                    color: primary,
                                    fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline,
                                size: 24),
                            onPressed: () => cart.updateQuantity(
                                item.product.id, item.quantity - 1),
                          ),
                          Text('${item.quantity}',
                              style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold)),
                          IconButton(
                            icon: Icon(Icons.add_circle_outline,
                                size: 24, color: primary),
                            onPressed: () => cart.updateQuantity(
                                item.product.id, item.quantity + 1),
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
                            Icon(Icons.location_on_outlined,
                                size: 16, color: primary),
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
                          child: Text('Change',
                              style: TextStyle(
                                  color: primary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600)),
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
                                  size: 18),
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10)),
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
                                    _pincodeController.text.trim()),
                            child: _shippingLoading
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white),
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
                        const Text('Shipping',
                            style: TextStyle(color: Colors.grey, fontSize: 14)),
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
                                            : null),
                              ),
                              if (_shippingResult!['estimated_days'] != null)
                                Text(
                                  'Est. ${_shippingResult!['estimated_days']} days',
                                  style: const TextStyle(
                                      color: Colors.grey, fontSize: 11),
                                ),
                            ],
                          )
                        else
                          Flexible(
                            child: Text(
                              _shippingResult!['message']?.toString() ??
                                  'Not serviceable',
                              style: const TextStyle(
                                  color: Colors.red, fontSize: 12),
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
                    const Text('Total',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    Text('Rs. ${cart.total.toStringAsFixed(0)}',
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: primary)),
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
                              builder: (_) => const LoginScreen()),
                        );
                        return;
                      }
                      Navigator.pushNamed(context, '/checkout');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primary,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      auth.isLoggedIn
                          ? 'Proceed to Checkout'
                          : 'Login to Checkout',
                      style: const TextStyle(
                          fontSize: 16, color: Colors.white),
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
            const Text('Guest',
                style:
                    TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const Text('Login to access your account',
                style: TextStyle(color: Colors.grey)),
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
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Login',
                    style: TextStyle(fontSize: 16, color: Colors.white)),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const RegisterScreen()),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: primary),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: Text('Create Account',
                    style: TextStyle(fontSize: 16, color: primary)),
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
              Text(user?.name ?? '',
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.bold)),
              if (user?.isProMember == true) ...[
                const SizedBox(width: 8),
                const ProMemberBadge(isProMember: true, compact: true),
              ],
            ],
          ),
          Text(user?.email ?? '',
              style: const TextStyle(color: Colors.grey)),
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
                        builder: (_) => const EditProfileScreen()),
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
                        builder: (_) => const SubscriptionScreen()),
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
                    MaterialPageRoute(
                        builder: (_) => const MyBookingsScreen()),
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
              label: const Text('Logout',
                  style: TextStyle(color: Colors.red)),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
