import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:weila/models/catalog/catalog_enums.dart';
import 'package:weila/models/catalog/catalog_values.dart';
import 'package:weila/pages/discover/catalog_controller.dart';
import 'package:weila/services/catalog/catalog_repository.dart';

void main() {
  test('controller defaults to discovery and loads the first page', () async {
    final repository = _FakeRepository()
      ..handler = (query, forceRefresh) async => CatalogPage(
            items: [_content('discovery')],
            coverage: const CatalogQueryCoverage(
              modes: {CatalogMode.discovery},
              complete: true,
            ),
          );
    final controller = CatalogController(repository: repository);

    await controller.initialize();

    expect(controller.query.mode, CatalogMode.discovery);
    expect(controller.items.single.contentId, 'discovery');
    expect(controller.isLoading, isFalse);
    expect(controller.coverage.complete, isTrue);
  });

  test('genre toggles are AND query state and scalar filters remain single',
      () async {
    final repository = _FakeRepository()
      ..handler = (query, forceRefresh) async => const CatalogPage();
    final controller = CatalogController(repository: repository);
    await controller.initialize();

    await controller.toggleGenre('fantasy');
    await controller.toggleGenre('adventure');
    await controller.setYear(2024);
    await controller.setYear(2023);

    expect(controller.query.genres, {'fantasy', 'adventure'});
    expect(controller.query.year, 2023);
    expect(repository.queries.last.genres, {'fantasy', 'adventure'});
    expect(repository.queries.last.year, 2023);
    expect(repository.queries.last.cursor, isNull);
  });

  test('older requests cannot overwrite a newer filter generation', () async {
    final first = Completer<CatalogPage>();
    final second = Completer<CatalogPage>();
    final repository = _FakeRepository();
    var call = 0;
    repository.handler = (query, forceRefresh) {
      call++;
      return call == 1 ? first.future : second.future;
    };
    final controller = CatalogController(repository: repository);

    final initial = controller.initialize();
    final changed = controller.setYear(2024);
    second.complete(CatalogPage(items: [_content('new')]));
    await changed;
    first.complete(CatalogPage(items: [_content('old')]));
    await initial;

    expect(controller.items.single.contentId, 'new');
    expect(controller.query.year, 2024);
  });

  test('loadMore appends a cursor page without duplicating content IDs',
      () async {
    final repository = _FakeRepository()
      ..handler = (query, forceRefresh) async {
        if (query.cursor == null) {
          return CatalogPage(
            items: [_content('a')],
            nextCursor: 'next',
          );
        }
        return CatalogPage(
          items: [_content('a'), _content('b')],
          coverage: const CatalogQueryCoverage(complete: true),
        );
      };
    final controller = CatalogController(repository: repository);
    await controller.initialize();

    await controller.loadMore();

    expect(controller.items.map((item) => item.contentId), ['a', 'b']);
    expect(controller.hasMore, isFalse);
    expect(repository.queries.last.cursor, 'next');
  });

  test('refresh failure preserves visible results and exposes a cache warning',
      () async {
    final repository = _FakeRepository();
    repository.handler = (query, forceRefresh) async {
      if (forceRefresh) throw StateError('offline');
      return CatalogPage(items: [_content('cached')]);
    };
    final controller = CatalogController(repository: repository);
    await controller.initialize();

    await controller.refresh();

    expect(controller.items.single.contentId, 'cached');
    expect(controller.errorMessage, isNull);
    expect(controller.updateWarning, contains('旧缓存'));
    expect(controller.lastError, isA<StateError>());
  });

  test('repository stale-cache warning is surfaced without hiding results',
      () async {
    final repository = _FakeRepository()
      ..handler = (query, forceRefresh) async => const CatalogPage(
            items: [
              CatalogContent(
                contentId: 'cached',
                titles: CatalogTitles(primary: '缓存作品'),
              ),
            ],
            warning: '目录更新失败，正在显示旧缓存结果。',
          );
    final controller = CatalogController(repository: repository);

    await controller.initialize();

    expect(controller.items.single.contentId, 'cached');
    expect(controller.updateWarning, '目录更新失败，正在显示旧缓存结果。');
    expect(controller.errorMessage, isNull);
  });

  test(
      'switching tabs resets provider-only filters and defaults discovery again',
      () async {
    final repository = _FakeRepository()
      ..handler = (query, forceRefresh) async => const CatalogPage();
    final controller = CatalogController(repository: repository);
    await controller.initialize();

    await controller.setMode(CatalogMode.playable);
    await controller.setProvider('cms_test');
    await controller.setUpdatedWithin(const Duration(days: 7));
    await controller.setMode(CatalogMode.discovery);

    expect(controller.query.mode, CatalogMode.discovery);
    expect(controller.query.providerId, isNull);
    expect(controller.query.updatedWithin, isNull);
  });
}

CatalogContent _content(String id) => CatalogContent(
      contentId: id,
      titles: CatalogTitles(primary: id),
    );

class _FakeRepository implements CatalogRepository {
  late Future<CatalogPage> Function(CatalogQuery query, bool forceRefresh)
      handler;
  final List<CatalogQuery> queries = [];

  @override
  Future<CatalogPage> query(
    CatalogQuery query, {
    bool forceRefresh = false,
  }) {
    queries.add(query);
    return handler(query, forceRefresh);
  }

  @override
  Future<void> confirmPlayable(String contentId, PlayableRef ref) async {}

  @override
  Future<List<PlayableMatch>> findPlayable(String contentId) async => const [];

  @override
  Future<CatalogContent?> getById(String contentId) async => null;
}
