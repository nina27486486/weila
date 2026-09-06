/// 路由路径常量与带参跳转 URI 的统一构造。
///
/// 页面跳转一律引用这里的常量/方法，避免路径字符串散落导致拼写漂移；
/// 带参构造自动过滤空值并对值做 URL 编码。
class AppRoutes {
  AppRoutes._();

  static const String home = '/';
  static const String search = '/search';
  static const String detailPath = '/detail';
  static const String playerPath = '/player';
  static const String history = '/history';
  static const String collect = '/collect';
  static const String track = '/track';
  static const String settings = '/settings';
  static const String plugins = '/settings/plugins';
  static const String pluginAdd = '/settings/plugin-add';
  static const String pluginDetail = '/settings/plugin-detail';
  static const String animeList = '/anime-list';
  static const String calendar = '/calendar';
  static const String ranking = '/ranking';
  static const String category = '/category';
  static const String download = '/download';

  /// 详情页 URI：三种入口（contentId / url+name / 混合）。
  static String detail({String? url, String? name, String? contentId}) {
    return _withParams(detailPath, {
      'url': url,
      'name': name,
      'contentId': contentId,
    });
  }

  /// 播放器 URI：url 必填，其余可选。
  static String player({
    required String url,
    String? title,
    String? animeUrl,
    String? animeName,
    String? cover,
    int? episodeIndex,
    String? source,
    String? contentId,
  }) {
    return _withParams(playerPath, {
      'url': url,
      'title': title,
      'animeUrl': animeUrl,
      'animeName': animeName,
      'cover': cover,
      'ep': episodeIndex?.toString(),
      'source': source,
      'contentId': contentId,
    });
  }

  static String _withParams(String path, Map<String, String?> params) {
    final query = params.entries
        .where((entry) => entry.value != null && entry.value!.isNotEmpty)
        .map((entry) => '${entry.key}=${Uri.encodeComponent(entry.value!)}')
        .join('&');
    return query.isEmpty ? path : '$path?$query';
  }
}
