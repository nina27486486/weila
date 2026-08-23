import 'dart:async';

import '../../theme/vira_colors.dart';
import '../../utils/logger.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:html/parser.dart' as html_parser;
import '../../theme/app_theme.dart';
import '../../stores/anime_store.dart';
import '../../stores/history_collect_store.dart';
import '../../stores/theme_store.dart';
import '../../models/anime.dart';
import '../../models/playback/playback_source.dart';
import '../../models/catalog/catalog_values.dart';
import '../../models/collect_item.dart';
import '../../models/track_item.dart';
import '../../services/plugin/plugin_service.dart';
import '../../services/jikan/jikan_service.dart';
import '../../services/http/http_client.dart';
import '../../services/catalog/catalog_repository.dart';
import '../../services/playback/playback_error_sanitizer.dart';
import '../../services/storage/storage_service.dart';
import '../../utils/animations.dart';
import '../../widgets/artwork_components.dart';
import '../../widgets/cover_image.dart';
import '../../widgets/vira_page_chrome.dart';
import '../../utils/error_handler.dart';
import 'detail_controller.dart';

part 'widgets/detail_components.dart';
part 'widgets/detail_page_view.dart';

class DetailPage extends StatefulWidget {
  final String animeUrl;
  final String animeName;
  final String? contentId;
  final CatalogRepository? catalogRepository;

  const DetailPage({
    super.key,
    required this.animeUrl,
    required this.animeName,
    this.contentId,
    this.catalogRepository,
  });

  @override
  State<DetailPage> createState() => _DetailPageState();
}

class _DetailPageState extends State<DetailPage> {
  final _store = AnimeStore();
  final _collectStore = HistoryCollectStore();
  final _pluginService = PluginService();
  late final CatalogRepository _catalogRepository;
  late final DetailController _detailController;
  late Anime _anime;
  late String _libraryAnimeUrl;
  late String _animeName;
  CatalogContent? _catalogContent;
  bool _descExpanded = false;
  bool _collected = false;
  bool _tracked = false;
  bool _episodeGridView = true;

