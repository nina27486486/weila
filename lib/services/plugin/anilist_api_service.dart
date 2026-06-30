import '../../models/anime.dart';
import '../http/http_client.dart';
import '../../utils/logger.dart';

class AnilistApiService {
  final HttpClient _http;

  AnilistApiService(this._http);

  static const _anilistEndpoint = 'https://graphql.anilist.co';

  Future<List<Anime>> searchAnilist(String keyword) async {
    const query = r'''
      query ($search: String) {
        Page(perPage: 10) {
          media(search: $search, type: ANIME) {
            id
            title { romaji native english }
            coverImage { large medium }
            description
          }
        }
      }
    ''';
    try {
      Log.d('Anilist', '搜索: $keyword');
      final data = await _http.postJson(_anilistEndpoint, data: {
        'query': query,
        'variables': {'search': keyword},
      });
      if (data is! Map<String, dynamic>) return [];
      final mediaList = data['data']?['Page']?['media'] as List?;
      if (mediaList == null || mediaList.isEmpty) return [];
      return mediaList.map((media) {
        final title = media['title'];
        final name = title['native']?.toString() ?? title['romaji']?.toString() ?? '';
        return Anime(
          name: name,
          url: 'anilist:${media['id']}',
          cover: media['coverImage']?['large']?.toString(),
          description: media['description']?.toString(),
          sourcePlugin: 'anilist',
        );
      }).where((a) => a.name.isNotEmpty).toList();
    } catch (e) {
      Log.e('Anilist', '搜索失败', e);
      return [];
    }
  }

  Future<Map<String, dynamic>?> getAnilistDetail(String animeUrl) async {
    final id = animeUrl.replaceAll('anilist:', '');
    const query = r'''
      query ($id: Int) {
        Media(id: $id, type: ANIME) {
          id
          title { romaji native english }
          coverImage { large medium }
          description
          episodes
          status
          genres
          averageScore
        }
      }
    ''';
    try {
      Log.d('Anilist', '获取详情: ID=$id');
      final data = await _http.postJson(_anilistEndpoint, data: {
        'query': query,
        'variables': {'id': int.parse(id)},
      });
      if (data is! Map<String, dynamic>) return null;
      final media = data['data']?['Media'];
      if (media == null) return null;
      final title = media['title'];
      return {
        'name': title['native']?.toString() ?? title['romaji']?.toString() ?? '',
        'name_cn': title['native']?.toString() ?? '',
        'name_ja': title['romaji']?.toString() ?? '',
        'summary': media['description']?.toString() ?? '',
        'cover': media['coverImage']?['large']?.toString(),
        'rating': media['averageScore'] != null ? (media['averageScore'] as int) / 10.0 : null,
        'tags': (media['genres'] as List?)?.cast<String>() ?? [],
        'status': media['status']?.toString(),
        'total_episodes': media['episodes'],
      };
    } catch (e) {
      Log.e('Anilist', '获取详情失败', e);
      return null;
    }
  }

  Future<List<Episode>> getAnilistEpisodes(String animeUrl) async {
    final detail = await getAnilistDetail(animeUrl);
    if (detail == null) return [];
    final totalEps = detail['total_episodes'] as int? ?? 12;
    return List.generate(totalEps, (i) => Episode(
      name: '第${i + 1}集',
      url: '',
      index: i + 1,
    ));
  }
}
