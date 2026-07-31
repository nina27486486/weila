import 'dart:io';

import 'package:hive_ce/hive.dart';

typedef CatalogCacheBoxOpener = Future<Box<Object?>> Function(String name);
typedef CatalogCacheBoxDeleter = Future<void> Function(String name);

Future<Box<Object?>> openRecoverableCatalogCacheBox({
  required String name,
  required CatalogCacheBoxOpener openBox,
  required CatalogCacheBoxDeleter deleteBoxFromDisk,
}) async {
  try {
    return await openBox(name);
  } on HiveError catch (error) {
    final unknownTypeId = RegExp(
      r'unknown typeId:\s*\d+',
      caseSensitive: false,
    ).hasMatch(error.message);
    if (!unknownTypeId) rethrow;
    const maximumDeleteAttempts = 20;
    for (var attempt = 1; attempt <= maximumDeleteAttempts; attempt++) {
      try {
        await deleteBoxFromDisk(name);
        break;
      } on FileSystemException catch (deleteError) {
        final sharingViolation = deleteError.osError?.errorCode == 32;
        if (!sharingViolation || attempt == maximumDeleteAttempts) rethrow;
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
    }
    return openBox(name);
  }
}

/// Owns the versioned catalog maps and serializes their Hive commits.
///
/// Catalog values intentionally remain versioned maps, so adding catalog
/// fields never consumes a global Hive typeId or invalidates legacy adapters.
class CatalogHiveStores {
  CatalogHiveStores({
    required Box<Object?> entriesBox,
    required Box<Object?> referencesBox,
    required Box<Object?> queryCacheBox,
  })  : _entriesBox = entriesBox,
        _referencesBox = referencesBox,
        _queryCacheBox = queryCacheBox,
        entryStore = _read(entriesBox),
        referenceStore = _read(referencesBox),
        queryCacheStore = _read(queryCacheBox);

  final Box<Object?> _entriesBox;
  final Box<Object?> _referencesBox;
  final Box<Object?> _queryCacheBox;

  final Map<String, Object?> entryStore;
  final Map<String, Object?> referenceStore;
  final Map<String, Object?> queryCacheStore;

  Future<void> _pending = Future<void>.value();

  Future<void> persist() {
    final operation = _pending.then((_) async {
      await _sync(_entriesBox, entryStore);
      await _sync(_referencesBox, referenceStore);
      await _sync(_queryCacheBox, queryCacheStore);
    });
    _pending = operation.catchError((_) {});
    return operation;
  }

  static Map<String, Object?> _read(Box<Object?> box) => {
        for (final key in box.keys) key.toString(): box.get(key),
      };

  static Future<void> _sync(
    Box<Object?> box,
    Map<String, Object?> values,
  ) async {
    final obsolete = box.keys
        .where((key) => !values.containsKey(key.toString()))
        .toList(growable: false);
    if (obsolete.isNotEmpty) await box.deleteAll(obsolete);
    if (values.isNotEmpty) await box.putAll(values);
  }
}
