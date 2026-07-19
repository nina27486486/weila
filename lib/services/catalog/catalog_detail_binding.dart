import '../../models/catalog/catalog_values.dart';
import 'catalog_repository.dart';

class CatalogDetailBinding {
  const CatalogDetailBinding({
    required this.libraryUrl,
    required this.sourceUrl,
    required this.sourcePlugin,
    required this.name,
    this.contentId,
    this.catalogContent,
  });

  final String libraryUrl;
  final String sourceUrl;
  final String sourcePlugin;
  final String name;
  final String? contentId;
  final CatalogContent? catalogContent;

  static Future<CatalogDetailBinding> resolve({
    String? contentId,
    required String legacyUrl,
    required String legacyName,
    required CatalogRepository repository,
  }) async {
    final normalizedContentId = _nonEmpty(contentId);
    final content = normalizedContentId == null
        ? null
        : await repository.getById(normalizedContentId);
    final selectedSource = content == null ? null : _sourceFor(content);
    final sourceUrl = selectedSource?.url ?? legacyUrl;
    final libraryUrl = legacyUrl.isNotEmpty
        ? legacyUrl
        : normalizedContentId == null
            ? sourceUrl
            : 'catalog:$normalizedContentId';
    final name = content == null
        ? legacyName
        : content.titles.chinese ?? content.titles.primary;
    return CatalogDetailBinding(
      libraryUrl: libraryUrl,
      sourceUrl: sourceUrl,
      sourcePlugin: selectedSource?.plugin ?? _pluginForLegacyUrl(sourceUrl),
      name: name,
      contentId: normalizedContentId,
      catalogContent: content,
    );
  }
}

({String url, String plugin})? _sourceFor(CatalogContent content) {
  final playable = content.playableRefs.firstOrNull;
  if (playable != null) {
    return (
      url: '${playable.providerId}:${playable.sourceItemId}',
      plugin: playable.providerId,
    );
  }
  for (final namespace in const ['anilist', 'mal', 'bangumi']) {
    final ref = content.externalRefs
        .where((candidate) => candidate.namespace == namespace)
        .firstOrNull;
    if (ref == null) continue;
    return switch (namespace) {
      'anilist' => (url: 'anilist:${ref.id}', plugin: 'anilist'),
      'mal' => (url: 'jikan:${ref.id}', plugin: 'jikan'),
      'bangumi' => (
          url: 'https://bgm.tv/subject/${ref.id}',
          plugin: 'bangumi',
        ),
      _ => throw StateError('unreachable'),
    };
  }
  return null;
}

String _pluginForLegacyUrl(String url) {
  if (url.contains('anilist:')) return 'anilist';
  if (url.contains('bgm.tv')) return 'bangumi';
  if (url.startsWith('jikan:')) return 'jikan';
  if (url.contains('cms_')) return url.split(':').first;
  return 'unknown';
}

String? _nonEmpty(String? value) {
  final normalized = value?.trim() ?? '';
  return normalized.isEmpty ? null : normalized;
}
