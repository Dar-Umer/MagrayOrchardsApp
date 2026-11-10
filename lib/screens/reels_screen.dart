import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import '../models/reel.dart';
import '../providers/reels_provider.dart';
import '../providers/auth_provider.dart';
import '../utils/formatters.dart';
import 'login_screen.dart';
import 'product_detail_screen.dart';
import 'reels_comments_sheet.dart';

class ReelsScreen extends StatefulWidget {
  const ReelsScreen({super.key});

  @override
  State<ReelsScreen> createState() => _ReelsScreenState();
}

class _ReelsScreenState extends State<ReelsScreen> {
  late final PageController _pageController;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ReelsProvider>().fetchReels(refresh: true);
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() => _currentIndex = index);
    final provider = context.read<ReelsProvider>();
    if (index >= provider.reels.length - 2 && provider.hasMore) {
      provider.fetchReels();
    }
  }

  Future<bool> _ensureLoggedIn() async {
    final auth = context.read<AuthProvider>();
    if (auth.isLoggedIn) return true;
    final goToLogin = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Login required'),
        content: const Text('Please login to like or comment on reels.'),
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
    return false;
  }

  void _buyNow(Reel reel) {
    final product = reel.product;
    if (product == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ProductDetailScreen(product: product)),
    );
  }

  void _openComments(Reel reel) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => ReelsCommentsSheet(reelId: reel.id),
    );
  }

  @override
  Widget build(BuildContext context) {
    final reelsProvider = context.watch<ReelsProvider>();

    if (reelsProvider.isLoading && reelsProvider.reels.isEmpty) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (reelsProvider.reels.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Reels')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.video_library_outlined,
                  size: 64, color: Colors.grey),
              const SizedBox(height: 12),
              const Text('No reels yet',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text('Check back soon for new videos',
                  style: TextStyle(color: Colors.grey.shade500)),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: PageView.builder(
        controller: _pageController,
        scrollDirection: Axis.vertical,
        onPageChanged: _onPageChanged,
        itemCount: reelsProvider.reels.length,
        itemBuilder: (context, index) {
          final reel = reelsProvider.reels[index];
          return _ReelView(
            reel: reel,
            isActive: index == _currentIndex,
            onLike: () => _ensureLoggedIn().then((ok) {
              if (ok) context.read<ReelsProvider>().toggleLike(reel);
            }),
            onComment: () => _ensureLoggedIn().then((ok) {
              if (ok) _openComments(reel);
            }),
            onBuyNow: () => _buyNow(reel),
          );
        },
      ),
    );
  }
}

class _ReelView extends StatefulWidget {
  final Reel reel;
  final bool isActive;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback onBuyNow;

  const _ReelView({
    required this.reel,
    required this.isActive,
    required this.onLike,
    required this.onComment,
    required this.onBuyNow,
  });

  @override
  State<_ReelView> createState() => _ReelViewState();
}

class _ReelViewState extends State<_ReelView> {
  VideoPlayerController? _controller;
  ChewieController? _chewieController;
  YoutubePlayerController? _youtubeController;
  bool _muted = false;

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  Future<void> _initVideo() async {
    if (widget.reel.isYouTube) {
      final videoId = _extractYoutubeId(widget.reel.videoUrl ?? '');
      if (videoId != null) {
        _youtubeController = YoutubePlayerController.fromVideoId(
          videoId: videoId,
          autoPlay: true,
          params: const YoutubePlayerParams(
            showControls: true,
            showFullscreenButton: true,
            loop: true,
          ),
        );
      }
    } else {
      final url = widget.reel.videoUrl;
      if (url != null && url.isNotEmpty) {
        _controller = VideoPlayerController.networkUrl(Uri.parse(url));
        await _controller!.initialize();
        _chewieController = ChewieController(
          videoPlayerController: _controller!,
          autoPlay: true,
          looping: true,
          allowMuting: true,
          allowPlaybackSpeedChanging: false,
          allowFullScreen: true,
          showControls: true,
        );
      }
    }
    if (mounted) setState(() {});
  }

