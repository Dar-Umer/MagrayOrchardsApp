import 'package:flutter/material.dart';
import '../widgets/app_network_image.dart';
import '../config/api_config.dart';

class ProductImageGallery extends StatefulWidget {
  final List<String> imageUrls;
  final int initialIndex;

  const ProductImageGallery({super.key, required this.imageUrls, this.initialIndex = 0});

  @override
  State<ProductImageGallery> createState() => _ProductImageGalleryState();
}

class _ProductImageGalleryState extends State<ProductImageGallery> {
  late final PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  String _imageUrl(String path) {
    if (path.startsWith('http')) return path;
    return '${ApiConfig.imageBaseUrl}$path';
  }

  @override
  Widget build(BuildContext context) {
    if (widget.imageUrls.isEmpty) {
      return Container(
        height: 320,
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.eco_rounded,
                  size: 48,
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Magray Orchards Quality Input',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade500,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 560;

        if (isWide) {
          // Big-screen layout: vertical thumbnail rail on the left, smaller
          // main image on the right.
          return ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Thumbnail rail
                SizedBox(
                  width: 72,
                  height: 360,
                  child: ListView.builder(
                    itemCount: widget.imageUrls.length,
                    itemBuilder: (context, i) {
                      final isActive = _currentIndex == i;
                      return GestureDetector(
                        onTap: () {
                          _pageController.animateToPage(i, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
                        },
                        child: Container(
                          width: 64,
                          height: 64,
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isActive ? Theme.of(context).colorScheme.primary : Colors.grey.shade200,
                              width: isActive ? 2 : 1,
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(7),
                            child: AppNetworkImage(
                              imageUrl: _imageUrl(widget.imageUrls[i]),
                              fit: BoxFit.cover,
                              errorWidget: (_, __, ___) => const Icon(Icons.image, size: 20, color: Colors.grey),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                // Main image (smaller)
                Expanded(
                  child: Container(
                    height: 360,
                    color: Colors.white,
                    child: Stack(
                      children: [
                        PageView.builder(
                          controller: _pageController,
                          itemCount: widget.imageUrls.length,
                          onPageChanged: (i) => setState(() => _currentIndex = i),
                          itemBuilder: (context, i) {
                            return GestureDetector(
                              onTap: () => _showFullScreen(i),
                              child: AppNetworkImage(
                                imageUrl: _imageUrl(widget.imageUrls[i]),
                                fit: BoxFit.contain,
                                placeholder: (_, __) => Container(color: Colors.white, child: const Center(child: CircularProgressIndicator())),
                                errorWidget: (context, url, error) => Container(
                                  color: const Color(0xFFF8FAFC),
                                  child: Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(16),
                                          decoration: BoxDecoration(
                                            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(Icons.eco_rounded, size: 44, color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.6)),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Magray Orchards',
                                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade400, letterSpacing: 0.5),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        // Mobile layout (existing): full-width main image + horizontal thumbnails
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 320,
              child: Stack(
                children: [
                  Container(
                    color: Colors.white,
                    child: PageView.builder(
                      controller: _pageController,
                      itemCount: widget.imageUrls.length,
                      onPageChanged: (i) => setState(() => _currentIndex = i),
                      itemBuilder: (context, i) {
                        return GestureDetector(
                          onTap: () => _showFullScreen(i),
                          child: AppNetworkImage(
                            imageUrl: _imageUrl(widget.imageUrls[i]),
                            fit: BoxFit.contain,
                            placeholder: (_, __) => Container(color: Colors.white, child: const Center(child: CircularProgressIndicator())),
                            errorWidget: (context, url, error) => Container(
                              color: const Color(0xFFF8FAFC),
                              child: Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(18),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.eco_rounded,
                                        size: 46,
                                        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.6),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Magray Orchards Quality Input',
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey.shade400,
                                        letterSpacing: 0.3,
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
                  if (widget.imageUrls.length > 1)
                    Positioned(
                      bottom: 12,
                      left: 0, right: 0,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(widget.imageUrls.length, (i) {
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: _currentIndex == i ? 24 : 8,
                            height: 8,
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            decoration: BoxDecoration(
                              color: _currentIndex == i ? Theme.of(context).colorScheme.primary : Colors.grey.withValues(alpha: 0.4),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          );
                        }),
                      ),
                    ),
                ],
              ),
            ),
            if (widget.imageUrls.length > 1)
              SizedBox(
                height: 68,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  itemCount: widget.imageUrls.length,
                  itemBuilder: (context, i) {
                    final isActive = _currentIndex == i;
                    return GestureDetector(
                      onTap: () {
                        _pageController.animateToPage(i, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
                      },
                      child: Container(
                        width: 56,
                        height: 56,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isActive ? Theme.of(context).colorScheme.primary : Colors.grey.shade200,
                            width: isActive ? 2 : 1,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(7),
                          child: AppNetworkImage(
                            imageUrl: _imageUrl(widget.imageUrls[i]),
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => const Icon(Icons.image, size: 20, color: Colors.grey),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }

  void _showFullScreen(int initialIndex) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => _FullScreenGallery(
        imageUrls: widget.imageUrls.map(_imageUrl).toList(),
        initialIndex: initialIndex,
      ),
    ));
  }
}

class _FullScreenGallery extends StatefulWidget {
  final List<String> imageUrls;
  final int initialIndex;
  const _FullScreenGallery({required this.imageUrls, this.initialIndex = 0});

  @override
  State<_FullScreenGallery> createState() => _FullScreenGalleryState();
}

class _FullScreenGalleryState extends State<_FullScreenGallery> {
  late final PageController _controller;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _controller = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('${_index + 1} / ${widget.imageUrls.length}', style: const TextStyle(fontSize: 16)),
      ),
      body: PageView.builder(
        controller: _controller,
        itemCount: widget.imageUrls.length,
        onPageChanged: (i) => setState(() => _index = i),
        itemBuilder: (context, i) {
          return InteractiveViewer(
            minScale: 0.5,
            maxScale: 4.0,
            child: Center(
              child: AppNetworkImage(
                imageUrl: widget.imageUrls[i],
                fit: BoxFit.contain,
                errorWidget: (_, __, ___) => const Icon(Icons.broken_image, color: Colors.white54, size: 48),
              ),
            ),
          );
        },
      ),
    );
  }
}
