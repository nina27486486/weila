/// 通用工具函数
class AppUtils {
  /// 时间格式化（刚刚、x分钟前、x小时前、x天前、月/日）
  static String timeAgo(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inHours < 1) return '${diff.inMinutes}分钟前';
    if (diff.inDays < 1) return '${diff.inHours}小时前';
    if (diff.inDays < 7) return '${diff.inDays}天前';
    return '${time.month}/${time.day}';
  }

  /// 修复封面URL：处理协议相对URL、HTTP→HTTPS、空值
  static String? fixCoverUrl(String? url) {
    if (url == null || url.isEmpty || url == 'null') return null;
    // 协议相对URL：//xxx → https://xxx
    if (url.startsWith('//')) return 'https:$url';
    // HTTP → HTTPS
    if (url.startsWith('http://')) return url.replaceFirst('http://', 'https://');
    // 相对路径（不太常见但处理一下）
    if (!url.startsWith('http')) return null;
    return url;
  }
}
