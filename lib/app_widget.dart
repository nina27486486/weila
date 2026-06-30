import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'theme/app_theme.dart';
import 'stores/theme_store.dart';

class AppWidget extends StatelessWidget {
  const AppWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Observer(
      builder: (_) {
        final themeStore = Modular.get<ThemeStore>();
        return MaterialApp.router(
          title: '薇拉',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeStore.isDarkMode ? ThemeMode.dark : ThemeMode.light,
          routerConfig: Modular.routerConfig,
        );
      },
    );
  }
}
