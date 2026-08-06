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
        height: 300,
        color: Colors.grey.shade100,
        child: const Center(child: Icon(Icons.image_not_supported, size: 64, color: Colors.grey)),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 350,
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
                      fit: BoxFit.cover,
                      width: double.infinity,
                      placeholder: (_, __) => Container(color: Colors.grey.shade100, child: const Center(child: CircularProgressIndicator())),
                      errorWidget: (_, __, ___) => Container(color: Colors.grey.shade100, child: const Icon(Icons.image_not_supported, size: 48, color: Colors.grey)),
                    ),
                  );
                },
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
                          color: _currentIndex == i ? Theme.of(context).colorScheme.primary : Colors.white.withValues(alpha: 0.7),
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
