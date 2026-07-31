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

  test('unknown legacy type in catalog cache deletes only that cache',
      () async {
    const cacheName = 'catalog_test_recoverable_cache';
    const unrelatedName = 'catalog_test_unrelated_library';
    final legacyCache = await Hive.openBox<Object?>(cacheName);
    await legacyCache.put('stale', const {'schemaVersion': 0});
    await legacyCache.close();
    final unrelated = await Hive.openBox<Object?>(unrelatedName);
    await unrelated.put('history', 'preserved');
    var attempts = 0;

    final recovered = await openRecoverableCatalogCacheBox(
      name: cacheName,
      openBox: (name) async {
        attempts += 1;
        if (attempts == 1) {
          throw HiveError('Cannot read, unknown typeId: 44.');
        }
        return Hive.openBox<Object?>(name);
      },
      deleteBoxFromDisk: Hive.deleteBoxFromDisk,
    );

    expect(attempts, 2);
    expect(recovered.keys, isEmpty);
    expect(unrelated.get('history'), 'preserved');
  });

  test('waits for a failed Hive open to release the cache file lock', () async {
    const cacheName = 'catalog_test_locked_cache';
    final legacyCache = await Hive.openBox<Object?>(cacheName);
    await legacyCache.put('stale', const {'schemaVersion': 0});
    await legacyCache.close();
    var openAttempts = 0;
    var deleteAttempts = 0;

    final recovered = await openRecoverableCatalogCacheBox(
      name: cacheName,
      openBox: (name) async {
        openAttempts += 1;
        if (openAttempts == 1) {
          throw HiveError('Cannot read, unknown typeId: 44.');
        }
        return Hive.openBox<Object?>(name);
      },
      deleteBoxFromDisk: (name) async {
        deleteAttempts += 1;
        if (deleteAttempts < 3) {
          throw const FileSystemException(
            'Cannot delete file',
            cacheName,
            OSError('The process cannot access the file', 32),
          );
        }
        await Hive.deleteBoxFromDisk(name);
      },
    );

    expect(deleteAttempts, 3);
    expect(recovered.keys, isEmpty);
  });

  test('non-type corruption errors preserve the catalog cache', () async {
    const cacheName = 'catalog_test_preserved_cache';
    final cache = await Hive.openBox<Object?>(cacheName);
    await cache.put('query', const {'schemaVersion': 1});
    await cache.close();

    await expectLater(
      openRecoverableCatalogCacheBox(
        name: cacheName,
        openBox: (_) async => throw HiveError('Box is already open.'),
        deleteBoxFromDisk: Hive.deleteBoxFromDisk,
      ),
      throwsA(
        isA<HiveError>().having(
          (error) => error.message,
          'message',
          'Box is already open.',
        ),
      ),
    );

    final preserved = await Hive.openBox<Object?>(cacheName);
    expect(preserved.get('query'), const {'schemaVersion': 1});
  });
}
