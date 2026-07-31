import '../../models/anime.dart';
import '../../models/catalog/catalog_values.dart';
import '../../services/catalog/catalog_detail_binding.dart';
import '../../services/catalog/catalog_repository.dart';

class DetailController {
  DetailController({required CatalogRepository repository})
      : _repository = repository;

  final CatalogRepository _repository;

  int _detailGeneration = 0;
  int _sourceGeneration = 0;
  bool _searchingSource = false;
  bool _disposed = false;

  bool get searchingSource => _searchingSource;

  Future<CatalogDetailBinding?> resolveBinding({
    String? contentId,
    required String legacyUrl,
    required String legacyName,
  }) async {
    final generation = ++_detailGeneration;
    final binding = await CatalogDetailBinding.resolve(
      contentId: contentId,
      legacyUrl: legacyUrl,
      legacyName: legacyName,
      repository: _repository,
    );
    if (_disposed || generation != _detailGeneration) return null;
    return binding;
  }

  int beginSourceSearch() {
    _searchingSource = true;
    return ++_sourceGeneration;
  }

  bool isCurrentSourceSearch(int generation) {
    return !_disposed && generation == _sourceGeneration;
  }

  void finishSourceSearch(int generation) {
    if (!isCurrentSourceSearch(generation)) return;
    _searchingSource = false;
  }

  Future<void> confirmPlayable({
    required String? contentId,
    required Anime anime,
    int routeCount = 1,
  }) async {
    final normalizedContentId = contentId?.trim() ?? '';
    final separator = anime.url.indexOf(':');
    if (normalizedContentId.isEmpty || separator <= 0) return;
    final sourceItemId = anime.url.substring(separator + 1).trim();
    final providerId = anime.sourcePlugin.trim();
    if (sourceItemId.isEmpty || providerId.isEmpty) return;
    await _repository.confirmPlayable(
      normalizedContentId,
      PlayableRef(
        providerId: providerId,
        sourceItemId: sourceItemId,
        routeCount: routeCount < 1 ? 1 : routeCount,
      ),
    );
  }

  void dispose() {
    _disposed = true;
    _detailGeneration++;
    _sourceGeneration++;
    _searchingSource = false;
  }
}
