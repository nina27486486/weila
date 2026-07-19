import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weila/pages/settings/widgets/settings_components.dart';
import 'package:weila/services/download/download_settings.dart';
import 'package:weila/theme/app_theme.dart';

void main() {
  testWidgets('download network panel edits proxy and retry settings',
      (tester) async {
    var saved = DownloadSettings.defaults;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: DownloadNetworkSettingsPanel(
            settings: DownloadSettings.defaults,
            onSave: (value) => saved = value,
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('download-proxy-custom')));
    await tester.enterText(
      find.byKey(const ValueKey('download-custom-proxy-field')),
      '127.0.0.1:7890',
    );
    await tester.enterText(
      find.byKey(const ValueKey('download-segment-concurrency-field')),
      '6',
    );
    await tester.enterText(
      find.byKey(const ValueKey('download-segment-retries-field')),
      '4',
    );
    await tester.tap(find.byKey(const ValueKey('download-network-save')));

    expect(saved.proxyMode, DownloadProxyMode.custom);
    expect(saved.customProxy, '127.0.0.1:7890');
    expect(saved.segmentConcurrency, 6);
    expect(saved.segmentRetries, 4);
  });
}
