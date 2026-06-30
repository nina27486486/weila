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
import '../../models/collect_item.dart';
import '../../models/track_item.dart';
import '../../services/plugin/plugin_service.dart';
import '../../services/jikan/jikan_service.dart';
import '../../services/http/http_client.dart';
import '../../services/artwork_palette_service.dart';
import '../../utils/animations.dart';
import '../../widgets/artwork_components.dart';
import '../../widgets/cover_image.dart';
import '../../widgets/vira_page_chrome.dart';
import '../../utils/error_handler.dart';

class DetailPage extends StatefulWidget {
  final String animeUrl;
  final String animeName;

  const DetailPage({
    super.key,
    required this.animeUrl,
    required this.animeName,
  });

  @override
  State<DetailPage> createState() => _DetailPageState();
}

class _DetailPageState extends State<DetailPage> {
  final _store = AnimeStore();
  final _collectStore = HistoryCollectStore();
  final _pluginService = PluginService();
  late Anime _anime;
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
  bool _searchingSource = false;

  @override
  void initState() {
    super.initState();
    final sourcePlugin = widget.animeUrl.contains('anilist:')
        ? 'anilist'
        : widget.animeUrl.contains('bgm.tv')
            ? 'bangumi'
            : widget.animeUrl.startsWith('jikan:')
                ? 'jikan'
                : widget.animeUrl.contains('cms_')
                    ? widget.animeUrl.split(':').first
                    : 'unknown';

    _anime = Anime(
      name: widget.animeName,
      url: widget.animeUrl,
      sourcePlugin: sourcePlugin,
    );
    _collected = _collectStore.isCollected(widget.animeUrl);
    _tracked = _collectStore.isTracked(widget.animeUrl);

    // 顺序加载：先加载元数据+集数，再搜索 CMS 播放源
    // 避免竞态条件：如果两者并行，loadEpisodes 可能在 CMS 集数加载后
    // 执行 clear()，把真实的 CMS 集数覆盖为 Jikan 空壳集数
    _initData(sourcePlugin);
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
    setState(() => _searchingSource = true);
    try {
      Log.d('Detail',
          '开始搜索播放源: ${widget.animeName} (source: ${_anime.sourcePlugin})');

      Anime? cmsResult;

      // 预处理：去掉季度/季数后缀，得到基础标题
      final baseTitle = _stripSeasonInfo(widget.animeName);
      Log.d('Detail', '基础标题: "$baseTitle"');

      // ── 第0轮（最优）：通过 Bangumi 桥接获取中文名称 ──
      if (_anime.sourcePlugin == 'jikan' || _anime.sourcePlugin == 'anilist') {
        // 先用基础标题搜 Bangumi（更短的关键词匹配率更高）
        for (final bgmKeyword in {baseTitle, widget.animeName}) {
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
      if (cmsResult == null && baseTitle != widget.animeName) {
        final results = await _pluginService.searchCmsOnly(baseTitle);
        cmsResult = results.firstOrNull;
        Log.d('Detail', '第1轮(基础标题CMS): ${cmsResult?.name ?? "无"}');
      }

      // 第1.5轮：用完整名称搜索 CMS
      if (cmsResult == null) {
        final results = await _pluginService.searchAll(widget.animeName);
        cmsResult =
            results.where((a) => a.sourcePlugin.startsWith('cms_')).firstOrNull;
        Log.d('Detail', '第1.5轮(完整名CMS): ${cmsResult?.name ?? "无"}');
      }

      // 第2轮：用 Jikan 日文原标题中的汉字转简体搜索
      if (cmsResult == null && _anime.sourcePlugin == 'jikan') {
        final malId = int.tryParse(widget.animeUrl.replaceFirst('jikan:', ''));
        String? jaTitle;
        if (malId != null) {
          final detail = await JikanService().getAnimeDetails(malId);
          if (detail != null) {
            jaTitle = detail['name_ja']?.toString();
          }
        }
        // 用日文标题的汉字部分转简体
        final titleForKanji = jaTitle ?? widget.animeName;
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

      if (cmsResult != null && mounted) {
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
      if (mounted) setState(() => _searchingSource = false);
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
    setState(() => _searchingSource = true);
    List<Anime> cmsResults;
    try {
      cmsResults = await _pluginService.searchCmsOnly(trimmedKeyword);
    } catch (e) {
      Log.e('Detail', '手动搜索失败', e);
      if (mounted) setState(() => _searchingSource = false);
      return;
    }
    if (mounted) setState(() => _searchingSource = false);

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

    if (selected != null && mounted) {
      Log.d('Detail', '手动选择播放源: ${selected.name} (${selected.url})');
      setState(() {
        _cmsAnimeUrl = selected.url;
        _cmsSourceName = _pluginService.plugins
                .where((p) => p.api == selected.sourcePlugin)
                .firstOrNull
                ?.name ??
            selected.sourcePlugin;
      });
      await _loadCmsEpisodes(selected);
    }
  }

  /// 加载 CMS 集数并替换 Store 中的占位集数
  Future<void> _loadCmsEpisodes(Anime cmsAnime) async {
    try {
      final episodes = await _pluginService.getEpisodes(cmsAnime);
      if (episodes.isNotEmpty && mounted) {
        _store.currentEpisodes.clear();
        _store.currentEpisodes.addAll(episodes);
        Log.d('Detail', '已加载 ${episodes.length} 个 CMS 集数');
      }
    } catch (e) {
      Log.e('Detail', '加载 CMS 集数失败', e);
    }
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
    Modular.to.pushNamed(
      '/player?url=${Uri.encodeComponent(ep.url)}'
      '&title=${Uri.encodeComponent(ep.name)}'
      '&animeUrl=${Uri.encodeComponent(widget.animeUrl)}'
      '&ep=$index'
      '&source=${Uri.encodeComponent(_anime.sourcePlugin)}',
    );
  }

  void _toggleTrack({
    required String name,
    required String? coverUrl,
    required String? status,
    required int totalEpisodes,
  }) {
    setState(() => _tracked = !_tracked);
    if (_tracked) {
      _collectStore.addTrack(TrackItem(
        animeName: name,
        animeUrl: widget.animeUrl,
        sourcePlugin: _anime.sourcePlugin,
        cover: coverUrl,
        status: status,
        totalEpisodes: totalEpisodes,
      ));
      ErrorHandler.showSuccess(context, '已追番');
    } else {
      _collectStore.removeTrack(widget.animeUrl);
      ErrorHandler.showInfo(context, '已取消追番');
    }
  }

  void _toggleCollect({
    required String name,
    required String? coverUrl,
    required String summary,
  }) {
    setState(() => _collected = !_collected);
    if (_collected) {
      _collectStore.addCollect(CollectItem(
        animeName: name,
        animeUrl: widget.animeUrl,
        sourcePlugin: _anime.sourcePlugin,
        cover: coverUrl,
        description: summary,
      ));
      ErrorHandler.showSuccess(context, '已收藏');
    } else {
      _collectStore.removeCollect(widget.animeUrl);
      ErrorHandler.showInfo(context, '已取消收藏');
    }
  }

  Future<void> _playFromCms(int episodeIndex) async {
    try {
      // 加载 CMS 集数
      final cmsAnime = Anime(
        name: widget.animeName,
        url: _cmsAnimeUrl!,
        sourcePlugin: _cmsAnimeUrl!.split(':').first,
      );
      final episodes = await _pluginService.getEpisodes(cmsAnime);

      if (episodes.isEmpty) {
        if (mounted) {
          ErrorHandler.showInfo(context, '未找到集数信息');
        }
        return;
      }

      // 找到对应集数（或第一集）
      final epIndex = episodeIndex < episodes.length ? episodeIndex : 0;
      final ep = episodes[epIndex];

      if (mounted) {
        Modular.to.pushNamed(
          '/player?url=${Uri.encodeComponent(ep.url)}'
          '&title=${Uri.encodeComponent(ep.name)}'
          '&animeUrl=${Uri.encodeComponent(_cmsAnimeUrl!)}'
          '&ep=$epIndex'
          '&source=${Uri.encodeComponent(_cmsAnimeUrl!.split(':').first)}',
        );
      }
    } catch (e) {
      Log.d('Detail', 'CMS 播放失败: $e');
      if (mounted) {
        ErrorHandler.showError(context, '播放失败: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ViraPageScaffold(
      activeDestination: null,
      onDestinationSelected: _openDestination,
      onSearch: () => Modular.to.pushNamed('/search'),
      onThemeToggle: () => Modular.get<ThemeStore>().toggleTheme(),
      onProfile: () => Modular.to.pushNamed('/settings'),
      child: Observer(
        builder: (_) {
          final detail = _store.currentDetail;
          final coverUrl = detail?['cover'] ?? _anime.cover;
          final name = detail?['name'] ?? widget.animeName;
          final nameJa = detail?['name_ja'] ?? '';
          final summary = _cleanDisplayText(detail?['summary']);
          final rating = detail?['rating'];
          final ratingCount = detail?['rating_count'];
          final rank = detail?['rank'];
          final tags = (detail?['tags'] as List?)?.cast<String>() ?? [];
          final date = detail?['date'] ?? '';
          final platform = detail?['platform'] ?? '';
          final totalEps = detail?['total_episodes'];

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeroPanel(
                        coverUrl: coverUrl?.toString(),
                        name: name.toString(),
                        nameJa: nameJa.toString(),
                        summary: summary.toString(),
                        rating: rating is num ? rating.toDouble() : null,
                        ratingCount: ratingCount,
                        rank: rank,
                        tags: tags,
                        date: date.toString(),
                        platform: platform.toString(),
                        totalEps: totalEps,
                        status: detail?['status']?.toString(),
                      ),
                      if (summary.toString().isNotEmpty) ...[
                        const SizedBox(height: 18),
                        _buildSummaryCard(summary.toString()),
                      ],
                      const SizedBox(height: 26),
                      _buildEpisodeToolbar(),
                      const SizedBox(height: 14),
                    ],
                  ),
                ),
              ),
              _buildEpisodeSliver(),
              SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          );
        },
      ),
    );
  }

  void _openDestination(ViraDestination destination) {
    final route = switch (destination) {
      ViraDestination.home => '/',
      ViraDestination.discover => '/category',
      ViraDestination.following => '/track',
      ViraDestination.library => '/collect',
      ViraDestination.downloads => '/download',
    };
    Modular.to.navigate(route);
  }

  Widget _buildHeroPanel({
    required String? coverUrl,
    required String name,
    required String nameJa,
    required String summary,
    required double? rating,
    required dynamic ratingCount,
    required dynamic rank,
    required List<String> tags,
    required String date,
    required String platform,
    required dynamic totalEps,
    required String? status,
  }) {
    final totalEpisodeCount = totalEps is int
        ? totalEps
        : int.tryParse(totalEps?.toString() ?? '') ?? 0;

    Widget buildPanel(ArtworkPalette palette) {
      return Container(
        key: const ValueKey('detail-ambient-hero'),
        height: 410,
        decoration: BoxDecoration(
          color: context.colors.bgCard,
          border: Border(
            top: BorderSide(color: context.colors.divider),
            bottom: BorderSide(color: context.colors.divider),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            AmbientArtworkBackdrop(
              palette: palette,
              child: const SizedBox.expand(),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Colors.black.withValues(alpha: 0.82),
                    context.colors.bgCard.withValues(alpha: 0.58),
                    Colors.black.withValues(alpha: 0.2),
                  ],
                  stops: const [0, 0.58, 1],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 26, 28, 24),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Hero(
                    tag: 'anime-cover-${widget.animeUrl}',
                    child: ArtworkParallax(
                      child: _DetailPoster(coverUrl: coverUrl),
                    ),
                  ),
                  const SizedBox(width: 28),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            if (date.isNotEmpty)
                              _InfoPill(
                                  icon: Icons.calendar_today_outlined,
                                  text: date),
                            if (platform.isNotEmpty)
                              _InfoPill(
                                  icon: Icons.tv_outlined, text: platform),
                            if (totalEpisodeCount > 0)
                              _InfoPill(
                                  icon: Icons.video_library_outlined,
                                  text: '$totalEpisodeCount集'),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            height: 1.08,
                            shadows: [
                              Shadow(blurRadius: 12, color: Colors.black87)
                            ],
                          ),
                        ),
                        if (nameJa.isNotEmpty && nameJa != name) ...[
                          const SizedBox(height: 8),
                          Text(
                            nameJa,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.58),
                              fontSize: 13,
                              height: 1.3,
                            ),
                          ),
                        ],
                        if (summary.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Text(
                            summary,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.72),
                              fontSize: 13,
                              height: 1.5,
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            if (rating != null) _buildScoreBadge(rating),
                            if (ratingCount != null)
                              _InfoPill(
                                  icon: Icons.people_alt_outlined,
                                  text: '${ratingCount.toString()}人评分'),
                            if (rank != null)
                              _InfoPill(
                                  icon: Icons.emoji_events_outlined,
                                  text: '排名 $rank',
                                  highlighted: true),
                            _buildSourceIndicator(),
                          ],
                        ),
                        if (tags.isNotEmpty) ...[
                          const SizedBox(height: 14),
                          Wrap(
                            spacing: 7,
                            runSpacing: 7,
                            children: tags
                                .take(5)
                                .map((tag) => _DetailTag(text: tag))
                                .toList(),
                          ),
                        ],
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            _HeroActionButton(
                              icon: Icons.play_arrow_rounded,
                              label: _store.currentEpisodes.isEmpty
                                  ? '等待片源'
                                  : '立即播放',
                              onTap: _store.currentEpisodes.isEmpty
                                  ? null
                                  : () => _onEpisodeTap(0),
                            ),
                            const SizedBox(width: 10),
                            _HeroIconButton(
                              icon: _tracked
                                  ? Icons.calendar_month
                                  : Icons.calendar_month_outlined,
                              active: _tracked,
                              tooltip: _tracked ? '已追番' : '追番',
                              onTap: () => _toggleTrack(
                                name: name,
                                coverUrl: coverUrl,
                                status: status,
                                totalEpisodes: totalEpisodeCount,
                              ),
                            ),
                            const SizedBox(width: 10),
                            _HeroIconButton(
                              icon: _collected
                                  ? Icons.bookmark
                                  : Icons.bookmark_border,
                              active: _collected,
                              tooltip: _collected ? '已收藏' : '收藏',
                              onTap: () => _toggleCollect(
                                name: name,
                                coverUrl: coverUrl,
                                summary: summary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final provider = CoverImage.providerFor(coverUrl);
    if (provider == null) return buildPanel(ArtworkPalette.fallback);
    return ArtworkPaletteBuilder(
      cacheKey: coverUrl!,
      provider: provider,
      builder: (_, palette) => buildPanel(palette),
    );
  }

  Widget _buildSummaryCard(String summary) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => setState(() => _descExpanded = !_descExpanded),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: context.colors.bgCard,
            border: Border(
              top: BorderSide(color: context.colors.divider),
              bottom: BorderSide(color: context.colors.divider),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.notes_rounded,
                      color: AppTheme.primaryBlue, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    '作品简介',
                    style: TextStyle(
                      color: context.colors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                summary,
                maxLines: _descExpanded ? null : 4,
                overflow: _descExpanded ? null : TextOverflow.ellipsis,
                style: TextStyle(
                  color: context.colors.textSecondary,
                  fontSize: 13,
                  height: 1.7,
                ),
              ),
              if (summary.length > 120)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    _descExpanded ? '收起简介' : '展开全部',
                    style: const TextStyle(
                      color: AppTheme.primaryBlue,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEpisodeToolbar() {
    return Row(
      children: [
        Text(
          '选集',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        if (_store.currentEpisodes.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Text(
              '${_store.currentEpisodes.length}集',
              style: TextStyle(color: context.colors.textMuted, fontSize: 12),
            ),
          ),
        const Spacer(),
        _ViewToggleButton(
          icon: Icons.grid_view_rounded,
          selected: _episodeGridView,
          tooltip: '网格视图',
          onTap: () => setState(() => _episodeGridView = true),
        ),
        const SizedBox(width: 6),
        _ViewToggleButton(
          icon: Icons.view_agenda_outlined,
          selected: !_episodeGridView,
          tooltip: '列表视图',
          onTap: () => setState(() => _episodeGridView = false),
        ),
      ],
    );
  }

  Widget _buildEpisodeSliver() {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      sliver: Observer(
        builder: (_) {
          if (_store.isLoadingEpisodes) {
            return SliverGrid(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 180,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 3.0,
              ),
              delegate: SliverChildBuilderDelegate(
                (_, __) => const _EpisodeSkeleton(),
                childCount: 10,
              ),
            );
          }

          if (_store.currentEpisodes.isEmpty) {
            return SliverToBoxAdapter(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(42),
                decoration: BoxDecoration(
                  color: context.colors.bgCard,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: context.colors.divider),
                ),
                child: Column(
                  children: [
                    Icon(Icons.video_library_outlined,
                        size: 48, color: context.colors.textMuted),
                    const SizedBox(height: 12),
                    Text('暂无章节信息',
                        style: TextStyle(color: context.colors.textSecondary)),
                  ],
                ),
              ),
            );
          }

          if (!_episodeGridView) {
            return SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  if (index.isOdd) return const SizedBox(height: 8);
                  final episodeIndex = index ~/ 2;
                  final ep = _store.currentEpisodes[episodeIndex];
                  return FadeSlideIn(
                    delay: Duration(
                      milliseconds: episodeIndex.clamp(0, 10) * 35,
                    ),
                    child: _EpisodeListTile(
                      episode: ep,
                      index: episodeIndex,
                      onTap: () => _onEpisodeTap(episodeIndex),
                    ),
                  );
                },
                childCount: _store.currentEpisodes.length * 2 - 1,
              ),
            );
          }

          return SliverGrid(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 190,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 3.15,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final ep = _store.currentEpisodes[index];
                return FadeSlideIn(
                  delay: Duration(milliseconds: index.clamp(0, 10) * 35),
                  child: _EpisodeChip(
                    episode: ep,
                    onTap: () => _onEpisodeTap(index),
                  ),
                );
              },
              childCount: _store.currentEpisodes.length,
            ),
          );
        },
      ),
    );
  }

  Widget _buildSourceIndicator() {
    // CMS 直接来源
    if (_anime.sourcePlugin.startsWith('cms_')) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppTheme.scoreGreen.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, size: 14, color: AppTheme.scoreGreen),
            SizedBox(width: 4),
            Text(
              '视频源: ${_anime.sourcePlugin.replaceAll("cms_", "")}',
              style: TextStyle(color: AppTheme.scoreGreen, fontSize: 11),
            ),
          ],
        ),
      );
    }
    // Jikan/Anilist/Bangumi 找到了 CMS 视频源
    if (_cmsAnimeUrl != null && _cmsSourceName != null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppTheme.scoreGreen.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, size: 14, color: AppTheme.scoreGreen),
            SizedBox(width: 4),
            Text(
              '视频源: $_cmsSourceName',
              style: TextStyle(color: AppTheme.scoreGreen, fontSize: 11),
            ),
          ],
        ),
      );
    }
    // 正在搜索视频源
    if (_searchingSource) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppTheme.scoreOrange.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                color: AppTheme.scoreOrange,
              ),
            ),
            SizedBox(width: 4),
            Text(
              '搜索视频源中...',
              style: TextStyle(color: AppTheme.scoreOrange, fontSize: 11),
            ),
          ],
        ),
      );
    }
    // 未找到视频源 → 显示警告 + 手动搜索按钮
    if (_anime.sourcePlugin == 'jikan' ||
        _anime.sourcePlugin == 'anilist' ||
        _anime.sourcePlugin == 'bangumi') {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.scoreRed.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.warning_amber, size: 14, color: AppTheme.scoreRed),
                SizedBox(width: 4),
                Text(
                  '暂无视频源',
                  style: TextStyle(color: AppTheme.scoreRed, fontSize: 11),
                ),
              ],
            ),
          ),
          SizedBox(width: 8),
          GestureDetector(
            onTap: _manualSearchSource,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                      color: AppTheme.primaryBlue.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.search, size: 14, color: AppTheme.primaryBlue),
                    SizedBox(width: 4),
                    Text(
                      '手动搜索',
                      style: TextStyle(
                          color: AppTheme.primaryBlue,
                          fontSize: 11,
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildScoreBadge(double score) {
    Color color;
    String label;
    if (score >= 8.0) {
      color = AppTheme.scoreGreen;
      label = '极好';
    } else if (score >= 7.0) {
      color = AppTheme.scoreOrange;
      label = '不错';
    } else {
      color = AppTheme.scoreRed;
      label = '还行';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.55)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              value: (score / 10).clamp(0.0, 1.0),
              color: color,
              backgroundColor: Colors.white.withValues(alpha: 0.12),
              strokeWidth: 3,
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                score.toStringAsFixed(1),
                style: TextStyle(
                  color: color,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
              Text(label,
                  style: TextStyle(color: color, fontSize: 10, height: 1.2)),
            ],
          ),
        ],
      ),
    );
  }
}

