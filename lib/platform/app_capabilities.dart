import 'package:flutter/widgets.dart';

class AppCapabilities {
  const AppCapabilities({
    required this.downloads,
    required this.pluginEditing,
    required this.secureCredentialStorage,
  });

  static const windows = AppCapabilities(
    downloads: true,
    pluginEditing: true,
    secureCredentialStorage: true,
  );

  static const androidCompileBaseline = AppCapabilities(
    downloads: false,
    pluginEditing: false,
    secureCredentialStorage: false,
  );

  final bool downloads;
  final bool pluginEditing;
  final bool secureCredentialStorage;
}

class AppCapabilitiesScope extends InheritedWidget {
  const AppCapabilitiesScope({
    super.key,
    required this.capabilities,
    required super.child,
  });

  final AppCapabilities capabilities;

  static AppCapabilities of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<AppCapabilitiesScope>()
          ?.capabilities ??
      AppCapabilities.windows;

  @override
  bool updateShouldNotify(AppCapabilitiesScope oldWidget) =>
      capabilities != oldWidget.capabilities;
}