  String? _extractYoutubeId(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return null;
    // youtu.be/{id}
    if (uri.host == 'youtu.be') {
      final seg = uri.pathSegments.isNotEmpty ? uri.pathSegments.first : null;
      return seg != null && seg.isNotEmpty ? seg : null;
    }
    // youtube.com/watch?v={id}
    final v = uri.queryParameters['v'];
    if (v != null && v.isNotEmpty) return v;
    // youtube.com/embed/{id} or /shorts/{id}
    if (uri.host.contains('youtube.com') && uri.pathSegments.isNotEmpty) {
      final last = uri.pathSegments.last;
      if (last.isNotEmpty && last.length == 11) return last;
    }
    return null;
  }

  @override
  void didUpdateWidget(covariant _ReelView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isActive && !widget.isActive) {
      _youtubeController?.pauseVideo();
      _chewieController?.pause();
    } else if (!oldWidget.isActive && widget.isActive) {
      _youtubeController?.playVideo();
      _chewieController?.play();
    }
  }

  @override
  void dispose() {
    _youtubeController?.close();
    _chewieController?.dispose();
    _controller?.dispose();
    super.dispose();
  }

  void _toggleMute() {
    setState(() => _muted = !_muted);
    if (widget.reel.isYouTube) {
      if (_muted) {
        _youtubeController?.mute();
      } else {
        _youtubeController?.unMute();
      }
    } else {
      _controller?.setVolume(_muted ? 0 : 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final reel = widget.reel;
    final product = reel.product;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Video
        Positioned.fill(
          child: Center(
            child: _buildVideo(),
          ),
        ),

        // Gradient for readability
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.black45, Colors.transparent, Colors.black54],
            ),
          ),
        ),

        // Top mute button
        Positioned(
          top: MediaQuery.of(context).padding.top + 8,
          right: 12,
          child: _transparentButton(
            icon: _muted ? Icons.volume_off : Icons.volume_up,
            onTap: _toggleMute,
          ),
        ),

        // Right action rail
        Positioned(
          right: 10,
          bottom: 90,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _actionButton(
                icon: reel.isLiked ? Icons.favorite : Icons.favorite_border,
                color: reel.isLiked ? Colors.redAccent : Colors.white,
                label: _formatCount(reel.likesCount),
                onTap: widget.onLike,
              ),
              const SizedBox(height: 18),
              _actionButton(
                icon: Icons.chat_bubble_outline,
                label: _formatCount(reel.commentsCount),
                onTap: widget.onComment,
              ),
              const SizedBox(height: 18),
              _actionButton(
                icon: Icons.share_outlined,
                label: 'Share',
                onTap: () {},
              ),
            ],
          ),
        ),

        // Bottom: caption + Buy Now
        Positioned(
          left: 14,
          right: 14,
          bottom: MediaQuery.of(context).padding.bottom + 16,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (product != null)
                GestureDetector(
                  onTap: widget.onBuyNow,
                  child: Row(
                    children: [
                      _transparentButton(
                        icon: Icons.shopping_bag_outlined,
                        onTap: widget.onBuyNow,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          product.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: scheme.secondary,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Buy Now · ${formatCurrency(product.price)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 10),
              Text(
                reel.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (reel.description != null && reel.description!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  reel.description!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 13,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildVideo() {
    if (widget.reel.isYouTube) {
      if (_youtubeController == null) {
        return const Center(child: CircularProgressIndicator(color: Colors.white));
      }
      return YoutubePlayer(controller: _youtubeController!);
    }

    if (_chewieController != null) {
      return Chewie(controller: _chewieController!);
    }

    return const Center(child: CircularProgressIndicator(color: Colors.white));
  }

  Widget _transparentButton({required IconData icon, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: const BoxDecoration(
          color: Colors.black38,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    Color? color,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Icon(icon, color: color ?? Colors.white, size: 32, shadows: const [
            Shadow(color: Colors.black54, blurRadius: 4),
          ]),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
            ),
          ),
        ],
      ),
    );
  }

  String _formatCount(int count) {
    if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(count >= 10000 ? 0 : 1)}k';
    }
    return '$count';
  }
}
