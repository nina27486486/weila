import 'package:flutter_test/flutter_test.dart';
import 'package:weila/models/catalog/catalog_values.dart';
import 'package:weila/services/catalog/catalog_detail_binding.dart';
import 'package:weila/services/catalog/catalog_repository.dart';

void main() {
  test('content route keeps stable library identity and selects playable ref',
      () async {
    final repository = _Repository(
      const CatalogContent(
        contentId: 'opaque-1',
        titles: CatalogTitles(primary: 'Romaji', chinese: '中文标题'),
        coverUrl: 'https://img.test/cover.jpg',
        playableRefs: [
          PlayableRef(
            providerId: 'cms_test',
            sourceItemId: '42',
            routeCount: 2,
          ),
        ],
      ),
    );

    final binding = await CatalogDetailBinding.resolve(
      contentId: 'opaque-1',
      legacyUrl: '',
      legacyName: '',
      repository: repository,
    );

    expect(binding.libraryUrl, 'catalog:opaque-1');
    expect(binding.sourceUrl, 'cms_test:42');
    expect(binding.sourcePlugin, 'cms_test');
    expect(binding.name, '中文标题');
    expect(binding.contentId, 'opaque-1');
  });

  test('metadata-only route selects an external identity without inventing CMS',
      () async {
    final repository = _Repository(
      const CatalogContent(
        contentId: 'opaque-2',
        titles: CatalogTitles(primary: 'Metadata only'),
        externalRefs: [ExternalRef(namespace: 'mal', id: '52991')],
      ),
    );

    final binding = await CatalogDetailBinding.resolve(
      contentId: 'opaque-2',
      legacyUrl: '',
      legacyName: '',
      repository: repository,
    );

    expect(binding.libraryUrl, 'catalog:opaque-2');
    expect(binding.sourceUrl, 'jikan:52991');
    expect(binding.sourcePlugin, 'jikan');
    expect(binding.catalogContent?.playableRefs, isEmpty);
  });

  test('legacy detail route remains unchanged when contentId is absent',
      () async {
    final binding = await CatalogDetailBinding.resolve(
      legacyUrl: 'cms_ffzy:7',
      legacyName: '旧片库作品',
      repository: _Repository(null),
    );

    expect(binding.libraryUrl, 'cms_ffzy:7');
    expect(binding.sourceUrl, 'cms_ffzy:7');
    expect(binding.sourcePlugin, 'cms_ffzy');
    expect(binding.name, '旧片库作品');
  });
}

class _Repository implements CatalogRepository {
  _Repository(this.content);

  final CatalogContent? content;

  @override
  Future<CatalogContent?> getById(String contentId) async => content;

  @override
  Future<void> confirmPlayable(String contentId, PlayableRef ref) async {}

  @override
  Future<List<PlayableMatch>> findPlayable(String contentId) async => const [];

  @override
  Future<CatalogPage> query(
    CatalogQuery query, {
    bool forceRefresh = false,
  }) async =>
      const CatalogPage();
}
