import '../../models/catalog/catalog_values.dart';

abstract interface class CatalogRepository {
  Future<CatalogPage> query(
    CatalogQuery query, {
    bool forceRefresh = false,
  });

  Future<CatalogContent?> getById(String contentId);

  Future<List<PlayableMatch>> findPlayable(String contentId);

  Future<void> confirmPlayable(String contentId, PlayableRef ref);
}
