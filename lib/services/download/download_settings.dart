import 'dart:io';

enum DownloadProxyMode { direct, system, custom }

abstract class DownloadSettingsRepository {
  DownloadSettings getDownloadSettings();
  Future<void> setDownloadSettings(DownloadSettings settings);
}

class DownloadSettings {
  static const proxyModeKey = 'download_proxy_mode';
  static const customProxyKey = 'download_custom_proxy';
  static const segmentConcurrencyKey = 'download_segment_concurrency';
  static const segmentRetriesKey = 'download_segment_retries';

  static const defaults = DownloadSettings();

  final DownloadProxyMode proxyMode;
  final String customProxy;
  final int segmentConcurrency;
  final int segmentRetries;

  const DownloadSettings({
    this.proxyMode = DownloadProxyMode.direct,
    this.customProxy = '',
    this.segmentConcurrency = 4,
    this.segmentRetries = 3,
  });

  DownloadSettings copyWith({
    DownloadProxyMode? proxyMode,
    String? customProxy,
    int? segmentConcurrency,
    int? segmentRetries,
  }) {
    return DownloadSettings(
      proxyMode: proxyMode ?? this.proxyMode,
      customProxy: customProxy ?? this.customProxy,
      segmentConcurrency: segmentConcurrency ?? this.segmentConcurrency,
      segmentRetries: segmentRetries ?? this.segmentRetries,
    );
  }

  DownloadSettings normalized() {
    return copyWith(
      customProxy: customProxy.trim(),
      segmentConcurrency: segmentConcurrency.clamp(1, 8).toInt(),
      segmentRetries: segmentRetries.clamp(0, 5).toInt(),
    );
  }

  Map<String, Object?> toMap() {
    final value = normalized();
    return {
      proxyModeKey: value.proxyMode.name,
      customProxyKey: value.customProxy,
      segmentConcurrencyKey: value.segmentConcurrency,
      segmentRetriesKey: value.segmentRetries,
    };
  }

  factory DownloadSettings.fromMap(Map<String, Object?> values) {
    final rawMode = values[proxyModeKey]?.toString();
    DownloadProxyMode? mode;
    for (final entry in DownloadProxyMode.values) {
      if (entry.name == rawMode) {
        mode = entry;
        break;
      }
    }
    return DownloadSettings(
      proxyMode: mode ?? DownloadProxyMode.direct,
      customProxy: values[customProxyKey]?.toString() ?? '',
      segmentConcurrency: _asInt(values[segmentConcurrencyKey], 4),
      segmentRetries: _asInt(values[segmentRetriesKey], 3),
    ).normalized();
  }

  String proxyRuleFor(Uri uri) {
    return switch (proxyMode) {
      DownloadProxyMode.direct => 'DIRECT',
      DownloadProxyMode.system => HttpClient.findProxyFromEnvironment(uri),
      DownloadProxyMode.custom => _customProxyRule() ?? 'DIRECT',
    };
  }

  String proxySummary() {
    return switch (proxyMode) {
      DownloadProxyMode.direct => '直连',
      DownloadProxyMode.system => '系统代理',
      DownloadProxyMode.custom =>
        customProxy.trim().isEmpty ? '自定义代理未填写' : customProxy.trim(),
    };
  }

  String? _customProxyRule() {
    final endpoint = _normalizedCustomProxyEndpoint();
    if (endpoint == null) return null;
    return 'PROXY $endpoint';
  }

  String? _normalizedCustomProxyEndpoint() {
    final trimmed = customProxy.trim();
    if (trimmed.isEmpty || trimmed.contains(RegExp(r'\s'))) return null;
    try {
      final uri = Uri.parse(
        trimmed.contains('://') ? trimmed : 'http://$trimmed',
      );
      if (uri.host.isEmpty) return null;
      final port = uri.hasPort ? uri.port : 80;
      if (port <= 0) return null;
      return '${uri.host}:$port';
    } catch (_) {
      return null;
    }
  }

  static int _asInt(Object? value, int fallback) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }
}
