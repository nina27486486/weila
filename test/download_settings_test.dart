import 'package:flutter_test/flutter_test.dart';
import 'package:weila/services/download/download_settings.dart';

void main() {
  test('download settings use safe defaults', () {
    const settings = DownloadSettings.defaults;

    expect(settings.proxyMode, DownloadProxyMode.direct);
    expect(settings.customProxy, isEmpty);
    expect(settings.segmentConcurrency, 4);
    expect(settings.segmentRetries, 3);
  });

  test('download settings clamp unsafe values', () {
    const settings = DownloadSettings(
      segmentConcurrency: 99,
      segmentRetries: -4,
    );

    final normalized = settings.normalized();

    expect(normalized.segmentConcurrency, 8);
    expect(normalized.segmentRetries, 0);
  });

  test('custom proxy accepts host port or http uri', () {
    const hostPort = DownloadSettings(
      proxyMode: DownloadProxyMode.custom,
      customProxy: '127.0.0.1:7890',
    );
    const httpUri = DownloadSettings(
      proxyMode: DownloadProxyMode.custom,
      customProxy: 'http://localhost:8080',
    );

    expect(
      hostPort.proxyRuleFor(Uri.parse('https://example.com/video.m3u8')),
      'PROXY 127.0.0.1:7890',
    );
    expect(
      httpUri.proxyRuleFor(Uri.parse('https://example.com/video.m3u8')),
      'PROXY localhost:8080',
    );
  });

  test('invalid custom proxy falls back to direct connection', () {
    const settings = DownloadSettings(
      proxyMode: DownloadProxyMode.custom,
      customProxy: 'not a proxy',
    );

    expect(settings.proxyRuleFor(Uri.parse('https://example.com')), 'DIRECT');
  });
}
