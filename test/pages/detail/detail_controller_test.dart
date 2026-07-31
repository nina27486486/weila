import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:weila/models/anime.dart';
import 'package:weila/models/catalog/catalog_values.dart';
import 'package:weila/pages/detail/detail_controller.dart';
import 'package:weila/services/catalog/catalog_repository.dart';

void main() {
  test('stale metadata resolution cannot replace the latest request', () async {
    final repository = _FakeCatalogRepository();
    final controller = DetailController(repository: repository);

    final first = controller.resolveBinding(
      contentId: 'first',
      legacyUrl: '',
      legacyName: '旧作品',
    );
    final second = controller.resolveBinding(
      contentId: 'second',
      legacyUrl: '',
      legacyName: '新作品',
    );
    repository.lookups['second']!.complete(null);
    expect((await second)?.name, '新作品');
    repository.lookups['first']!.complete(null);
    expect(await first, isNull);
  });

  test('source search state is generation isolated', () {
    final controller = DetailController(repository: _FakeCatalogRepository());

    final first = controller.beginSourceSearch();
    final second = controller.beginSourceSearch();
    expect(controller.searchingSource, isTrue);

    controller.finishSourceSearch(first);
    expect(controller.searchingSource, isTrue);
    controller.finishSourceSearch(second);
    expect(controller.searchingSource, isFalse);
  });

  test('confirmed CMS source persists structured playable identity', () async {
    final repository = _FakeCatalogRepository();
    final controller = DetailController(repository: repository);
    final anime = Anime(
      name: '作品',
      url: 'cms_ffzy:24840',
      sourcePlugin: 'cms_ffzy',
    );

    await controller.confirmPlayable(
      contentId: 'content-1',
      anime: anime,
      routeCount: 3,
    );

    expect(repository.confirmed.single.$1, 'content-1');
    expect(repository.confirmed.single.$2.providerId, 'cms_ffzy');
    expect(repository.confirmed.single.$2.sourceItemId, '24840');
    expect(repository.confirmed.single.$2.routeCount, 3);
  });

  test('invalid source identity is not persisted', () async {
    final repository = _FakeCatalogRepository();
    final controller = DetailController(repository: repository);

    await controller.confirmPlayable(
      contentId: 'content-1',
      anime: Anime(name: '作品', url: 'invalid', sourcePlugin: 'cms_ffzy'),
    );

    expect(repository.confirmed, isEmpty);
  });
}

class _FakeCatalogRepository implements CatalogRepository {
  final Map<String, Completer<CatalogContent?>> lookups = {};
  final List<(String, PlayableRef)> confirmed = [];

  @override
  Future<void> confirmPlayable(String contentId, PlayableRef ref) async {
    confirmed.add((contentId, ref));
  }

  @override
  Future<List<PlayableMatch>> findPlayable(String contentId) async => const [];

  @override
  Future<CatalogContent?> getById(String contentId) {
    return (lookups[contentId] ??= Completer<CatalogContent?>()).future;
  }

  @override
  Future<CatalogPage> query(
    CatalogQuery query, {
    bool forceRefresh = false,
  }) async {
    return const CatalogPage();
  }
}
