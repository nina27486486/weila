import '../http/http_client.dart';
import '../../utils/logger.dart';
import '../../utils/constants.dart';

/// Bangumi API 服务
class BangumiApiService {
  final HttpClient http;

  BangumiApiService(this.http);

  /// 获取 Bangumi 详情（含集数）
  Future<Map<String, dynamic>?> getBangumiDetail(String subjectUrl) async {
    try {
      // 从URL提取subject ID
      final match = RegExp(r'/subject/(\d+)').firstMatch(subjectUrl);
      if (match == null) return null;
      final id = match.group(1);

      final headers = {'User-Agent': AppConstants.defaultUserAgent};

      // 获取详情
      final detailUrl = 'https://api.bgm.tv/v0/subjects/$id';
      Log.d('Bangumi', '获取详情: $detailUrl');
      final detail = await http.getJson(detailUrl, headers: headers);

      // 获取集数（用旧API，返回更完整）
      final epsUrl = 'https://api.bgm.tv/subject/$id?responseGroup=large';
      Log.d('Bangumi', '获取集数: $epsUrl');
      final epsData = await http.getJson(epsUrl, headers: headers);

      return {
        'name': detail['name_cn']?.toString().isNotEmpty == true
            ? detail['name_cn']
            : detail['name'],
        'name_cn': detail['name_cn'] ?? '',
        'name_ja': detail['name'] ?? '',
        'summary': detail['summary'] ?? '',
        'cover': detail['images']?['large'] ?? detail['images']?['medium'],
        'rating': detail['rating']?['score'],
        'rating_count': detail['rating']?['total'],
        'rank': detail['rating']?['rank'],
        'tags': (detail['tags'] as List?)
            ?.take(8)
            .map((t) => t['name']?.toString() ?? '')
            .where((t) => t.isNotEmpty)
            .toList(),
        'date': detail['date'] ?? epsData['air_date'] ?? '',
        'platform': detail['platform'] ?? '',
        'total_episodes': detail['total_episodes'],
        'episodes': (epsData['eps'] as List?)
            ?.where((ep) => ep['type'] == 0) // 只要正片
            .map((ep) => {
                  'sort': ep['sort'],
                  'name': ep['name_cn']?.toString().isNotEmpty == true
                      ? ep['name_cn']
                      : ep['name'],
                  'airdate': ep['airdate'],
                  'duration': ep['duration'],
                })
            .toList(),
      };
    } catch (e) {
      Log.e('Bangumi', '获取详情失败', e);
      return null;
    }
  }

  /// 搜索 Bangumi 动漫（返回中文标题）
  Future<Map<String, dynamic>?> searchSubject(String keyword) async {
    try {
      final headers = {'User-Agent': AppConstants.defaultUserAgent};
      final url = 'https://api.bgm.tv/search/subject/${Uri.encodeComponent(keyword)}?type=2&max_results=1';
      Log.d('Bangumi', '搜索: $url');
      final data = await http.getJson(url, headers: headers);
      if (data is! Map<String, dynamic>) return null;
      final list = data['list'] as List? ?? [];
      if (list.isEmpty) return null;
      final item = list.first as Map<String, dynamic>;
      return {
        'name_cn': item['name_cn']?.toString() ?? '',
        'name': item['name']?.toString() ?? '',
        'id': item['id'],
      };
    } catch (e) {
      Log.e('Bangumi', '搜索失败', e);
      return null;
    }
  }
}
