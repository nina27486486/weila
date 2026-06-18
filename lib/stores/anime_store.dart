import 'package:mobx/mobx.dart';
import '../models/anime.dart';
import '../services/plugin/plugin_service.dart';

part 'anime_store.g.dart';

class AnimeStore = _AnimeStore with _$AnimeStore;

abstract class _AnimeStore with Store {
  final PluginService _pluginService = PluginService();

  @observable
  ObservableList<Anime> searchResults = ObservableList.of([]);
  
  @observable
  ObservableList<Anime> popularList = ObservableList.of([]);
  
  @observable
  ObservableList<Episode> currentEpisodes = ObservableList.of([]);
  
  @observable
  Map<String, dynamic>? currentDetail;
  
  @observable
  bool isLoading = false;
  
  @observable
  bool isLoadingEpisodes = false;
  
  @observable
  String? errorMessage;

  @observable
  String lastKeyword = '';
  
  @action
  Future<void> search(String keyword) async {
    if (keyword.trim().isEmpty) return;
    
    isLoading = true;
    errorMessage = null;
    searchResults.clear();
    lastKeyword = keyword;
    
    try {
      final results = await _pluginService.searchAll(keyword);
      searchResults.addAll(results);
      
      if (results.isEmpty) {
        errorMessage = '没有找到相关结果';
      }
    } catch (e) {
      errorMessage = '搜索失败: $e';
    } finally {
      isLoading = false;
    }
  }
  
  @action
  Future<void> loadEpisodes(Anime anime) async {
    isLoadingEpisodes = true;
    currentEpisodes.clear();
    currentDetail = null;
    
    try {
      // 加载详情（包含元数据和集数）
      final detail = await _pluginService.getDetail(anime);
      if (detail != null) {
        currentDetail = detail;
      }
      
      final episodes = await _pluginService.getEpisodes(anime);
      currentEpisodes.addAll(episodes);
    } catch (e) {
      errorMessage = '加载章节失败: $e';
    } finally {
      isLoadingEpisodes = false;
    }
  }

  @action
  Future<List<String>> getVideoUrls(Anime anime, Episode episode) async {
    try {
      final plugin = _pluginService.plugins.firstWhere(
        (p) => p.api == anime.sourcePlugin,
        orElse: () => _pluginService.plugins.first,
      );
      return await _pluginService.getVideoUrls(episode.url, plugin);
    } catch (e) {
      errorMessage = '获取视频源失败: $e';
      return [];
    }
  }
  
  @action
  void clearSearch() {
    searchResults.clear();
    errorMessage = null;
    lastKeyword = '';
  }

  @action
  void clearEpisodes() {
    currentEpisodes.clear();
  }
}
