import '../../../models/catalog/catalog_enums.dart';
import '../../../models/catalog/catalog_values.dart';
import 'catalog_provider.dart';

class CatalogProviderGateway {
  CatalogProviderGateway({
    required CatalogProvider anilist,
    required CatalogProvider jikan,
    List<CatalogProvider> playableProviders = const [],
  })  : _anilist = anilist,
        _jikan = jikan,
        _playableProviders = List.unmodifiable(playableProviders);

  static const _aggregateCursorId = 'catalog:playable';

  final CatalogProvider _anilist;
  final CatalogProvider _jikan;
  final List<CatalogProvider> _playableProviders;

  List<CatalogProvider> available(CatalogMode mode) {
    final providers =
        mode == CatalogMode.discovery ? [_anilist, _jikan] : _playableProviders;
    return providers
        .where((provider) => provider.capabilities.modes.contains(mode))
        .toList(growable: false);
  }

  Future<ProviderCatalogPage> query(CatalogQuery query) {
    return switch (query.mode) {
      CatalogMode.discovery => _queryDiscovery(query),
      CatalogMode.playable => _queryPlayable(query),
      CatalogMode.unknown => throw CatalogProviderUnavailableException(
          providerId: 'catalog',
          message: 'Unknown catalog mode.',
        ),
    };
  }

  Future<CatalogPage> load(CatalogQuery query) async {
    final page = await this.query(query);
    return page.toCatalogPage(query.mode);
  }

  Future<ProviderCatalogPage> _queryDiscovery(CatalogQuery query) async {
    final requested = query.providerId;
    if (requested != null) {
      final provider = available(CatalogMode.discovery)
          .where((candidate) => candidate.providerId == requested)
          .firstOrNull;
      if (provider == null) {
        throw CatalogProviderUnavailableException(
          providerId: requested,
          message: 'Requested discovery provider is unavailable.',
        );
      }
      return provider.query(query);
    }
    try {
      return await _anilist.query(query);
    } catch (primaryError) {
      try {
        return await _jikan.query(query);
      } catch (_) {
        Error.throwWithStackTrace(primaryError, StackTrace.current);
      }
    }
  }

  Future<ProviderCatalogPage> _queryPlayable(CatalogQuery query) async {
    final providers = available(CatalogMode.playable);
    final requested = query.providerId;
    if (requested != null) {
      final provider = providers
          .where((candidate) => candidate.providerId == requested)
          .firstOrNull;
      if (provider == null) {
        throw CatalogProviderUnavailableException(
          providerId: requested,
          message: 'Requested playable provider is unavailable.',
        );
      }
      return provider.query(query);
    }
    if (providers.isEmpty) {
      throw CatalogProvidersDisabledException(CatalogMode.playable);
    }
    if (providers.length == 1) {
      return providers.single.query(
        _forProvider(query, providers.single.providerId, query.cursor),
      );
    }
    return _queryPlayableAggregate(query, providers);
  }

  Future<ProviderCatalogPage> _queryPlayableAggregate(
    CatalogQuery query,
    List<CatalogProvider> providers,
  ) async {
    final state = ProviderCursor.decode(
      query.cursor,
      providerId: _aggregateCursorId,
    );
    final cursors = _stringMap(state['cursors']);
    final completed = _stringSet(state['completed']);
    final items = <CatalogContent>[];
    final local = <String>{};
    Set<String>? remote;
    final warnings = <String>[];
    final errors = <Object>[];
    var scanned = 0;
    var successfulProviders = 0;

    for (final provider in providers) {
      if (completed.contains(provider.providerId)) continue;
      try {
        final page = await provider.query(
          _forProvider(
            query,
            provider.providerId,
            cursors[provider.providerId]?.toString(),
          ),
        );
        successfulProviders++;
        items.addAll(page.items);
        local.addAll(page.locallyEvaluated);
        remote = remote == null
            ? Set<String>.from(page.remotelyEvaluated)
            : remote.intersection(page.remotelyEvaluated);
        warnings.addAll(page.warnings);
        scanned += page.scannedUpstreamPages;
        if (page.complete || page.nextCursor == null) {
          completed.add(provider.providerId);
          cursors.remove(provider.providerId);
        } else {
          cursors[provider.providerId] = page.nextCursor;
        }
      } catch (error) {
        errors.add(error);
        warnings.add('${provider.providerId}: $error');
      }
    }
    if (successfulProviders == 0 && errors.isNotEmpty) throw errors.first;
    final complete = completed.containsAll(
      providers.map((provider) => provider.providerId),
    );
    return ProviderCatalogPage(
      items: items,
      nextCursor: complete
          ? null
          : ProviderCursor.encode(
              _aggregateCursorId,
              {
                'cursors': cursors,
                'completed': completed.toList()..sort(),
              },
            ),
      remotelyEvaluated: remote ?? const {},
      locallyEvaluated: local,
      complete: complete,
      scannedUpstreamPages: scanned,
      warnings: warnings,
    );
  }
}

CatalogQuery _forProvider(
  CatalogQuery query,
  String providerId,
  String? cursor,
) {
  return CatalogQuery(
    mode: query.mode,
    text: query.text,
    genres: query.genres,
    year: query.year,
    season: query.season,
    format: query.format,
    status: query.status,
    region: query.region,
    minimumScore: query.minimumScore,
    sort: query.sort,
    providerId: providerId,
    updatedWithin: query.updatedWithin,
    cursor: cursor,
    limit: query.limit,
    includeAdult: query.includeAdult,
  );
}

Map<String, Object?> _stringMap(Object? value) => value is Map
    ? value.map((key, item) => MapEntry(key.toString(), item))
    : <String, Object?>{};

Set<String> _stringSet(Object? value) => value is Iterable
    ? value.map((item) => item.toString()).toSet()
    : <String>{};
