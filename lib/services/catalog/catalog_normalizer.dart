import '../../models/catalog/catalog_enums.dart';

class CatalogNormalizer {
  const CatalogNormalizer();

  static const Set<String> canonicalGenres = {
    'action',
    'adventure',
    'comedy',
    'drama',
    'fantasy',
    'sciFi',
    'romance',
    'school',
    'sliceOfLife',
    'healing',
    'mystery',
    'thriller',
    'horror',
    'sports',
    'music',
    'historical',
    'military',
    'mecha',
    'magicalGirl',
    'isekai',
    'family',
    'supernatural',
  };

  String normalizeTitle(String value) => value
      .trim()
      .toLowerCase()
      .replaceAll(
        RegExp(r'[\s\u3000·・:：\-–—_.,，。!！?？’“”‘()（）\[\]【】/\\]+'),
        '',
      )
      .replaceAll("'", '');

  Set<String> normalizeGenres(Iterable<String> values) {
    final result = <String>{};
    for (final value in values) {
      for (final token in value.split(RegExp(r'[,，/／|、;；&＋+]'))) {
        final normalized = _genreAliases[_aliasKey(token)];
        if (normalized != null) result.add(normalized);
      }
    }
    return Set<String>.unmodifiable(result);
  }

  CatalogFormat normalizeFormat(String? value) =>
      _formatAliases[_aliasKey(value)] ?? CatalogFormat.unknown;

  CatalogStatus normalizeStatus(String? value) =>
      _statusAliases[_aliasKey(value)] ?? CatalogStatus.unknown;

  CatalogRegion normalizeRegion(String? value) =>
      _regionAliases[_aliasKey(value)] ?? CatalogRegion.unknown;

  bool matchesAllGenres({
    required Iterable<String> contentGenres,
    required Iterable<String> selectedGenres,
  }) {
    final selected = normalizeGenres(selectedGenres);
    if (selected.isEmpty) return true;
    final available = normalizeGenres(contentGenres);
    return available.containsAll(selected);
  }

  static const Map<String, String> _genreAliases = {
    'action': 'action',
    '动作': 'action',
    'adventure': 'adventure',
    '冒险': 'adventure',
    'comedy': 'comedy',
    '喜剧': 'comedy',
    '搞笑': 'comedy',
    'drama': 'drama',
    '剧情': 'drama',
    'fantasy': 'fantasy',
    '奇幻': 'fantasy',
    'scifi': 'sciFi',
    'sciencefiction': 'sciFi',
    '科幻': 'sciFi',
    'romance': 'romance',
    '恋爱': 'romance',
    '爱情': 'romance',
    'school': 'school',
    '校园': 'school',
    'sliceoflife': 'sliceOfLife',
    '日常': 'sliceOfLife',
    'healing': 'healing',
    'iyashikei': 'healing',
    '治愈': 'healing',
    'mystery': 'mystery',
    '推理': 'mystery',
    'thriller': 'thriller',
    '悬疑': 'thriller',
    '惊悚': 'thriller',
    'horror': 'horror',
    '恐怖': 'horror',
    'sports': 'sports',
    'sport': 'sports',
    '运动': 'sports',
    '体育': 'sports',
    'music': 'music',
    '音乐': 'music',
    'historical': 'historical',
    'history': 'historical',
    '历史': 'historical',
    '古装': 'historical',
    'military': 'military',
    '军事': 'military',
    '战争': 'military',
    'mecha': 'mecha',
    '机战': 'mecha',
    '机器人': 'mecha',
    'magicalgirl': 'magicalGirl',
    '魔法少女': 'magicalGirl',
    'isekai': 'isekai',
    '异世界': 'isekai',
    'family': 'family',
    '家庭': 'family',
    '亲子': 'family',
    'supernatural': 'supernatural',
    '超自然': 'supernatural',
    '灵异': 'supernatural',
  };

  static const Map<String, CatalogFormat> _formatAliases = {
    'tv': CatalogFormat.tv,
    'tvseries': CatalogFormat.tv,
    '电视动画': CatalogFormat.tv,
    'テレビ': CatalogFormat.tv,
    'movie': CatalogFormat.movie,
    'film': CatalogFormat.movie,
    'theatrical': CatalogFormat.movie,
    '剧场版': CatalogFormat.movie,
    '电影': CatalogFormat.movie,
    'ova': CatalogFormat.ova,
    'oav': CatalogFormat.ova,
    'ona': CatalogFormat.ona,
    'web': CatalogFormat.ona,
    '网络动画': CatalogFormat.ona,
    'special': CatalogFormat.special,
    'sp': CatalogFormat.special,
    'music': CatalogFormat.music,
    'mv': CatalogFormat.music,
  };

  static const Map<String, CatalogStatus> _statusAliases = {
    'upcoming': CatalogStatus.upcoming,
    'notyetaired': CatalogStatus.upcoming,
    '未放送': CatalogStatus.upcoming,
    '即将上映': CatalogStatus.upcoming,
    'airing': CatalogStatus.airing,
    'currentlyairing': CatalogStatus.airing,
    '连载': CatalogStatus.airing,
    '连载中': CatalogStatus.airing,
    '更新中': CatalogStatus.airing,
    '放送中': CatalogStatus.airing,
    'completed': CatalogStatus.completed,
    'finishedairing': CatalogStatus.completed,
    '完结': CatalogStatus.completed,
    '已完结': CatalogStatus.completed,
    'hiatus': CatalogStatus.hiatus,
    '暂停': CatalogStatus.hiatus,
    '停更': CatalogStatus.hiatus,
    'cancelled': CatalogStatus.cancelled,
    'canceled': CatalogStatus.cancelled,
    '取消': CatalogStatus.cancelled,
  };

  static const Map<String, CatalogRegion> _regionAliases = {
    'japan': CatalogRegion.japan,
    'japanese': CatalogRegion.japan,
    '日本': CatalogRegion.japan,
    'china': CatalogRegion.china,
    'chinese': CatalogRegion.china,
    '中国': CatalogRegion.china,
    '大陆': CatalogRegion.china,
    '国产': CatalogRegion.china,
    'korea': CatalogRegion.korea,
    'korean': CatalogRegion.korea,
    '韩国': CatalogRegion.korea,
    'western': CatalogRegion.western,
    'us': CatalogRegion.western,
    'usa': CatalogRegion.western,
    'america': CatalogRegion.western,
    'europe': CatalogRegion.western,
    '欧美': CatalogRegion.western,
    '美国': CatalogRegion.western,
    '欧洲': CatalogRegion.western,
    'other': CatalogRegion.other,
    '其他': CatalogRegion.other,
  };

  static String _aliasKey(String? value) =>
      (value ?? '').trim().toLowerCase().replaceAll(RegExp(r'[\s_.\-]+'), '');
}
