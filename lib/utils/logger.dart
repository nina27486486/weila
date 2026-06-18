import 'package:flutter/foundation.dart';

/// 统一日志工具 - Release 模式自动静默
class Log {
  static void d(String tag, String message) {
    if (kDebugMode) {
      print('[$tag] $message');
    }
  }

  static void e(String tag, String message, [Object? error]) {
    if (kDebugMode) {
      print('[$tag] $message');
      if (error != null) print('[$tag] Error: $error');
    }
  }
}
