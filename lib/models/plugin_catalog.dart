import 'package:flutter/foundation.dart';

@immutable
class PluginCatalogCategory {
  const PluginCatalogCategory({
    required this.id,
    required this.label,
    this.facets = const {},
  });

  final String id;
  final String label;
  final Map<String, String> facets;

  Map<String, Object?> toJson() => {
        'id': id,
        'label': label,
        if (facets.isNotEmpty)
          'facets': {
            for (final key in facets.keys.toList()..sort()) key: facets[key],
          },
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PluginCatalogCategory &&
          id == other.id &&
          label == other.label &&
          mapEquals(facets, other.facets);

  @override
  int get hashCode => Object.hash(
        id,
        label,
        Object.hashAll(
          (facets.keys.toList()..sort()).map(
            (key) => Object.hash(key, facets[key]),
          ),
        ),
      );
}

@immutable
class PluginCatalogConfig {
  const PluginCatalogConfig({
    required this.kind,
    required this.categories,
    this.sorts = const {},
  });

  static const supportedKind = 'mac_cms_v1';
  static const supportedSorts = {'updated', 'score', 'popularity'};

  final String kind;
  final List<PluginCatalogCategory> categories;
  final Set<String> sorts;

  static PluginCatalogConfig? tryFromJson(Object? value) {
    if (value is! Map) return null;
    final kind = value['kind']?.toString().trim() ?? '';
    if (kind != supportedKind) return null;
    final rawCategories = value['categories'];
    if (rawCategories is! List || rawCategories.isEmpty) return null;

    final categories = <PluginCatalogCategory>[];
    final ids = <String>{};
    for (final raw in rawCategories) {
      if (raw is! Map) return null;
      final id = raw['id']?.toString().trim() ?? '';
      final label = raw['label']?.toString().trim() ?? '';
      if (id.isEmpty || label.isEmpty || !ids.add(id)) return null;
      final facets = _parseFacets(raw['facets']);
      if (facets == null) return null;
      categories.add(
        PluginCatalogCategory(id: id, label: label, facets: facets),
      );
    }

    final rawSorts = value['sorts'];
    final sorts = <String>{};
    if (rawSorts != null) {
      if (rawSorts is! List) return null;
      for (final raw in rawSorts) {
        final sort = raw?.toString().trim() ?? '';
        if (!supportedSorts.contains(sort)) return null;
        sorts.add(sort);
      }
    }
    return PluginCatalogConfig(
      kind: kind,
      categories: List.unmodifiable(categories),
      sorts: Set.unmodifiable(sorts),
    );
  }

  static Map<String, String>? _parseFacets(Object? value) {
    if (value == null) return const {};
    if (value is! Map) return null;
    final facets = <String, String>{};
    for (final entry in value.entries) {
      final key = entry.key.toString().trim();
      final facetValue = entry.value?.toString().trim() ?? '';
      if (!_isValidFacet(key, facetValue)) return null;
      facets[key] = facetValue;
    }
    return Map.unmodifiable(facets);
  }

  static bool _isValidFacet(String key, String value) {
    return switch (key) {
      'region' => const {'jp', 'cn', 'kr', 'western', 'other'}.contains(value),
      'genre' => _canonicalGenres.contains(value),
      'season' => const {'winter', 'spring', 'summer', 'fall'}.contains(value),
      'format' => const {
          'tv',
          'movie',
          'ova',
          'ona',
          'special',
          'music',
        }.contains(value),
      'status' => const {
          'upcoming',
          'airing',
          'completed',
          'hiatus',
          'cancelled',
        }.contains(value),
      'year' => _isValidYear(value),
      _ => false,
    };
  }

  static bool _isValidYear(String value) {
    final year = int.tryParse(value);
    return year != null && year >= 1900 && year <= 2200;
  }

  Map<String, Object?> toJson() => {
        'kind': kind,
        'categories': categories.map((category) => category.toJson()).toList(),
        if (sorts.isNotEmpty) 'sorts': sorts.toList()..sort(),
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PluginCatalogConfig &&
          kind == other.kind &&
          listEquals(categories, other.categories) &&
          setEquals(sorts, other.sorts);

  @override
  int get hashCode => Object.hash(
        kind,
        Object.hashAll(categories),
        Object.hashAll(sorts.toList()..sort()),
      );
}

abstract final class PluginCatalogDefaults {
  static PluginCatalogConfig? forPlugin(String api, String baseUrl) {
    final normalizedBase = baseUrl.trim().replaceFirst(RegExp(r'/+$'), '');
    return switch ((api, normalizedBase)) {
      ('cms_yinhua', 'https://www.yinhuadm.xyz') => yinhua,
      ('cms_ffzy', 'https://cj.ffzyapi.com') => ffzy,
      _ => null,
    };
  }

  static const yinhua = PluginCatalogConfig(
    kind: PluginCatalogConfig.supportedKind,
    categories: [
      PluginCatalogCategory(
        id: '10',
        label: '日本动漫',
        facets: {'region': 'jp'},
      ),
      PluginCatalogCategory(
        id: '9',
        label: '国产动漫',
        facets: {'region': 'cn'},
      ),
      PluginCatalogCategory(
        id: '11',
        label: '欧美动漫',
        facets: {'region': 'western'},
      ),
      PluginCatalogCategory(
        id: '12',
        label: '港台动漫',
        facets: {'region': 'cn'},
      ),
    ],
    sorts: {'updated', 'score', 'popularity'},
  );

  static const ffzy = PluginCatalogConfig(
    kind: PluginCatalogConfig.supportedKind,
    categories: [
      PluginCatalogCategory(
        id: '30',
        label: '日韩动漫',
        facets: {'region': 'jp'},
      ),
      PluginCatalogCategory(
        id: '29',
        label: '国产动漫',
        facets: {'region': 'cn'},
      ),
      PluginCatalogCategory(
        id: '31',
        label: '欧美动漫',
        facets: {'region': 'western'},
      ),
    ],
    sorts: {'updated', 'score', 'popularity'},
  );
}

const _canonicalGenres = {
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
