import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Shared image loader that keeps decode size close to the on-screen size.
///
/// Without [cacheWidth]/[memCacheWidth], Flutter decodes full-resolution
/// assets/network files (often multi‑MB PNGs) into GPU textures even when the
/// widget is only 72×72 — which is what makes template/material screens hitch.
class AppImage {
  const AppImage._();

  static int _px(BuildContext context, double logical) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return (logical * dpr).round().clamp(1, 4096);
  }

  /// Local asset, decoded only as large as [width]/[height] need.
  static Widget asset(
    BuildContext context,
    String path, {
    double? width,
    double? height,
    BoxFit fit = BoxFit.cover,
    Widget Function(BuildContext, Object, StackTrace?)? errorBuilder,
  }) {
    final cacheW = width != null ? _px(context, width) : null;
    final cacheH = height != null ? _px(context, height) : null;

    return Image.asset(
      path,
      width: width,
      height: height,
      fit: fit,
      cacheWidth: cacheW,
      cacheHeight: cacheH,
      filterQuality: FilterQuality.medium,
      errorBuilder: errorBuilder,
    );
  }

  /// Remote image with disk cache + memory decode limits.
  static Widget network(
    BuildContext context,
    String url, {
    double? width,
    double? height,
    BoxFit fit = BoxFit.cover,
    Widget? placeholder,
    Widget? error,
  }) {
    final cacheW = width != null ? _px(context, width) : null;
    final cacheH = height != null ? _px(context, height) : null;

    return CachedNetworkImage(
      imageUrl: url,
      width: width,
      height: height,
      fit: fit,
      memCacheWidth: cacheW,
      memCacheHeight: cacheH,
      fadeInDuration: const Duration(milliseconds: 150),
      placeholder: (context, url) =>
          placeholder ??
          ColoredBox(
            color: Colors.black12,
            child: Center(
              child: SizedBox(
                width: (width ?? 24) * 0.4,
                height: (height ?? 24) * 0.4,
                child: const CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
      errorWidget: (context, url, err) =>
          error ??
          const ColoredBox(
            color: Colors.black12,
            child: Icon(Icons.broken_image_outlined, size: 18),
          ),
    );
  }
}
