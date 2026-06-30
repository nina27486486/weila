// ignore_for_file: library_private_types_in_public_api

import 'package:mobx/mobx.dart';
import '../services/storage/storage_service.dart';

part 'theme_store.g.dart';

class ThemeStore extends _ThemeStore with _$ThemeStore {
  ThemeStore._();

  static final ThemeStore _instance = ThemeStore._();

  factory ThemeStore() => _instance;
}

abstract class _ThemeStore with Store {
  final _storage = StorageService();

  @observable
  bool isDarkMode = false;

  @action
  void toggleTheme() {
    isDarkMode = !isDarkMode;
    _storage.setSetting('isDarkMode', isDarkMode);
  }

  @action
  void loadTheme() {
    isDarkMode =
        _storage.getSetting<bool>('isDarkMode', defaultValue: false) ?? false;
  }
}