  String _cleanDisplayText(Object? value) {
    final source = value?.toString() ?? '';
    if (source.isEmpty) return '';
    return (html_parser.parseFragment(source).text ?? '')
        .replaceAll('\u00A0', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  // CMS 视频源
  String? _cmsAnimeUrl; // CMS 可播放源的 URL（如 cms_ffzy:24840）
  String? _cmsSourceName; // CMS 源名称（如"非凡资源"）
  bool get _searchingSource => _detailController.searchingSource;

  @override
  void initState() {
    super.initState();
    _catalogRepository =
        widget.catalogRepository ?? StorageService().createCatalogRepository();
    _detailController = DetailController(repository: _catalogRepository);
    _libraryAnimeUrl = widget.animeUrl.isNotEmpty
        ? widget.animeUrl
        : widget.contentId?.isNotEmpty == true
            ? 'catalog:${widget.contentId}'
            : '';
    _animeName = widget.animeName;
    _anime = Anime(
      name: _animeName,
      url: widget.animeUrl,
      sourcePlugin: 'unknown',
    );
    // isCollected/isTracked 以 store 的 observable 列表为事实源，
    // 读取前必须先加载对应列表。
    _collectStore.loadCollects();
    _collectStore.loadTracks();
    _collected = _collectStore.isCollected(_libraryAnimeUrl);
    _tracked = _collectStore.isTracked(_libraryAnimeUrl);

    unawaited(_initializeDetail());
  }

  Future<void> _initializeDetail() async {
    final binding = await _detailController.resolveBinding(
      contentId: widget.contentId,
      legacyUrl: widget.animeUrl,
      legacyName: widget.animeName,
    );
    if (!mounted || binding == null) return;
    _libraryAnimeUrl = binding.libraryUrl;
    _animeName = binding.name;
    _catalogContent = binding.catalogContent;
    _anime = Anime(
      name: binding.name,
      url: binding.sourceUrl,
      sourcePlugin: binding.sourcePlugin,
      cover: binding.catalogContent?.coverUrl,
      description: binding.catalogContent?.synopsis,
    );
    _collected = _collectStore.isCollected(_libraryAnimeUrl);
    _tracked = _collectStore.isTracked(_libraryAnimeUrl);
    setState(() {});

    // 顺序加载：先加载元数据+集数，再搜索 CMS 播放源
    // 避免竞态条件：如果两者并行，loadEpisodes 可能在 CMS 集数加载后
    // 执行 clear()，把真实的 CMS 集数覆盖为 Jikan 空壳集数
    if (binding.sourceUrl.isNotEmpty && binding.sourcePlugin != 'unknown') {
      await _initData(binding.sourcePlugin);
    }
  }

  @override
  void dispose() {
    _detailController.dispose();
    _collectStore.dispose();
    super.dispose();
  }

  /// 顺序初始化数据：先加载集数，再搜索播放源
  Future<void> _initData(String sourcePlugin) async {
    // 第一步：加载元数据和集数（Jikan/Anilist/Bangumi 占位集数）
    await _store.loadEpisodes(_anime);

    // 第二步：元数据加载完毕后，再搜索 CMS 播放源
    // 这样 _loadCmsEpisodes() 替换集数时不会被 loadEpisodes 覆盖
    if (sourcePlugin == 'anilist' ||
        sourcePlugin == 'bangumi' ||
        sourcePlugin == 'jikan') {
      await _searchPlayableSource();
    }
  }

  /// 自动搜索 CMS 可播放源
  Future<void> _searchPlayableSource() async {
    final searchGeneration = _detailController.beginSourceSearch();
    setState(() {});
    try {
      Log.d('Detail', '开始搜索播放源: $_animeName (source: ${_anime.sourcePlugin})');

      Anime? cmsResult;

      // 预处理：去掉季度/季数后缀，得到基础标题
      final baseTitle = _stripSeasonInfo(_animeName);
      Log.d('Detail', '基础标题: "$baseTitle"');

      // ── 第0轮（最优）：通过 Bangumi 桥接获取中文名称 ──
      if (_anime.sourcePlugin == 'jikan' || _anime.sourcePlugin == 'anilist') {
        // 先用基础标题搜 Bangumi（更短的关键词匹配率更高）
        for (final bgmKeyword in {baseTitle, _animeName}) {
          try {
            final bgmResults = await _pluginService
                .searchBangumi(bgmKeyword)
                .timeout(const Duration(seconds: 8),
                    onTimeout: () => <Anime>[]);
            if (bgmResults.isNotEmpty) {
              final bgmName = bgmResults.first.name;
              Log.d('Detail', 'Bangumi 桥接: "$bgmKeyword" → "$bgmName"');
              final cmsResults = await _pluginService.searchCmsOnly(bgmName);
              cmsResult = cmsResults.firstOrNull;
              if (cmsResult != null) {
                Log.d('Detail', 'Bangumi→CMS 成功: ${cmsResult.name}');
                break;
              }
            }
          } catch (e) {
            Log.d('Detail', 'Bangumi 搜索 "$bgmKeyword" 失败: $e');
          }
        }
      }

      // 第1轮：用基础标题搜索 CMS（去掉季度后缀后匹配率更高）
      if (cmsResult == null && baseTitle != _animeName) {
        final results = await _pluginService.searchCmsOnly(baseTitle);
        cmsResult = results.firstOrNull;
        Log.d('Detail', '第1轮(基础标题CMS): ${cmsResult?.name ?? "无"}');
      }

      // 第1.5轮：用完整名称搜索 CMS
      if (cmsResult == null) {
        final results = await _pluginService.searchAll(_animeName);
        cmsResult =
            results.where((a) => a.sourcePlugin.startsWith('cms_')).firstOrNull;
        Log.d('Detail', '第1.5轮(完整名CMS): ${cmsResult?.name ?? "无"}');
      }

      // 第2轮：用 Jikan 日文原标题中的汉字转简体搜索
      if (cmsResult == null && _anime.sourcePlugin == 'jikan') {
        final malId = int.tryParse(_anime.url.replaceFirst('jikan:', ''));
        String? jaTitle;
        if (malId != null) {
          final detail = await JikanService().getAnimeDetails(malId);
          if (detail != null) {
            jaTitle = detail['name_ja']?.toString();
          }
        }
        // 用日文标题的汉字部分转简体
        final titleForKanji = jaTitle ?? _animeName;
        final cnKeywords = _japaneseToChineseKeywords(titleForKanji);
        if (cnKeywords != null && cnKeywords.length >= 2) {
          Log.d('Detail', '第2轮: 汉字转换 "$cnKeywords" 搜索 CMS');
          final results = await _pluginService.searchCmsOnly(cnKeywords);
          cmsResult = results.firstOrNull;
        }
        // 同时用日文原标题搜 Bangumi
        if (cmsResult == null && jaTitle != null && jaTitle.isNotEmpty) {
          try {
            final bgmResults = await _pluginService
                .searchBangumi(jaTitle)
                .timeout(const Duration(seconds: 6),
                    onTimeout: () => <Anime>[]);
            if (bgmResults.isNotEmpty) {
              final bgmName = bgmResults.first.name;
              Log.d('Detail', '日文→Bangumi: "$jaTitle" → "$bgmName"');
              final cmsResults = await _pluginService.searchCmsOnly(bgmName);
              cmsResult = cmsResults.firstOrNull;
            }
          } catch (e) {
            Log.d('Detail', '日文 Bangumi 搜索失败: $e');
          }
        }
      }

      // 第3轮：用 Anilist 同义词找中文标题
      if (cmsResult == null &&
          (_anime.sourcePlugin == 'jikan' ||
              _anime.sourcePlugin == 'anilist')) {
        try {
          final cnName = await _getChineseTitleFromAnilist(baseTitle).timeout(
            const Duration(seconds: 8),
            onTimeout: () => null,
          );
          if (cnName != null && cnName.isNotEmpty) {
            Log.d('Detail', '第3轮: Anilist 中文名 "$cnName" 搜索 CMS');
            final results = await _pluginService.searchCmsOnly(cnName);
            cmsResult = results.firstOrNull;
          }
        } catch (e) {
          Log.d('Detail', '第3轮 Anilist 超时/失败: $e');
        }
      }

      if (cmsResult != null &&
          mounted &&
          _detailController.isCurrentSourceSearch(searchGeneration)) {
        final cms = cmsResult;
        Log.d('Detail', '找到播放源: ${cms.name} (${cms.url})');
        setState(() {
          _cmsAnimeUrl = cms.url;
          _cmsSourceName = _pluginService.plugins
                  .where((p) => p.api == cms.sourcePlugin)
                  .firstOrNull
                  ?.name ??
              cms.sourcePlugin;
        });
        await _loadCmsEpisodes(cms);
      } else {
        Log.d('Detail', '自动搜索未找到播放源，等待用户手动搜索');
      }
    } catch (e) {
      Log.e('Detail', '搜索可播放源失败', e);
    } finally {
      if (_detailController.isCurrentSourceSearch(searchGeneration)) {
        _detailController.finishSourceSearch(searchGeneration);
        if (mounted) setState(() {});
      }
    }
  }

  /// 手动搜索 CMS 播放源（用户触发）
  Future<void> _manualSearchSource() async {
    final controller = TextEditingController();
    final focusNode = FocusNode();

    // 对话框 1: 输入搜索关键词
    final keyword = await showDialog<String>(
      context: context,
      builder: (ctx) {
        // 延迟请求焦点，确保对话框已完全渲染
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (focusNode.canRequestFocus) focusNode.requestFocus();
        });
        return AlertDialog(
          backgroundColor: context.colors.bgCard,
          title: Text('手动搜索视频源',
              style: TextStyle(color: context.colors.textPrimary)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '请输入动漫的中文名称：',
                style: TextStyle(
                    color: context.colors.textSecondary, fontSize: 13),
              ),
              SizedBox(height: 12),
              TextField(
                controller: controller,
                focusNode: focusNode,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: '例如: 实力至上主义的教室',
                  hintStyle: TextStyle(color: context.colors.textMuted),
                  filled: true,
                  fillColor: context.colors.bgDark,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                ),
                onSubmitted: (value) => Navigator.of(ctx).pop(value),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text('取消',
                  style: TextStyle(color: context.colors.textSecondary)),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(controller.text),
              child: Text('搜索'),
            ),
          ],
        );
      },
    );
    focusNode.dispose();
    controller.dispose();

    if (keyword == null || keyword.trim().isEmpty) return;
    final trimmedKeyword = keyword.trim();

    // 搜索 CMS
    if (!mounted) return;
    final searchGeneration = _detailController.beginSourceSearch();
    setState(() {});
    List<Anime> cmsResults;
    try {
      cmsResults = await _pluginService.searchCmsOnly(trimmedKeyword);
    } catch (e) {
      Log.e('Detail', '手动搜索失败', e);
      if (_detailController.isCurrentSourceSearch(searchGeneration)) {
        _detailController.finishSourceSearch(searchGeneration);
        if (mounted) setState(() {});
      }
      return;
    }
    if (!_detailController.isCurrentSourceSearch(searchGeneration)) return;
    _detailController.finishSourceSearch(searchGeneration);
    if (mounted) setState(() {});

    if (cmsResults.isEmpty) {
      if (mounted) {
        ErrorHandler.showInfo(context, '未找到 "$trimmedKeyword" 的播放源');
      }
      return;
    }

    // 对话框 2: 选择匹配的动漫
    if (!mounted) return;
    final selected = await showDialog<Anime>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.colors.bgCard,
        title: Text('选择匹配的动漫',
            style: TextStyle(color: context.colors.textPrimary)),
        content: SizedBox(
          width: 400,
          height: 300,
          child: ListView.builder(
            itemCount: cmsResults.length > 10 ? 10 : cmsResults.length,
            itemBuilder: (ctx, i) {
              final anime = cmsResults[i];
              return ListTile(
                title: Text(anime.name,
                    style: TextStyle(color: context.colors.textPrimary)),
                subtitle:
                    anime.description != null && anime.description!.isNotEmpty
                        ? Text(_cleanDisplayText(anime.description),
                            style: TextStyle(
                                color: context.colors.textMuted, fontSize: 11),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis)
                        : null,
                onTap: () => Navigator.of(ctx).pop(anime),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('取消'),
          ),
        ],
      ),
    );

    if (selected != null &&
        mounted &&
        _detailController.isCurrentSourceSearch(searchGeneration)) {
      Log.d('Detail', '手动选择播放源: ${selected.name} (${selected.url})');
      setState(() {
        _cmsAnimeUrl = selected.url;
        _cmsSourceName = _pluginService.plugins
                .where((p) => p.api == selected.sourcePlugin)
                .firstOrNull
                ?.name ??
            selected.sourcePlugin;
      });
      final episodeCount = await _loadCmsEpisodes(selected);
      if (episodeCount > 0) await _confirmPlayable(selected);
    }
  }

  /// 加载 CMS 集数并替换 Store 中的占位集数
  Future<int> _loadCmsEpisodes(Anime cmsAnime) async {
    try {
      final episodes = await _pluginService.getEpisodes(cmsAnime);
      if (episodes.isNotEmpty && mounted) {
        _store.replaceEpisodes(episodes);
        Log.d('Detail', '已加载 ${episodes.length} 个 CMS 集数');
      }
      return episodes.length;
    } catch (e) {
      Log.e('Detail', '加载 CMS 集数失败', e);
      return 0;
    }
  }

  Future<void> _confirmPlayable(Anime anime) async {
    await _detailController.confirmPlayable(
      contentId: widget.contentId,
      anime: anime,
    );
  }

  double? _bestCatalogScore() {
    double? best;
    for (final rating
        in _catalogContent?.ratings.values ?? const <CatalogRating>[]) {
      final score = rating.score;
      if (score != null && (best == null || score > best)) best = score;
    }
    return best;
  }

  /// 通过 Anilist GraphQL 获取中文标题（从 synonyms 中找中文，并转简体）
  Future<String?> _getChineseTitleFromAnilist(String keyword) async {
    try {
      const query = r'''
        query ($search: String) {
          Media(search: $search, type: ANIME) {
            title { romaji native english }
            synonyms
          }
        }
      ''';
      final data = await HttpClient().postJson(
        'https://graphql.anilist.co',
        data: {
          'query': query,
          'variables': {'search': keyword}
        },
      );
      if (data is! Map<String, dynamic>) return null;
      final media = data['data']?['Media'] as Map<String, dynamic>?;
      if (media == null) return null;

      // 从 synonyms 中找中文标题（包含中文字符的）
      final synonyms = (media['synonyms'] as List?)?.cast<String>() ?? [];
      for (final s in synonyms) {
        if (RegExp(r'[\u4e00-\u9fff]').hasMatch(s) && s != keyword) {
          final simplified = _traditionalToSimplified(s);
          Log.d('Detail', 'Anilist 找到中文标题: $s → 简体: $simplified');
          return simplified;
        }
      }

      // 没有中文同义词，用 native（日文标题）
      final native = media['title']?['native']?.toString();
      if (native != null && native != keyword) return native;

      return null;
    } catch (e) {
      Log.d('Detail', 'Anilist 获取中文标题失败: $e');
      return null;
    }
  }

  /// 去除标题中的季度/季数后缀，提取基础标题
  /// "Youkoso...e 4th Season: 2-nensei-hen 1 Gakki" → "Youkoso...e"
  /// "进击的巨人 第三季" → "进击的巨人"
  static String _stripSeasonInfo(String title) {
    // 英文季度后缀模式
    var stripped = title
        .replaceAll(
            RegExp(r'\s+\d+(st|nd|rd|th)\s+(Season|season|Cour|cour).*$',
                caseSensitive: false),
            '')
        .replaceAll(RegExp(r'\s+Season\s+\d+.*$', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s+S\d+.*$', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s+Part\s+\d+.*$', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s+Cour\s+\d+.*$', caseSensitive: false), '');
    // 中文季度后缀
    stripped = stripped
        .replaceAll(RegExp(r'\s+第[一二三四五六七八九十\d]+季.*$'), '')
        .replaceAll(RegExp(r'\s+[IVX]+\s*$'), ''); // 罗马数字后缀
    return stripped.trim();
  }

  /// 从日文标题提取汉字并转简体中文（用于 CMS 搜索）
  /// "ようこそ実力至上主義の教室へ" → "欢迎来到实力至上主义的教室"
  static String? _japaneseToChineseKeywords(String title) {
    // 日文汉字 → 简体中文 映射（动漫高频字）
    const kanjiToSimplified = {
      '実': '实',
      '義': '义',
      '國': '国',
      '學': '学',
      '時': '时',
      '間': '间',
      '動': '动',
      '畫': '画',
      '戰': '战',
      '術': '术',
      '機': '机',
      '關': '关',
      '開': '开',
      '發': '发',
      '現': '现',
      '點': '点',
      '問': '问',
      '題': '题',
      '場': '场',
      '報': '报',
      '書': '书',
      '記': '记',
      '長': '长',
      '門': '门',
      '車': '车',
      '電': '电',
      '風': '风',
      '雲': '云',
      '飛': '飞',
      '龍': '龙',
      '鳳': '凤',
      '華': '华',
      '麗': '丽',
      '語': '语',
      '說': '说',
      '話': '话',
      '讀': '读',
      '寫': '写',
      '聽': '听',
      '見': '见',
      '視': '视',
      '覺': '觉',
      '頭': '头',
      '臉': '脸',
      '愛': '爱',
      '夢': '梦',
      '師': '师',
      '將': '将',
      '軍': '军',
      '後': '后',
      '從': '从',
      '對': '对',
      '歲': '岁',
      '萬': '万',
      '裡': '里',
      '銀': '银',
      '鐵': '铁',
      '種': '种',
      '類': '类',
      '節': '节',
      '經': '经',
      '練': '练',
      '組': '组',
      '結': '结',
      '統': '统',
      '續': '续',
      '維': '维',
      '網': '网',
      '總': '总',
      '線': '线',
      '產': '产',
      '業': '业',
      '無': '无',
      '東': '东',
      '強': '强',
      '當': '当',
      '應': '应',
      '進': '进',
      '達': '达',
      '過': '过',
      '還': '还',
      '遠': '远',
      '連': '连',
      '運': '运',
      '選': '选',
      '錄': '录',
      '體': '体',
      '驗': '验',
      '鬥': '斗',
      '歡': '欢',
      '來': '来',
      '區': '区',
      '號': '号',
      '錢': '钱',
      '親': '亲',
      '葉': '叶',
      '紅': '红',
      '黃': '黄',
      '藍': '蓝',
      '綠': '绿',
    };

    // 提取假名之外的汉字部分，并转换
    final buf = StringBuffer();
    for (final ch in title.split('')) {
      final code = ch.codeUnitAt(0);
      // CJK 统一汉字范围
      if (code >= 0x4e00 && code <= 0x9fff) {
        buf.write(kanjiToSimplified[ch] ?? ch);
      }
    }
    final result = buf.toString();
    return result.length >= 2 ? result : null;
  }

  /// 繁体中文 → 简体中文（覆盖动漫常用字）
  static String _traditionalToSimplified(String text) {
    final map = {
      '歡': '欢',
      '迎': '迎',
      '來': '来',
      '實': '实',
      '義': '义',
      '國': '国',
      '學': '学',
      '時': '时',
      '間': '间',
      '動': '动',
      '畫': '画',
      '戰': '战',
      '術': '术',
      '機': '机',
      '關': '关',
      '開': '开',
      '發': '发',
      '現': '现',
      '點': '点',
      '問': '问',
      '題': '题',
      '場': '场',
      '報': '报',
      '書': '书',
      '記': '记',
      '長': '长',
      '門': '门',
      '車': '车',
      '電': '电',
      '風': '风',
      '雲': '云',
      '飛': '飞',
      '魚': '鱼',
      '鳥': '鸟',
      '馬': '马',
      '龍': '龙',
      '鳳': '凤',
      '華': '华',
      '麗': '丽',
      '語': '语',
      '說': '说',
      '話': '话',
      '讀': '读',
      '寫': '写',
      '聽': '听',
      '見': '见',
      '視': '视',
      '覺': '觉',
      '頭': '头',
      '臉': '脸',
      '眼': '眼',
      '淚': '泪',
      '愛': '爱',
      '夢': '梦',
      '燈': '灯',
      '師': '师',
      '將': '将',
      '軍': '军',
      '後': '后',
      '從': '从',
      '對': '对',
      '歲': '岁',
      '萬': '万',
      '億': '亿',
      '號': '号',
      '裡': '里',
      '錢': '钱',
      '銀': '银',
      '鐵': '铁',
      '種': '种',
      '類': '类',
      '葉': '叶',
      '節': '节',
      '經': '经',
      '練': '练',
      '組': '组',
      '結': '结',
      '統': '统',
      '續': '续',
      '維': '维',
      '網': '网',
      '總': '总',
      '線': '线',
      '綠': '绿',
      '紅': '红',
      '黃': '黄',
      '藍': '蓝',
      '親': '亲',
      '產': '产',
      '業': '业',
      '無': '无',
      '東': '东',
      '區': '区',
      '強': '强',
      '當': '当',
      '應': '应',
      '進': '进',
      '達': '达',
      '過': '过',
      '還': '还',
      '遠': '远',
      '連': '连',
      '運': '运',
      '選': '选',
      '邊': '边',
      '週': '周',
      '遊': '游',
      '錄': '录',
      '鑰': '钥',
      '隊': '队',
      '陽': '阳',
      '陰': '阴',
      '陣': '阵',
      '階': '阶',
      '離': '离',
      '難': '难',
      '靈': '灵',
      '響': '响',
      '頂': '顶',
      '順': '顺',
      '預': '预',
      '須': '须',
      '頁': '页',
      '館': '馆',
      '體': '体',
      '驗': '验',
      '鬥': '斗',
    };
    final buf = StringBuffer();
    for (final ch in text.split('')) {
      buf.write(map[ch] ?? ch);
    }
    return buf.toString();
  }

  /// 点击集数时，优先使用 CMS 源
  void _onEpisodeTap(int index) {
    // CMS 来源的动漫直接用已加载的集数播放
    if (_anime.sourcePlugin.startsWith('cms_')) {
      _playFromCurrentEpisodes(index);
      return;
    }

    if (_cmsAnimeUrl != null) {
      // 有 CMS 源 → 加载 CMS 集数并跳转
      _playFromCms(index);
    } else {
      // 无 CMS 源 → 提示
      ErrorHandler.showInfo(context, '暂无可用视频源');
    }
  }

  /// 从已加载的集数直接播放（CMS来源专用）
  void _playFromCurrentEpisodes(int index) {
    final episodes = _store.currentEpisodes;
    if (episodes.isEmpty || index >= episodes.length) {
      ErrorHandler.showInfo(context, '暂无集数信息');
      return;
    }

    final ep = episodes[index];
    final detail = _store.currentDetail;
    final animeName = detail?['name']?.toString().trim();
    final coverUrl = detail?['cover']?.toString() ?? _anime.cover ?? '';
    Modular.to.pushNamed(
      '/player?url=${Uri.encodeComponent(ep.url)}'
      '&title=${Uri.encodeComponent(ep.name)}'
      '&animeUrl=${Uri.encodeComponent(_libraryAnimeUrl)}'
      '&animeName=${Uri.encodeComponent(
        animeName?.isNotEmpty == true ? animeName! : _animeName,
      )}'
      '&cover=${Uri.encodeComponent(coverUrl)}'
      '&ep=$index'
      '&source=${Uri.encodeComponent(_anime.sourcePlugin)}'
      '${widget.contentId?.isNotEmpty == true ? '&contentId=${Uri.encodeComponent(widget.contentId!)}' : ''}',
    );
  }

  Future<void> _toggleTrack({
    required String name,
    required String? coverUrl,
    required String? status,
    required int totalEpisodes,
  }) async {
    // store 列表是唯一事实源：先按当前状态决定动作，写完回读刷新本地缓存。
    if (!_collectStore.isTracked(_libraryAnimeUrl)) {
      await _collectStore.addTrack(TrackItem(
        animeName: name,
        animeUrl: _libraryAnimeUrl,
        contentId: widget.contentId,
        sourcePlugin: _anime.sourcePlugin,
        cover: coverUrl,
        status: status,
        totalEpisodes: totalEpisodes,
      ));
      if (mounted) ErrorHandler.showSuccess(context, '已追番');
    } else {
      await _collectStore.removeTrack(_libraryAnimeUrl);
      if (mounted) ErrorHandler.showInfo(context, '已取消追番');
    }
    if (mounted) {
      setState(() => _tracked = _collectStore.isTracked(_libraryAnimeUrl));
    }
  }

  Future<void> _toggleCollect({
    required String name,
    required String? coverUrl,
    required String summary,
  }) async {
    if (!_collectStore.isCollected(_libraryAnimeUrl)) {
      await _collectStore.addCollect(CollectItem(
        animeName: name,
        animeUrl: _libraryAnimeUrl,
        contentId: widget.contentId,
        sourcePlugin: _anime.sourcePlugin,
        cover: coverUrl,
        description: summary,
      ));
      if (mounted) ErrorHandler.showSuccess(context, '已收藏');
    } else {
      await _collectStore.removeCollect(_libraryAnimeUrl);
      if (mounted) ErrorHandler.showInfo(context, '已取消收藏');
    }
    if (mounted) {
      setState(() => _collected = _collectStore.isCollected(_libraryAnimeUrl));
    }
  }

  void _updateDetailState(VoidCallback update) => setState(update);

  @override
  Widget build(BuildContext context) => _buildDetailView();
}
