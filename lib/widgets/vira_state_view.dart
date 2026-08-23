import 'package:flutter/material.dart';

import '../theme/vira_colors.dart';

enum ViraStateKind { empty, error, loading }

class ViraStateView extends StatelessWidget {
  final ViraStateKind kind;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// 覆盖默认的 kind 图标（如搜索空态的放大镜）。
  final IconData? icon;

  /// 标题上方的小标签（如"搜索"），不传则不渲染。
  final String? eyebrow;

  /// 操作按钮图标，不传则只有文字按钮。
  final IconData? actionIcon;

  const ViraStateView({
    super.key,
    required this.kind,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.icon,
    this.eyebrow,
    this.actionIcon,
  });

  const ViraStateView.error({
    super.key,
    required this.title,
    required this.message,
    required VoidCallback onRetry,
    this.icon,
    this.eyebrow,
  })  : kind = ViraStateKind.error,
        actionLabel = '重新加载',
        onAction = onRetry,
        actionIcon = Icons.refresh_rounded;

  const ViraStateView.empty({
    super.key,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.icon,
    this.eyebrow,
    this.actionIcon,
  }) : kind = ViraStateKind.empty;

  const ViraStateView.loading({
    super.key,
    this.title = '正在整理画面',
    this.message = '请稍候，故事很快抵达。',
  })  : kind = ViraStateKind.loading,
        actionLabel = null,
        onAction = null,
        icon = null,
        eyebrow = null,
        actionIcon = null;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final effectiveIcon =
        icon ??
        switch (kind) {
          ViraStateKind.empty => Icons.bookmark_border_rounded,
          ViraStateKind.error => Icons.cloud_off_outlined,
          ViraStateKind.loading => Icons.auto_awesome_outlined,
        };

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 58,
                height: 58,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: kind == ViraStateKind.error
                      ? colors.sakuraLight
                      : colors.skyLight,
                  shape: BoxShape.circle,
                ),
                child: kind == ViraStateKind.loading
                    ? SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: colors.sky,
                        ),
                      )
                    : Icon(
                        effectiveIcon,
                        color: kind == ViraStateKind.error
                            ? colors.danger
                            : colors.sky,
                        size: 25,
                      ),
              ),
              if (eyebrow case final label?) ...[
                const SizedBox(height: 14),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: colors.sky,
                      ),
                ),
              ],
              const SizedBox(height: 18),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 7),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: 20),
                if (actionIcon case final icon?)
                  OutlinedButton.icon(
                    onPressed: onAction,
                    icon: Icon(icon, size: 17),
                    label: Text(actionLabel!),
                  )
                else
                  OutlinedButton(
                    onPressed: onAction,
                    child: Text(actionLabel!),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
