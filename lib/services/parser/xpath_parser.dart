import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart';

/// 解析结果
class ParseResult {
  final String? name;
  final String? url;
  final String? cover;
  final String? description;

  const ParseResult({this.name, this.url, this.cover, this.description});
}

/// 章节解析结果
class EpisodeResult {
  final String name;
  final String url;
  final int index;

  const EpisodeResult({required this.name, required this.url, this.index = 0});
}

/// 视频源解析结果
class VideoSource {
  final String name;
  final String url;

  const VideoSource({required this.name, required this.url});
}

/// XPath/CSS 选择器解析器
/// Kazumi 用 xpath_selector，我们用 CSS 选择器（html 包自带）
class XPathParser {
  /// 解析 HTML 字符串
  static Document parseHtml(String html) {
    return html_parser.parse(html);
  }

  /// CSS 选择器提取所有元素
  static List<Element> queryAll(Document doc, String selector) {
    if (selector.isEmpty) return [];
    return doc.querySelectorAll(selector);
  }

  /// CSS 选择器提取单个元素
  static Element? queryOne(Document doc, String selector) {
    if (selector.isEmpty) return null;
    return doc.querySelector(selector);
  }

  /// 提取文本
  static String? text(Element? el) => el?.text.trim();

  /// 提取属性
  static String? attr(Element? el, String name) => el?.attributes[name];

  /// 提取链接
  static String? href(Element? el) => attr(el, 'href');

  /// 解析搜索结果
  /// [html] HTML内容
  /// [plugin] 插件配置（包含选择器）
  static List<ParseResult> parseSearchResults(
    String html, {
    required String listSelector,
    required String nameSelector,
    required String linkSelector,
    String? coverSelector,
    String? descSelector,
    String baseUrl = '',
  }) {
    final doc = parseHtml(html);
    final items = queryAll(doc, listSelector);
    final results = <ParseResult>[];

    for (final item in items) {
      final name = text(item.querySelector(nameSelector));
      if (name == null || name.isEmpty) continue;

      var url = href(item.querySelector(linkSelector));
      if (url != null && !url.startsWith('http')) {
        url = _resolveUrl(baseUrl, url);
      }

      String? cover;
      if (coverSelector != null && coverSelector.isNotEmpty) {
        cover = attr(item.querySelector(coverSelector), 'src') ??
                attr(item.querySelector(coverSelector), 'data-src');
        if (cover != null && !cover.startsWith('http')) {
          cover = _resolveUrl(baseUrl, cover);
        }
      }

      String? desc;
      if (descSelector != null && descSelector.isNotEmpty) {
        desc = text(item.querySelector(descSelector));
      }

      results.add(ParseResult(
        name: name,
        url: url,
        cover: cover,
        description: desc,
      ));
    }

    return results;
  }

  /// 解析章节列表
  static List<EpisodeResult> parseEpisodes(
    String html, {
    required String listSelector,
    required String nameSelector,
    required String linkSelector,
    String baseUrl = '',
  }) {
    final doc = parseHtml(html);
    final items = queryAll(doc, listSelector);
    final episodes = <EpisodeResult>[];

    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      final name = text(item.querySelector(nameSelector)) ?? '第${i + 1}集';
      var url = href(item.querySelector(linkSelector));
      if (url != null && !url.startsWith('http')) {
        url = _resolveUrl(baseUrl, url);
      }
      if (url == null || url.isEmpty) continue;

      episodes.add(EpisodeResult(name: name, url: url, index: i));
    }

    return episodes;
  }

  /// 解析视频源
  static List<VideoSource> parseVideoSources(
    String html, {
    required String listSelector,
    required String nameSelector,
    required String linkSelector,
    String baseUrl = '',
  }) {
    final doc = parseHtml(html);
    final items = queryAll(doc, listSelector);
    final sources = <VideoSource>[];

    for (final item in items) {
      final name = text(item.querySelector(nameSelector)) ?? '源';
      var url = href(item.querySelector(linkSelector)) ??
                attr(item.querySelector(linkSelector), 'data-src');
      if (url != null && !url.startsWith('http')) {
        url = _resolveUrl(baseUrl, url);
      }
      if (url == null || url.isEmpty) continue;

      sources.add(VideoSource(name: name, url: url));
    }

    return sources;
  }

  /// 解析视频URL（从页面中提取 m3u8/mp4 等）
  static List<String> parseVideoUrls(String html) {
    final urls = <String>[];
    // 匹配 m3u8
    final m3u8Reg = RegExp(r'https?://[^\s"<>]+\.m3u8[^\s"<>]*');
    urls.addAll(m3u8Reg.allMatches(html).map((m) => m.group(0)!));
    // 匹配 mp4
    final mp4Reg = RegExp(r'https?://[^\s"<>]+\.mp4[^\s"<>]*');
    urls.addAll(mp4Reg.allMatches(html).map((m) => m.group(0)!));
    return urls.toSet().toList();
  }

  /// 相对URL转绝对URL
  static String _resolveUrl(String base, String relative) {
    if (relative.startsWith('//')) return 'https:$relative';
    if (relative.startsWith('/')) {
      final uri = Uri.parse(base);
      return '${uri.scheme}://${uri.host}$relative';
    }
    return '$base/$relative';
  }
}
