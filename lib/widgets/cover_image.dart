import '../theme/vira_colors.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../utils/helpers.dart';
import '../theme/app_theme.dart';

/// 统一的网络封面图片组件
/// 自动修复URL + Referer防盗链 + 三级缓存（内存+磁盘+网络）+ 错误占位图
class CoverImage extends StatelessWidget {
  final String? url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  const CoverImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
  });

  static ImageProvider<Object>? providerFor(String? url) {
    final request = _requestFor(url);
    if (request == null) return null;
    return CachedNetworkImageProvider(
      request.url,
      headers: request.headers,
    );
  }

  @override
  Widget build(BuildContext context) {
    final request = _requestFor(url);

    Widget image;
    if (request == null) {
      image = _placeholder(context, width, height);
    } else {
      // 从图片URL提取origin作为Referer
      image = CachedNetworkImage(
        imageUrl: request.url,
        httpHeaders: request.headers,
        width: width,
        height: height,
        fit: fit,
        memCacheWidth: 300,
        maxWidthDiskCache: 600,
        placeholder: (_, __) => _loadingPlaceholder(context, width, height),
        errorWidget: (_, __, ___) => _placeholder(context, width, height),
      );
    }

    if (borderRadius != null) {
      return ClipRRect(borderRadius: borderRadius!, child: image);
    }
    return image;
  }

  Widget _placeholder(BuildContext context, double? w, double? h) {
    return Container(
      width: w,
      height: h,
      color: context.colors.bgCard,
      child: Center(
        child: Icon(Icons.broken_image_outlined,
            color: context.colors.textMuted, size: 32),
      ),
    );
  }

  static Widget _loadingPlaceholder(
      BuildContext context, double? w, double? h) {
    return Container(
      width: w,
      height: h,
      color: context.colors.bgCard,
      child: Center(
        child: CircularProgressIndicator(
            color: AppTheme.primaryBlue, strokeWidth: 2),
      ),
    );
  }

  static _CoverRequest? _requestFor(String? url) {
    final fixedUrl = AppUtils.fixCoverUrl(url);
    if (fixedUrl == null) return null;
    try {
      final uri = Uri.parse(fixedUrl);
      return _CoverRequest(
        url: fixedUrl,
        headers: {'Referer': '${uri.scheme}://${uri.host}/'},
      );
    } catch (_) {
      return _CoverRequest(url: fixedUrl, headers: const {});
    }
  }
}

class _CoverRequest {
  final String url;
  final Map<String, String> headers;

  const _CoverRequest({required this.url, required this.headers});
}
