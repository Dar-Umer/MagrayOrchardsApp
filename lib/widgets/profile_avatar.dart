import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../config/api_config.dart';
import 'app_network_image.dart';

/// Circular user avatar with a pulsing round VIP glow & badge for subscribers
/// and an optional secure photo upload trigger (max 1 MB, JPG/PNG/WEBP).
class ProfileAvatar extends StatefulWidget {
  final String initial;
  final String? avatarPath;
  final Color primaryColor;
  final bool isSubscribed;
  final double radius;
  final bool isUploading;
  final Future<void> Function(XFile file)? onPickImage;

  const ProfileAvatar({
    super.key,
    required this.initial,
    this.avatarPath,
    required this.primaryColor,
    this.isSubscribed = false,
    this.radius = 50,
    this.isUploading = false,
    this.onPickImage,
  });

  @override
  State<ProfileAvatar> createState() => _ProfileAvatarState();
}

class _ProfileAvatarState extends State<ProfileAvatar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _glowController;
  late final Animation<double> _glowAnim;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _glowAnim = Tween<double>(begin: 0.45, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
    if (widget.isSubscribed) {
      _glowController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant ProfileAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSubscribed && !_glowController.isAnimating) {
      _glowController.repeat(reverse: true);
    } else if (!widget.isSubscribed && _glowController.isAnimating) {
      _glowController.stop();
    }
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  Future<void> _handlePick() async {
    if (widget.onPickImage == null || widget.isUploading) return;
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );
    if (picked != null) {
      await widget.onPickImage!(picked);
    }
  }

  Widget _buildAvatarCore(double diameter) {
    final resolvedUrl = widget.avatarPath != null && widget.avatarPath!.trim().isNotEmpty
        ? ApiConfig.resolveImageUrl(widget.avatarPath)
        : '';

    return Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: widget.primaryColor.withValues(alpha: 0.1),
      ),
      clipBehavior: Clip.antiAlias,
      child: resolvedUrl.isNotEmpty
          ? AppNetworkImage(
              imageUrl: resolvedUrl,
              fit: BoxFit.cover,
              width: diameter,
              height: diameter,
              errorWidget: (_, _, _) => Center(
                child: Text(
                  widget.initial,
                  style: TextStyle(fontSize: widget.radius * 0.72, color: widget.primaryColor),
                ),
              ),
            )
          : Center(
              child: Text(
                widget.initial,
                style: TextStyle(fontSize: widget.radius * 0.72, color: widget.primaryColor),
              ),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final diameter = widget.radius * 2;

    Widget avatarCircle = _buildAvatarCore(diameter);

    if (widget.isSubscribed) {
      avatarCircle = AnimatedBuilder(
        animation: _glowAnim,
        builder: (context, child) {
          final t = _glowAnim.value;
          return Container(
            padding: const EdgeInsets.all(3.5),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFFDE68A),
                  Color(0xFFF59E0B),
                  Color(0xFFD97706),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.35 + 0.3 * t),
                  blurRadius: 12 + 10 * t,
                  spreadRadius: 1.5 + 2.0 * t,
                ),
              ],
            ),
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
              ),
              child: child,
            ),
          );
        },
        child: avatarCircle,
      );
    }

    return SizedBox(
      width: diameter + (widget.isSubscribed ? 16 : 8),
      height: diameter + (widget.isSubscribed ? 22 : 8),
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          GestureDetector(
            onTap: widget.onPickImage != null ? _handlePick : null,
            child: avatarCircle,
          ),

          if (widget.isUploading)
            Container(
              width: diameter,
              height: diameter,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withValues(alpha: 0.45),
              ),
              child: const Center(
                child: SizedBox(
                  width: 26,
                  height: 26,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                ),
              ),
            ),

          if (widget.isSubscribed)
            Positioned(
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2.5),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white, width: 1.8),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFD97706).withValues(alpha: 0.35),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.workspace_premium_rounded, size: 11, color: Colors.white),
                    SizedBox(width: 3),
                    Text(
                      'VIP',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          if (widget.onPickImage != null)
            Positioned(
              right: 2,
              bottom: widget.isSubscribed ? 14 : 4,
              child: Material(
                color: widget.primaryColor,
                shape: const CircleBorder(
                  side: BorderSide(color: Colors.white, width: 2),
                ),
                elevation: 2,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: widget.isUploading ? null : _handlePick,
                  child: const Padding(
                    padding: EdgeInsets.all(6),
                    child: Icon(
                      Icons.camera_alt_rounded,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
