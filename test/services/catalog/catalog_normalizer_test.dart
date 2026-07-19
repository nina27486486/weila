import 'package:flutter_test/flutter_test.dart';
import 'package:weila/models/catalog/catalog_enums.dart';
import 'package:weila/services/catalog/catalog_normalizer.dart';

void main() {
  const normalizer = CatalogNormalizer();

  test('canonical genres cover the required catalog vocabulary', () {
    expect(CatalogNormalizer.canonicalGenres, {
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
    });
  });

  test('Chinese and English aliases normalize to canonical values', () {
    expect(
      normalizer.normalizeGenres(
        const ['动作 / Adventure', 'SCI-FI, 恋爱', '魔法少女', '异世界'],
      ),
      {'action', 'adventure', 'sciFi', 'romance', 'magicalGirl', 'isekai'},
    );
    expect(
      normalizer.normalizeTitle('  Frieren: Beyond Journey’s End！ '),
      'frierenbeyondjourneysend',
    );
    expect(normalizer.normalizeFormat('剧场版'), CatalogFormat.movie);
    expect(normalizer.normalizeFormat('TV Series'), CatalogFormat.tv);
    expect(normalizer.normalizeStatus('更新中'), CatalogStatus.airing);
    expect(
        normalizer.normalizeStatus('Finished Airing'), CatalogStatus.completed);
    expect(normalizer.normalizeRegion('日本'), CatalogRegion.japan);
    expect(normalizer.normalizeRegion('欧美'), CatalogRegion.western);
  });

  test('genre selection uses AND semantics after alias normalization', () {
    expect(
      normalizer.matchesAllGenres(
        contentGenres: const ['动作', '科幻', '冒险'],
        selectedGenres: const ['action', 'SCI FI'],
      ),
      isTrue,
    );
    expect(
      normalizer.matchesAllGenres(
        contentGenres: const ['动作', '科幻', '冒险'],
        selectedGenres: const ['action', 'romance'],
      ),
      isFalse,
    );
    expect(
      normalizer.matchesAllGenres(
        contentGenres: const ['动作'],
        selectedGenres: const [],
      ),
      isTrue,
    );
  });
}
