// ignore_for_file: library_private_types_in_public_api

import 'package:mobx/mobx.dart';
import '../models/anime.dart';
import '../services/plugin/plugin_service.dart';
import '../../utils/logger.dart';

part 'home_store.g.dart';

class HomeStore = _HomeStore with _$HomeStore;

abstract class _HomeStore with Store {
  final PluginService _pluginService = PluginService();

  @observable
  ObservableList<Map<String, dynamic>> latestList = ObservableList.of([]);

  @observable
  ObservableList<Map<String, dynamic>> trendingList = ObservableList.of([]);

  @observable
  bool isLoadingLatest = false;

  @observable
  bool isLoadingTrending = false;

  @observable
  ObservableList<Map<String, dynamic>> seasonalList = ObservableList.of([]);

  @observable
  bool isLoadingSeasonal = false;

  @observable
  String? errorMessage;

  @action
  Future<void> loadLatest() async {
    isLoadingLatest = true;
    errorMessage = null;
    try {
      final results =
          await _pluginService.getCmsLatest(pluginApi: 'cms_yinhua', page: 1);
      latestList.clear();
      latestList.addAll(results);
    } catch (e) {
      Log.e('HomeStore', '加载最新番剧失败', e);
      errorMessage = '加载最新番剧失败，请检查网络';
    } finally {
      isLoadingLatest = false;
    }
  }

  @action
  Future<void> loadTrending() async {
    isLoadingTrending = true;
    errorMessage = null;
    try {
      final results =
          await _pluginService.getCmsLatest(pluginApi: 'cms_ffzy', page: 1);
      trendingList.clear();
      trendingList.addAll(results);
    } catch (e) {
      Log.e('HomeStore', '加载热门番剧失败', e);
      errorMessage = '加载热门番剧失败，请检查网络';
    } finally {
      isLoadingTrending = false;
    }
  }

  @action
  Future<void> loadSeasonal() async {
    isLoadingSeasonal = true;
    try {
      final results = await _pluginService.getJikanSeasonNow();

      // 关键修复：将 Jikan URL 解析为 CMS 可播放源 URL
      // Jikan 不提供视频，详情页需要 CMS 源才能播放
      // 提前在首页解析好，用户点击时直接用 CMS 源
      await _resolveJikanToCms(results);

      seasonalList.clear();
      seasonalList.addAll(results);
    } catch (e) {
      Log.e('HomeStore', '加载季度新番失败', e);
    } finally {
      isLoadingSeasonal = false;
    }
  }

  /// 将 Jikan 动漫列表中的 URL 替换为 CMS 可播放源 URL
  /// 通过 Bangumi 桥接获取中文名，再用中文名搜索 CMS
  Future<void> _resolveJikanToCms(List<Map<String, dynamic>> items) async {
    final jikanItems = items
        .where(
          (item) => item['url']?.toString().startsWith('jikan:') == true,
        )
        .toList();
    if (jikanItems.isEmpty) return;

    Log.d('HomeStore', '开始解析 ${jikanItems.length} 个 Jikan 动漫的 CMS 源...');

    // 分批并行解析（每批5个，避免瞬间发太多请求）
    for (var i = 0; i < jikanItems.length; i += 5) {
      final batch = jikanItems.skip(i).take(5);
      await Future.wait(batch.map((item) => _resolveSingleJikan(item)));
    }

    final resolved = jikanItems
        .where(
          (item) => !item['url'].toString().startsWith('jikan:'),
        )
        .length;
    Log.d('HomeStore', 'CMS 源解析完成: $resolved/${jikanItems.length} 成功');
  }

  /// 解析单个 Jikan 动漫的 CMS 源
  Future<void> _resolveSingleJikan(Map<String, dynamic> item) async {
    final name = item['name']?.toString() ?? '';
    if (name.isEmpty) return;

    try {
      // 策略1: 通过 Bangumi 获取中文名，再搜 CMS（最可靠）
      final bgmResults = await _pluginService
          .searchBangumi(name)
          .timeout(const Duration(seconds: 5), onTimeout: () => <Anime>[]);
      if (bgmResults.isNotEmpty) {
        final bgmName = bgmResults.first.name;
        final cmsResults = await _pluginService
            .searchCmsOnly(bgmName)
            .timeout(const Duration(seconds: 5), onTimeout: () => <Anime>[]);
        if (cmsResults.isNotEmpty) {
          Log.d('HomeStore', '✓ $name → $bgmName → ${cmsResults.first.name}');
          item['url'] = cmsResults.first.url;
          return;
        }
      }

      // 策略2: 直接用名称搜 CMS
      final cmsResults = await _pluginService
          .searchCmsOnly(name)
          .timeout(const Duration(seconds: 5), onTimeout: () => <Anime>[]);
      if (cmsResults.isNotEmpty) {
        Log.d('HomeStore', '✓ $name → ${cmsResults.first.name} (直接匹配)');
        item['url'] = cmsResults.first.url;
        return;
      }

      Log.d('HomeStore', '✗ $name 未找到 CMS 源');
    } catch (e) {
      Log.d('HomeStore', '解析 $name 失败: $e');
    }
  }

  @action
  Future<void> loadAll() async {
    await Future.wait([loadLatest(), loadTrending(), loadSeasonal()]);
  }
}
