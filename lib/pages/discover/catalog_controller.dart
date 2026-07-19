import 'package:flutter/foundation.dart';

import '../../models/catalog/catalog_enums.dart';
import '../../models/catalog/catalog_values.dart';
import '../../services/catalog/catalog_repository.dart';
import '../../services/catalog/providers/catalog_provider.dart';

class CatalogController extends ChangeNotifier {
  CatalogController({
    required CatalogRepository repository,
    bool includeAdult = false,
  })  : _repository = repository,
        _query = CatalogQuery(includeAdult: includeAdult);

  final CatalogRepository _repository;

  CatalogQuery _query;
  CatalogQuery get query => _query;

  List<CatalogContent> _items = const [];
  List<CatalogContent> get items => _items;

  CatalogQueryCoverage _coverage = const CatalogQueryCoverage();
  CatalogQueryCoverage get coverage => _coverage;

  String? _nextCursor;
  bool get hasMore => _nextCursor != null;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _isLoadingMore = false;
  bool get isLoadingMore => _isLoadingMore;

  bool _isRefreshing = false;
  bool get isRefreshing => _isRefreshing;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  String? _updateWarning;
  String? get updateWarning => _updateWarning;

  Object? _lastError;
  Object? get lastError => _lastError;

  bool _initialized = false;
  int _generation = 0;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    await _reload(clearItems: true);
  }

  Future<void> refresh() => _reload(forceRefresh: true, clearItems: false);

  Future<void> loadMore() async {
    final cursor = _nextCursor;
    if (cursor == null || _isLoadingMore || _isLoading) return;
    final generation = _generation;
    _isLoadingMore = true;
    _updateWarning = null;
    notifyListeners();
    try {
      final page = await _repository.query(_copy(cursor: cursor));
      if (generation != _generation) return;
      final byId = <String, CatalogContent>{
        for (final item in _items) item.contentId: item,
      };
      for (final item in page.items) {
        byId[item.contentId] = item;
      }
      _items = List.unmodifiable(byId.values);
      _nextCursor = page.nextCursor;
      _coverage = page.coverage;
      _updateWarning = page.warning;
      _lastError = null;
    } catch (error) {
      if (generation != _generation) return;
      _lastError = error;
      _updateWarning = '继续扩展索引失败，已保留当前结果。';
    } finally {
      if (generation == _generation) {
        _isLoadingMore = false;
        notifyListeners();
      }
    }
  }

  Future<void> setMode(CatalogMode mode) {
    if (mode == _query.mode || mode == CatalogMode.unknown) {
      return Future<void>.value();
    }
    return _applyQuery(
      _copy(
        mode: mode,
        providerId: mode == CatalogMode.discovery ? null : _query.providerId,
        updatedWithin:
            mode == CatalogMode.discovery ? null : _query.updatedWithin,
      ),
    );
  }

  Future<void> toggleGenre(String genre) {
    final genres = Set<String>.from(_query.genres);
    if (!genres.add(genre)) genres.remove(genre);
    return _applyQuery(_copy(genres: genres));
  }

  Future<void> setGenres(Set<String> genres) =>
      _applyQuery(_copy(genres: Set.unmodifiable(genres)));

  Future<void> setYear(int? value) => _applyQuery(_copy(year: value));

  Future<void> setSeason(CatalogSeason? value) =>
      _applyQuery(_copy(season: value));

  Future<void> setFormat(CatalogFormat? value) =>
      _applyQuery(_copy(format: value));

  Future<void> setStatus(CatalogStatus? value) =>
      _applyQuery(_copy(status: value));

  Future<void> setRegion(CatalogRegion? value) =>
      _applyQuery(_copy(region: value));

  Future<void> setMinimumScore(double? value) =>
      _applyQuery(_copy(minimumScore: value));

  Future<void> setSort(CatalogSort value) => _applyQuery(_copy(sort: value));

  Future<void> setProvider(String? value) =>
      _applyQuery(_copy(providerId: value));

  Future<void> setUpdatedWithin(Duration? value) =>
      _applyQuery(_copy(updatedWithin: value));

  Future<void> setIncludeAdult(bool value) {
    if (_query.includeAdult == value) return Future<void>.value();
    return _applyQuery(_copy(includeAdult: value));
  }

  Future<void> clearAllFilters() {
    return _applyQuery(
      CatalogQuery(mode: _query.mode, includeAdult: _query.includeAdult),
    );
  }

  Future<void> _applyQuery(CatalogQuery next) {
    if (next == _query) return Future<void>.value();
    _query = next;
    return _reload(clearItems: true);
  }

  Future<void> _reload({
    bool forceRefresh = false,
    required bool clearItems,
  }) async {
    final generation = ++_generation;
    if (clearItems) {
      _items = const [];
      _nextCursor = null;
      _coverage = const CatalogQueryCoverage();
    }
    _errorMessage = null;
    _updateWarning = null;
    _lastError = null;
    _isLoading = _items.isEmpty;
    _isRefreshing = !_isLoading;
    _isLoadingMore = false;
    notifyListeners();
    try {
      final page = await _repository.query(
        _query,
        forceRefresh: forceRefresh,
      );
      if (generation != _generation) return;
      _items = List.unmodifiable(page.items);
      _nextCursor = page.nextCursor;
      _coverage = page.coverage;
      _updateWarning = page.warning;
    } catch (error) {
      if (generation != _generation) return;
      _lastError = error;
      if (_items.isEmpty) {
        _errorMessage = _messageFor(error);
      } else {
        _updateWarning = '目录更新失败，正在显示旧缓存结果。';
      }
    } finally {
      if (generation == _generation) {
        _isLoading = false;
        _isRefreshing = false;
        notifyListeners();
      }
    }
  }

  String _messageFor(Object error) {
    if (error is CatalogProvidersDisabledException) {
      return '没有启用可用于此目录的插件，请前往插件设置开启片源。';
    }
    if (error is CatalogProviderUnavailableException) {
      return '所选片源当前不可用，请更换片源或检查插件设置。';
    }
    return '加载失败，请检查网络后再试。';
  }

  CatalogQuery _copy({
    CatalogMode? mode,
    Set<String>? genres,
    Object? year = _unset,
    Object? season = _unset,
    Object? format = _unset,
    Object? status = _unset,
    Object? region = _unset,
    Object? minimumScore = _unset,
    CatalogSort? sort,
    Object? providerId = _unset,
    Object? updatedWithin = _unset,
    Object? cursor = _unset,
    bool? includeAdult,
  }) {
    return CatalogQuery(
      mode: mode ?? _query.mode,
      text: _query.text,
      genres: genres ?? _query.genres,
      year: identical(year, _unset) ? _query.year : year as int?,
      season:
          identical(season, _unset) ? _query.season : season as CatalogSeason?,
      format:
          identical(format, _unset) ? _query.format : format as CatalogFormat?,
      status:
          identical(status, _unset) ? _query.status : status as CatalogStatus?,
      region:
          identical(region, _unset) ? _query.region : region as CatalogRegion?,
      minimumScore: identical(minimumScore, _unset)
          ? _query.minimumScore
          : minimumScore as double?,
      sort: sort ?? _query.sort,
      providerId: identical(providerId, _unset)
          ? _query.providerId
          : providerId as String?,
      updatedWithin: identical(updatedWithin, _unset)
          ? _query.updatedWithin
          : updatedWithin as Duration?,
      cursor: identical(cursor, _unset) ? null : cursor as String?,
      limit: _query.limit,
      includeAdult: includeAdult ?? _query.includeAdult,
    );
  }
}

const _unset = Object();