class _DetailPoster extends StatelessWidget {
  final String? coverUrl;

  const _DetailPoster({required this.coverUrl});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 178,
      height: 252,
      decoration: BoxDecoration(
        color: context.colors.bgCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryBlue.withValues(alpha: 0.22),
            blurRadius: 28,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: CoverImage(url: coverUrl, fit: BoxFit.cover),
    );
  }
}

class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool highlighted;

  const _InfoPill({
    required this.icon,
    required this.text,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = highlighted ? AppTheme.scoreOrange : Colors.white;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: (highlighted ? AppTheme.scoreOrange : Colors.white)
            .withValues(alpha: highlighted ? 0.16 : 0.09),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color.withValues(alpha: 0.82), size: 13),
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(
              color: color.withValues(alpha: 0.86),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailTag extends StatelessWidget {
  final String text;

  const _DetailTag({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.primaryBlue.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppTheme.primaryBlue.withValues(alpha: 0.16)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.82),
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _HeroActionButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _HeroActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  State<_HeroActionButton> createState() => _HeroActionButtonState();
}

class _HeroActionButtonState extends State<_HeroActionButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
          decoration: BoxDecoration(
            color: enabled
                ? (_hovering ? AppTheme.accentBlue : AppTheme.primaryBlue)
                : Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
            boxShadow: enabled && _hovering
                ? [
                    BoxShadow(
                      color: AppTheme.primaryBlue.withValues(alpha: 0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, color: Colors.white, size: 20),
              const SizedBox(width: 6),
              Text(
                widget.label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroIconButton extends StatefulWidget {
  final IconData icon;
  final bool active;
  final String tooltip;
  final VoidCallback onTap;

  const _HeroIconButton({
    required this.icon,
    required this.active,
    required this.tooltip,
    required this.onTap,
  });

  @override
  State<_HeroIconButton> createState() => _HeroIconButtonState();
}

class _HeroIconButtonState extends State<_HeroIconButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovering = true),
        onExit: (_) => setState(() => _hovering = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: widget.active
                  ? AppTheme.primaryBlue.withValues(alpha: 0.2)
                  : Colors.white.withValues(alpha: _hovering ? 0.14 : 0.08),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: widget.active
                    ? AppTheme.primaryBlue.withValues(alpha: 0.5)
                    : Colors.white.withValues(alpha: 0.08),
              ),
            ),
            child: Icon(
              widget.icon,
              color: widget.active
                  ? AppTheme.primaryBlue
                  : Colors.white.withValues(alpha: 0.84),
              size: 20,
            ),
          ),
        ),
      ),
    );
  }
}

