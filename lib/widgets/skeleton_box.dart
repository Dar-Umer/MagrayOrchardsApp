import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// Standard shimmer palette tailored for clean, modern e-commerce UI.
class AppShimmerTheme {
  AppShimmerTheme._();

  static Color baseColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? const Color(0xFF2D2F33) : const Color(0xFFE8E9EC);
  }

  static Color highlightColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? const Color(0xFF3F4248) : const Color(0xFFF7F8FA);
  }
}

/// A flexible, reusable shimmer container with configurable shape and radius.
class ShimmerBox extends StatelessWidget {
  final double? width;
  final double? height;
  final double borderRadius;
  final BoxShape shape;
  final EdgeInsetsGeometry? margin;

  const ShimmerBox({
    super.key,
    this.width,
    this.height,
    this.borderRadius = 8,
    this.shape = BoxShape.rectangle,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        color: AppShimmerTheme.baseColor(context),
        shape: shape,
        borderRadius:
            shape == BoxShape.circle ? null : BorderRadius.circular(borderRadius),
      ),
    );
  }
}

/// Animated shimmer placeholder card mirroring the exact dimensions, borders,
/// and layout of the real [ProductCard].
class ShimmerProductCard extends StatelessWidget {
  final double? width;

  const ShimmerProductCard({super.key, this.width});

  @override
  Widget build(BuildContext context) {
    final base = AppShimmerTheme.baseColor(context);
    final highlight = AppShimmerTheme.highlightColor(context);

    return Container(
      width: width,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Shimmer.fromColors(
        baseColor: base,
        highlightColor: highlight,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Product Image Placeholder ──
            Expanded(
              flex: 5,
              child: Container(
                width: double.infinity,
                color: base,
              ),
            ),

            // ── Details Section ──
            Expanded(
              flex: 5,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Brand chip placeholder
                    Container(
                      height: 10,
                      width: 50,
                      decoration: BoxDecoration(
                        color: base,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 6),

                    // Title line 1
                    Container(
                      height: 12,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: base,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 4),

                    // Title line 2
                    Container(
                      height: 12,
                      width: 85,
                      decoration: BoxDecoration(
                        color: base,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const Spacer(),

                    // Price & MRP row
                    Row(
                      children: [
                        Container(
                          height: 14,
                          width: 55,
                          decoration: BoxDecoration(
                            color: base,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          height: 10,
                          width: 35,
                          decoration: BoxDecoration(
                            color: base,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Add to Cart Button Skeleton
                    Container(
                      height: 28,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: base,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Animated shimmer skeleton for the home banner carousel.
class ShimmerBannerCarousel extends StatelessWidget {
  const ShimmerBannerCarousel({super.key});

  @override
  Widget build(BuildContext context) {
    final base = AppShimmerTheme.baseColor(context);
    final highlight = AppShimmerTheme.highlightColor(context);
    final primary = Theme.of(context).colorScheme.primary;

    return Container(
      color: primary,
      padding: const EdgeInsets.only(bottom: 14, top: 2),
      child: Shimmer.fromColors(
        baseColor: base,
        highlightColor: highlight,
        child: Container(
          height: 152,
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
    );
  }
}

/// Animated shimmer skeleton for the 2-row categories rail.
class ShimmerCategoriesRail extends StatelessWidget {
  const ShimmerCategoriesRail({super.key});

  @override
  Widget build(BuildContext context) {
    final base = AppShimmerTheme.baseColor(context);
    final highlight = AppShimmerTheme.highlightColor(context);

    return Container(
      color: Colors.white,
      height: 190,
      padding: const EdgeInsets.only(top: 12, bottom: 4),
      child: Shimmer.fromColors(
        baseColor: base,
        highlightColor: highlight,
        child: GridView.builder(
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisExtent: 90,
            mainAxisSpacing: 5,
            crossAxisSpacing: 2,
          ),
          itemCount: 8,
          itemBuilder: (_, _) => Column(
            children: [
              Container(
                width: 62,
                height: 62,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                height: 10,
                width: 52,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Animated shimmer skeleton for the Brand rail.
class ShimmerBrandRail extends StatelessWidget {
  const ShimmerBrandRail({super.key});

  @override
  Widget build(BuildContext context) {
    final base = AppShimmerTheme.baseColor(context);
    final highlight = AppShimmerTheme.highlightColor(context);

    return Shimmer.fromColors(
      baseColor: base,
      highlightColor: highlight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 20, 18, 8),
            child: Container(
              height: 20,
              width: 140,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ),
          SizedBox(
            height: 96,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: 5,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (_, _) => Column(
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    height: 10,
                    width: 48,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Animated shimmer skeleton for the Orchard Services rail.
class ShimmerServicesRail extends StatelessWidget {
  const ShimmerServicesRail({super.key});

  @override
  Widget build(BuildContext context) {
    final base = AppShimmerTheme.baseColor(context);
    final highlight = AppShimmerTheme.highlightColor(context);

    return Shimmer.fromColors(
      baseColor: base,
      highlightColor: highlight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 22, 18, 10),
            child: Container(
              height: 20,
              width: 160,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ),
          SizedBox(
            height: 116,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: 3,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, _) => Container(
                width: 190,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Animated shimmer skeleton for product sections (header + horizontal rail or responsive grid).
class ShimmerProductSection extends StatelessWidget {
  final String? title;
  final String layout;

  const ShimmerProductSection({
    super.key,
    this.title,
    this.layout = 'carousel',
  });

  @override
  Widget build(BuildContext context) {
    final base = AppShimmerTheme.baseColor(context);
    final highlight = AppShimmerTheme.highlightColor(context);

    final header = Padding(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
      child: Shimmer.fromColors(
        baseColor: base,
        highlightColor: highlight,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              height: 22,
              width: title != null && title!.isNotEmpty
                  ? (title!.length * 10.0).clamp(90.0, 200.0)
                  : 150,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            Container(
              height: 16,
              width: 60,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ],
        ),
      ),
    );

    if (layout == 'grid') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          header,
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 215,
                mainAxisExtent: 296,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: 4,
              itemBuilder: (_, _) => const ShimmerProductCard(),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        header,
        SizedBox(
          height: 290,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: 4,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, _) => const SizedBox(
              width: 158,
              child: ShimmerProductCard(),
            ),
          ),
        ),
      ],
    );
  }
}

/// Animated shimmer skeleton list for order, booking, and wallet lists.
class ShimmerCardList extends StatelessWidget {
  final int itemCount;
  final double itemHeight;

  const ShimmerCardList({
    super.key,
    this.itemCount = 5,
    this.itemHeight = 112,
  });

  @override
  Widget build(BuildContext context) {
    final base = AppShimmerTheme.baseColor(context);
    final highlight = AppShimmerTheme.highlightColor(context);

    return Shimmer.fromColors(
      baseColor: base,
      highlightColor: highlight,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        physics: const NeverScrollableScrollPhysics(),
        itemCount: itemCount,
        itemBuilder: (_, _) => Container(
          height: itemHeight,
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}
