import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:weila/services/catalog/catalog_hive_stores.dart';

void main() {
  late Directory directory;

  setUpAll(() async {
    directory = await Directory.systemTemp.createTemp('weila-catalog-hive-');
    Hive.init(directory.path);
  });

  tearDownAll(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  test('versioned catalog maps round-trip through Hive boxes', () async {
    final entries = await Hive.openBox<Object?>('catalog_test_entries');
    final refs = await Hive.openBox<Object?>('catalog_test_refs');
    final cache = await Hive.openBox<Object?>('catalog_test_cache');
    final stores = CatalogHiveStores(
      entriesBox: entries,
      referencesBox: refs,
      queryCacheBox: cache,
    );

    stores.entryStore['content-1'] = const {'schemaVersion': 1, 'name': 'A'};
    stores.referenceStore['ref-1'] = const {'schemaVersion': 1};
    stores.queryCacheStore['query-1'] = const {'schemaVersion': 1};
    await stores.persist();

    final restored = CatalogHiveStores(
      entriesBox: entries,
      referencesBox: refs,
      queryCacheBox: cache,
    );
    expect(restored.entryStore['content-1'], isA<Map>());
    expect(restored.referenceStore, contains('ref-1'));
    expect(restored.queryCacheStore, contains('query-1'));

    restored.queryCacheStore.clear();
    await restored.persist();
    expect(cache.keys, isEmpty);
  });
}