class _ViewToggleButton extends StatefulWidget {
  final IconData icon;
  final bool selected;
  final String tooltip;
  final VoidCallback onTap;

  const _ViewToggleButton({
    required this.icon,
    required this.selected,
    required this.tooltip,
    required this.onTap,
  });

  @override
  State<_ViewToggleButton> createState() => _ViewToggleButtonState();
}

class _ViewToggleButtonState extends State<_ViewToggleButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovering = true),
        onExit: (_) => setState(() => _hovering = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 170),
            width: 34,
            height: 32,
            decoration: BoxDecoration(
              color: widget.selected
                  ? AppTheme.primaryBlue.withValues(alpha: 0.18)
                  : context.colors.bgCard,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: widget.selected || _hovering
                    ? AppTheme.primaryBlue.withValues(alpha: 0.36)
                    : context.colors.divider,
              ),
            ),
            child: Icon(
              widget.icon,
              size: 17,
              color: widget.selected
                  ? AppTheme.primaryBlue
                  : context.colors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _EpisodeSkeleton extends StatefulWidget {
  const _EpisodeSkeleton();

  @override
  State<_EpisodeSkeleton> createState() => _EpisodeSkeletonState();
}

class _EpisodeSkeletonState extends State<_EpisodeSkeleton> {
  bool _lit = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _pulse());
  }

  void _pulse() {
    if (!mounted) return;
    setState(() => _lit = !_lit);
    Future.delayed(const Duration(milliseconds: 760), _pulse);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 760),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(7),
        gradient: LinearGradient(
          colors: _lit
              ? [
                  context.colors.bgCard,
                  context.colors.bgHover,
                  context.colors.bgCard
                ]
              : [
                  context.colors.bgSurface.withValues(alpha: 0.55),
                  context.colors.bgCard,
                  context.colors.bgSurface.withValues(alpha: 0.55),
                ],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
      ),
    );
  }
}

