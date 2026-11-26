import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'app_loading_indicator.dart';

class AppNetworkImage extends StatelessWidget {
  final String imageUrl;
  final BoxFit fit;
  final double? width;
  final double? height;
  final Widget Function(BuildContext, String)? placeholder;
  final Widget Function(BuildContext, String, Object)? errorWidget;
  final Duration fadeInDuration;
  final int? memCacheWidth;
  final int? memCacheHeight;

  const AppNetworkImage({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.placeholder,
    this.errorWidget,
    this.fadeInDuration = const Duration(milliseconds: 300),
    this.memCacheWidth,
    this.memCacheHeight,
  });

  @override
  Widget build(BuildContext context) {
    Widget buildPlaceholder(BuildContext ctx, String url) {
      if (placeholder != null) return placeholder!(ctx, url);
      return Container(
        width: width,
        height: height,
        color: Theme.of(ctx).colorScheme.surfaceContainerHighest,
        child: const Center(child: AppLoadingIndicator.small()),
      );
    }

    Widget buildError(BuildContext ctx, String url, Object error) {
      if (errorWidget != null) return errorWidget!(ctx, url, error);
      return Container(
        width: width,
        height: height,
        color: Theme.of(ctx).colorScheme.surfaceContainerHighest,
        child: Icon(Icons.image_not_supported_outlined,
            color: Theme.of(ctx).colorScheme.onSurfaceVariant),
      );
    }

    if (kIsWeb) {
      return Image.network(
        imageUrl,
        fit: fit,
        width: width,
        height: height,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return buildPlaceholder(context, imageUrl);
        },
        errorBuilder: (context, error, stackTrace) => buildError(context, imageUrl, error),
      );
    }

    if (memCacheWidth == null && (width == null || !width!.isFinite || width!.isNaN)) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final boundedW = (constraints.hasBoundedWidth && constraints.maxWidth.isFinite && constraints.maxWidth > 0)
              ? (constraints.maxWidth * 2).round().clamp(1, 1200)
              : null;
          final boundedH = memCacheHeight ??
              ((height != null && height!.isFinite && !height!.isNaN)
                  ? (height! * 2).toInt()
                  : null);
          return CachedNetworkImage(
            imageUrl: imageUrl,
            fit: fit,
            width: width,
            height: height,
            memCacheWidth: boundedW,
            memCacheHeight: boundedH,
            fadeInDuration: fadeInDuration,
            placeholder: buildPlaceholder,
            errorWidget: buildError,
          );
        },
      );
    }

    final computedMemWidth = memCacheWidth ??
        (width != null && width!.isFinite && !width!.isNaN
            ? (width! * 2).toInt()
            : null);
    final computedMemHeight = memCacheHeight ??
        (height != null && height!.isFinite && !height!.isNaN
            ? (height! * 2).toInt()
            : null);

    return CachedNetworkImage(
      imageUrl: imageUrl,
      fit: fit,
      width: width,
      height: height,
      memCacheWidth: computedMemWidth,
      memCacheHeight: computedMemHeight,
      fadeInDuration: fadeInDuration,
      placeholder: buildPlaceholder,
      errorWidget: buildError,
    );
  }
}
