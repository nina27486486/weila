import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';
import '../../../theme/vira_colors.dart';
import '../../../utils/animations.dart';

class DataSourcePageHeader extends StatelessWidget {
  const DataSourcePageHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onBack,
    this.actions = const [],
  });

  final String title;
  final String subtitle;
  final VoidCallback onBack;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 94,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: context.colors.paper,
        border: Border(bottom: BorderSide(color: context.colors.divider)),
      ),
      child: Row(
        children: [
          _HeaderBackButton(onTap: onBack),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 2),
                Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          ...actions,
        ],
      ),
    );
  }
}

class DataSourceSection extends StatelessWidget {
  const DataSourceSection({
    super.key,
    required this.title,
    required this.description,
    required this.child,
    this.icon = Icons.tune_rounded,
  });

  final String title;
  final String description;
  final Widget child;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
      decoration: BoxDecoration(
        color: context.colors.paper,
        border: Border(
          top: BorderSide(color: context.colors.divider),
          bottom: BorderSide(color: context.colors.divider),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withValues(alpha: 0.12),
                ),
                child: Icon(icon, color: AppTheme.primaryBlue, size: 19),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 3),
                    Text(description,
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}

class DataSourceMetric extends StatelessWidget {
  const DataSourceMetric({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.color = AppTheme.primaryBlue,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 132),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: context.colors.bgSurface,
        border: Border.all(color: context.colors.divider),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.labelSmall),
              const SizedBox(height: 2),
              Text(value, style: Theme.of(context).textTheme.labelLarge),
            ],
          ),
        ],
      ),
    );
  }
}

class DataSourceStatusBadge extends StatelessWidget {
  const DataSourceStatusBadge({
    super.key,
    required this.enabled,
    this.enabledLabel = '已启用',
    this.disabledLabel = '已停用',
  });

  final bool enabled;
  final String enabledLabel;
  final String disabledLabel;

  @override
  Widget build(BuildContext context) {
    final color = enabled ? AppTheme.scoreGreen : context.colors.textMuted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.11),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            enabled ? enabledLabel : disabledLabel,
            style:
                Theme.of(context).textTheme.labelSmall?.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

class DataSourceTypeBadge extends StatelessWidget {
  const DataSourceTypeBadge({super.key, required this.api});

  final String api;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.primaryBlue.withValues(alpha: 0.10),
      ),
      child: Text(
        dataSourceTypeLabel(api),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppTheme.primaryBlue,
            ),
      ),
    );
  }
}

class DataSourceEmptyState extends StatelessWidget {
  const DataSourceEmptyState({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  color: context.colors.bgCard,
                  border: Border.all(color: context.colors.divider),
                ),
                child: Icon(icon, color: AppTheme.primaryBlue, size: 28),
              ),
              const SizedBox(height: 17),
              Text(title, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 7),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: onAction,
                  icon: const Icon(Icons.add_rounded, size: 17),
                  label: Text(actionLabel!),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

IconData dataSourceTypeIcon(String api) {
  final normalized = api.toLowerCase();
  if (normalized.startsWith('cms_')) return Icons.playlist_play_rounded;
  if (normalized == 'jikan' ||
      normalized == 'bangumi' ||
      normalized == 'anilist') {
    return Icons.auto_stories_outlined;
  }
  return Icons.extension_rounded;
}

String dataSourceTypeLabel(String api) {
  final normalized = api.toLowerCase();
  if (normalized.startsWith('cms_')) return '播放源';
  if (normalized == 'jikan' ||
      normalized == 'bangumi' ||
      normalized == 'anilist') {
    return '元数据';
  }
  return '自定义';
}

class _HeaderBackButton extends StatefulWidget {
  const _HeaderBackButton({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_HeaderBackButton> createState() => _HeaderBackButtonState();
}

class _HeaderBackButtonState extends State<_HeaderBackButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '返回',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovering = true),
        onExit: (_) => setState(() => _hovering = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: AppAnimations.fast,
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: _hovering ? context.colors.bgHover : context.colors.bgCard,
              border: Border.all(color: context.colors.divider),
            ),
            child: Icon(
              Icons.arrow_back_rounded,
              color: _hovering
                  ? context.colors.textPrimary
                  : context.colors.textSecondary,
              size: 20,
            ),
          ),
        ),
      ),
    );
  }
}