class _EpisodeListTile extends StatefulWidget {
  final Episode episode;
  final int index;
  final VoidCallback onTap;

  const _EpisodeListTile({
    required this.episode,
    required this.index,
    required this.onTap,
  });

  @override
  State<_EpisodeListTile> createState() => _EpisodeListTileState();
}

class _EpisodeListTileState extends State<_EpisodeListTile> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 170),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: _hovering ? context.colors.bgHover : context.colors.bgCard,
            borderRadius: BorderRadius.circular(7),
            border: Border.all(
              color: _hovering
                  ? AppTheme.primaryBlue.withValues(alpha: 0.36)
                  : context.colors.divider,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  '${widget.index + 1}'.padLeft(2, '0'),
                  style: const TextStyle(
                    color: AppTheme.primaryBlue,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.episode.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _hovering
                        ? AppTheme.primaryBlue
                        : context.colors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Icon(
                Icons.play_arrow_rounded,
                color:
                    _hovering ? AppTheme.primaryBlue : context.colors.textMuted,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EpisodeChip extends StatefulWidget {
  final Episode episode;
  final VoidCallback onTap;
  const _EpisodeChip({required this.episode, required this.onTap});
  @override
  State<_EpisodeChip> createState() => _EpisodeChipState();
}

class _EpisodeChipState extends State<_EpisodeChip> {
  bool _hovering = false;
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: _hovering
                ? AppTheme.primaryBlue.withValues(alpha: 0.15)
                : context.colors.bgCard,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
                color: _hovering
                    ? AppTheme.primaryBlue.withValues(alpha: 0.3)
                    : Colors.transparent),
          ),
          child: Text(widget.episode.name,
              style: TextStyle(
                  color: _hovering
                      ? AppTheme.primaryBlue
                      : context.colors.textSecondary,
                  fontSize: 13)),
        ),
      ),
    );
  }
}
