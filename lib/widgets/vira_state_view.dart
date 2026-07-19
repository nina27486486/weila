import 'package:flutter/material.dart';

import '../theme/vira_colors.dart';

enum ViraStateKind { empty, error, loading }

class ViraStateView extends StatelessWidget {
  final ViraStateKind kind;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const ViraStateView({
    super.key,
    required this.kind,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  const ViraStateView.error({
    super.key,
    required this.title,
    required this.message,
    required VoidCallback onRetry,
  })  : kind = ViraStateKind.error,
        actionLabel = '重新加载',
        onAction = onRetry;

  const ViraStateView.empty({
    super.key,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  }) : kind = ViraStateKind.empty;

  const ViraStateView.loading({
    super.key,
    this.title = '正在整理画面',
    this.message = '请稍候，故事很快抵达。',
  })  : kind = ViraStateKind.loading,
        actionLabel = null,
        onAction = null;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final icon = switch (kind) {
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
                        icon,
                        color: kind == ViraStateKind.error
                            ? colors.danger
                            : colors.sky,
                        size: 25,
                      ),
              ),
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
              if (actionLabel case final label?) ...[
                const SizedBox(height: 20),
                OutlinedButton(
                  onPressed: onAction,
                  child: Text(label),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
