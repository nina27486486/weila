import 'dart:convert';

import '../../../models/catalog/catalog_enums.dart';
import '../../../models/catalog/catalog_values.dart';

typedef CatalogGetJson = Future<Object?> Function(
  Uri uri,
  Map<String, String> headers,
);

typedef CatalogPostJson = Future<Object?> Function(
  Uri uri,
  Map<String, Object?> body,
  Map<String, String> headers,
);

abstract interface class CatalogProvider {
  String get providerId;

  CatalogProviderCapabilities get capabilities;

  Future<ProviderCatalogPage> query(CatalogQuery query);
}

class CatalogProviderCapabilities {
  const CatalogProviderCapabilities({
    required this.modes,
    this.remoteDimensions = const {},
    this.localDimensions = const {},
    this.remoteSorts = const {},
  });

  final Set<CatalogMode> modes;
  final Set<String> remoteDimensions;
  final Set<String> localDimensions;
  final Set<CatalogSort> remoteSorts;
}

class ProviderCatalogPage {
  const ProviderCatalogPage({
    this.items = const [],
    this.nextCursor,
    this.remotelyEvaluated = const {},
    this.locallyEvaluated = const {},
    this.complete = false,
    this.scannedUpstreamPages = 0,
    this.upstreamPageCount,
    this.warnings = const [],
  });

  final List<CatalogContent> items;
  final String? nextCursor;
  final Set<String> remotelyEvaluated;
  final Set<String> locallyEvaluated;
  final bool complete;
  final int scannedUpstreamPages;
  final int? upstreamPageCount;
  final List<String> warnings;

  CatalogPage toCatalogPage(CatalogMode mode) => CatalogPage(
        items: items,
        nextCursor: nextCursor,
        coverage: CatalogQueryCoverage(
          modes: {mode},
          dimensions: {...remotelyEvaluated, ...locallyEvaluated},
          complete: complete,
        ),
        warning: warnings.isEmpty ? null : '部分片源更新失败，已展示其余可用结果。',
      );
}

class CatalogProviderException implements Exception {
  const CatalogProviderException({
    required this.providerId,
    required this.stage,
    required this.message,
    this.cause,
  });

  final String providerId;
  final String stage;
  final String message;
  final Object? cause;

  @override
  String toString() => 'CatalogProviderException($providerId/$stage: $message)';
}

class CatalogProviderUnavailableException extends CatalogProviderException {
  const CatalogProviderUnavailableException({
    required super.providerId,
    required super.message,
  }) : super(stage: 'availability');
}

class CatalogProvidersDisabledException extends CatalogProviderException {
  CatalogProvidersDisabledException(CatalogMode mode)
      : super(
          providerId: 'catalog',
          stage: 'disabled',
          message: 'No enabled provider supports ${mode.name}.',
        );
}

abstract final class CatalogProviderDimensions {
  static const mode = 'mode';
  static const text = 'text';
  static const genres = 'genres';
  static const year = 'year';
  static const season = 'season';
  static const format = 'format';
  static const status = 'status';
  static const region = 'region';
  static const minimumScore = 'minimumScore';
  static const sort = 'sort';
  static const providerId = 'providerId';
  static const updatedWithin = 'updatedWithin';
  static const adult = 'adult';
  static const cursor = 'cursor';
  static const limit = 'limit';
  static const playable = 'playable';
}

abstract final class ProviderCursor {
  static String encode(String providerId, Map<String, Object?> state) {
    final bytes = utf8.encode(jsonEncode({
      'v': 1,
      'providerId': providerId,
      'state': state,
    }));
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  static Map<String, Object?> decode(
    String? cursor, {
    required String providerId,
  }) {
    if (cursor == null || cursor.isEmpty) return const {};
    try {
      final padded = cursor.padRight((cursor.length + 3) ~/ 4 * 4, '=');
      final decoded = jsonDecode(utf8.decode(base64Url.decode(padded)));
      if (decoded is! Map ||
          decoded['v'] != 1 ||
          decoded['providerId'] != providerId ||
          decoded['state'] is! Map) {
        throw const FormatException('Cursor scope mismatch.');
      }
      return (decoded['state'] as Map).map(
        (key, value) => MapEntry(key.toString(), value),
      );
    } catch (error) {
      throw CatalogProviderException(
        providerId: providerId,
        stage: 'cursor',
        message: 'Invalid provider cursor.',
        cause: error,
      );
    }
  }
}
