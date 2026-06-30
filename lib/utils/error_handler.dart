import '../theme/vira_colors.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// 统一错误处理工具类
/// 所有页面的错误提示都通过此类，保持一致的用户体验
class ErrorHandler {
  /// 显示错误 SnackBar（带可选重试按钮）
  static void showError(
    BuildContext context,
    String message, {
    VoidCallback? onRetry,
    Duration duration = const Duration(seconds: 4),
  }) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.white, size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Text(message, style: TextStyle(fontSize: 13)),
          ),
        ],
      ),
      action: onRetry != null
          ? SnackBarAction(
              label: '重试',
              textColor: Colors.white,
              onPressed: onRetry,
            )
          : null,
      backgroundColor: Colors.red.shade700,
      behavior: SnackBarBehavior.floating,
      duration: duration,
      margin: const EdgeInsets.all(12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ));
  }

  /// 显示成功提示
  static void showSuccess(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 2),
  }) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(
        children: [
          Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Text(message, style: TextStyle(fontSize: 13)),
          ),
        ],
      ),
      backgroundColor: Colors.green.shade700,
      behavior: SnackBarBehavior.floating,
      duration: duration,
      margin: const EdgeInsets.all(12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ));
  }

  /// 显示信息提示
  static void showInfo(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 2),
  }) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(
        children: [
          Icon(Icons.info_outline, color: Colors.white, size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Text(message, style: TextStyle(fontSize: 13)),
          ),
        ],
      ),
      backgroundColor: AppTheme.primaryBlue,
      behavior: SnackBarBehavior.floating,
      duration: duration,
      margin: const EdgeInsets.all(12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ));
  }

  /// 显示确认对话框
  static Future<bool> showConfirm(
    BuildContext context, {
    required String title,
    required String message,
    String confirmText = '确认',
    String cancelText = '取消',
    Color? confirmColor,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.colors.bgCard,
        title: Text(title,
            style: TextStyle(color: context.colors.textPrimary, fontSize: 16)),
        content: Text(message,
            style:
                TextStyle(color: context.colors.textSecondary, fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(cancelText,
                style: TextStyle(color: context.colors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: confirmColor ?? AppTheme.primaryBlue,
            ),
            child: Text(confirmText),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  /// 包装异步操作，自动处理错误
  /// 返回 null 表示失败，成功返回 T
  static Future<T?> wrap<T>(
    BuildContext context,
    Future<T> Function() operation, {
    String? errorMessage,
    VoidCallback? onRetry,
    bool showError = true,
  }) async {
    try {
      return await operation();
    } catch (e) {
      if (showError && context.mounted) {
        showErrorSnackBar(context, errorMessage ?? '操作失败: $e',
            onRetry: onRetry);
      }
      return null;
    }
  }

  static void showErrorSnackBar(BuildContext context, String message,
      {VoidCallback? onRetry}) {
    showError(context, message, onRetry: onRetry);
  }
}
