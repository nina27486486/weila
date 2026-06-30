import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';
import '../../../theme/vira_colors.dart';
import '../../../utils/animations.dart';

class SettingsNavDestination {
  const SettingsNavDestination({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

enum SettingsStatusTone { neutral, success, warning }

class SettingsChapterIndex extends StatelessWidget {
  const SettingsChapterIndex({
    super.key,
    required this.destinations,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<SettingsNavDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.colors.paper,
        border: Border(
          top: BorderSide(color: context.colors.divider),
          bottom: BorderSide(color: context.colors.divider),
        ),
      ),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              '设置目录',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: context.colors.textMuted,
                    letterSpacing: 1.2,
                  ),
            ),
          ),
          Container(width: 1, height: 30, color: context.colors.divider),
          for (var index = 0; index < destinations.length; index++)
            Expanded(
              child: _SettingsChapterItem(
                key: ValueKey('settings-chapter-$index'),
                index: index,
                destination: destinations[index],
                selected: index == selectedIndex,
                onTap: () => onSelected(index),
              ),
            ),
        ],
      ),
    );
  }
}

class _SettingsChapterItem extends StatefulWidget {
  const _SettingsChapterItem({
    super.key,
    required this.index,
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final int index;
  final SettingsNavDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_SettingsChapterItem> createState() => _SettingsChapterItemState();
}

class _SettingsChapterItemState extends State<_SettingsChapterItem> {
  var _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Semantics(
      button: true,
      selected: widget.selected,
      label: widget.destination.label,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: AppAnimations.fast,
            height: 58,
            decoration: BoxDecoration(
              color: widget.selected
                  ? colors.skyLight
                  : _hovered
                      ? colors.bgHover
                      : Colors.transparent,
              border: Border(
                bottom: BorderSide(
                  color: widget.selected ? colors.sky : Colors.transparent,
                  width: 2,
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${widget.index + 1}'.padLeft(2, '0'),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: widget.selected || _hovered
                            ? colors.sky
                            : colors.textMuted,
                      ),
                ),
                const SizedBox(width: 7),
                Text(
                  widget.destination.label,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: widget.selected || _hovered
                            ? colors.textPrimary
                            : colors.textSecondary,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SettingsPageHeader extends StatelessWidget {
  const SettingsPageHeader({
    super.key,
    required this.onBack,
    required this.themeLabel,
  });

  final VoidCallback onBack;
  final String themeLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 78,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: context.colors.bgDark,
        border: Border(bottom: BorderSide(color: context.colors.divider)),
      ),
      child: Row(
        children: [
          _SquareIconButton(
            icon: Icons.arrow_back_rounded,
            tooltip: '返回首页',
            onTap: onBack,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('设置中心', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 2),
                Text(
                  '调整薇拉在这台设备上的播放体验',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: context.colors.bgCard,
              borderRadius: BorderRadius.circular(7),
              border: Border.all(color: context.colors.divider),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.desktop_windows_outlined,
                  size: 15,
                  color: AppTheme.primaryBlue,
                ),
                const SizedBox(width: 6),
                Text(
                  '本机 · $themeLabel',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SettingsNavigation extends StatelessWidget {
  const SettingsNavigation({
    super.key,
    required this.destinations,
    required this.selectedIndex,
    required this.version,
    required this.onSelected,
  });

  final List<SettingsNavDestination> destinations;
  final int selectedIndex;
  final String version;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: context.colors.bgSidebar,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '放映控制室',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text('选择一个分区', style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            const SizedBox(height: 20),
            for (var index = 0; index < destinations.length; index++)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: _NavigationItem(
                  destination: destinations[index],
                  index: index,
                  selected: selectedIndex == index,
                  onTap: () => onSelected(index),
                ),
              ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.colors.bgCard,
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: context.colors.divider),
              ),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryBlue.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(
                      Icons.movie_filter_rounded,
                      color: AppTheme.primaryBlue,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('薇拉',
                            style: Theme.of(context).textTheme.labelLarge),
                        Text('版本 $version',
                            style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CompactSettingsNavigation extends StatelessWidget {
  const CompactSettingsNavigation({
    super.key,
    required this.destinations,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<SettingsNavDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54,
      decoration: BoxDecoration(
        color: context.colors.bgSidebar,
        border: Border(bottom: BorderSide(color: context.colors.divider)),
      ),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        scrollDirection: Axis.horizontal,
        itemCount: destinations.length,
        separatorBuilder: (_, __) => const SizedBox(width: 7),
        itemBuilder: (context, index) => _CompactNavItem(
          destination: destinations[index],
          selected: selectedIndex == index,
          onTap: () => onSelected(index),
        ),
      ),
    );
  }
}

class SettingsHero extends StatelessWidget {
  const SettingsHero({
    super.key,
    required this.themeLabel,
    required this.enabledPluginCount,
    required this.pluginCount,
    required this.cacheLabel,
  });

  final String themeLabel;
  final int enabledPluginCount;
  final int pluginCount;
  final String cacheLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
      decoration: BoxDecoration(
        color: context.colors.paper,
        border: Border(
          top: BorderSide(color: context.colors.divider),
          bottom: BorderSide(color: context.colors.divider),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 700;
          final intro = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 3,
                    height: 14,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryBlue,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '设备配置概览',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: AppTheme.primaryBlue,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                '让每次放映都更合手',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 6),
              Text(
                '外观、数据源与本地缓存均保存在当前设备。',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          );
          final metrics = Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _HeroMetric(
                icon: Icons.contrast_rounded,
                label: '当前外观',
                value: themeLabel,
              ),
              _HeroMetric(
                icon: Icons.extension_rounded,
                label: '启用数据源',
                value: '$enabledPluginCount / $pluginCount',
              ),
              _HeroMetric(
                icon: Icons.storage_rounded,
                label: '内存缓存',
                value: cacheLabel,
              ),
            ],
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [intro, const SizedBox(height: 18), metrics],
            );
          }
          return Row(
            children: [
              Expanded(child: intro),
              const SizedBox(width: 22),
              metrics,
            ],
          );
        },
      ),
    );
  }
}

class SettingsSectionCard extends StatelessWidget {
  const SettingsSectionCard({
    super.key,
    required this.indexLabel,
    required this.title,
    required this.description,
    required this.child,
  });

  final String indexLabel;
  final String title;
  final String description;
  final Widget child;

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
              Text(
                indexLabel,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: AppTheme.primaryBlue,
                      letterSpacing: 1.2,
                    ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 4),
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

class ThemePreviewCard extends StatefulWidget {
  const ThemePreviewCard({
    super.key,
    required this.label,
    required this.description,
    required this.dark,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String description;
  final bool dark;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<ThemePreviewCard> createState() => _ThemePreviewCardState();
}

class _ThemePreviewCardState extends State<ThemePreviewCard> {
  bool _hovering = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final highlighted = widget.selected || _hovering || _focused;
    final canvas =
        widget.dark ? const Color(0xFF0D1624) : const Color(0xFFF7FBFE);
    final card =
        widget.dark ? const Color(0xFF131F31) : const Color(0xFFFFFEFC);
    final line =
        widget.dark ? const Color(0xFF2B4156) : const Color(0xFFDCE8EF);
    final text =
        widget.dark ? const Color(0xFFEAF0F4) : const Color(0xFF202830);

    return Semantics(
      button: true,
      selected: widget.selected,
      label: '切换为${widget.label}',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovering = true),
        onExit: (_) => setState(() => _hovering = false),
        child: FocusableActionDetector(
          onShowFocusHighlight: (value) => setState(() => _focused = value),
          actions: {
            ActivateIntent: CallbackAction<ActivateIntent>(
              onInvoke: (_) {
                widget.onTap();
                return null;
              },
            ),
          },
          child: GestureDetector(
            onTap: widget.onTap,
            child: AnimatedContainer(
              duration: AppAnimations.fast,
              height: 190,
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: highlighted
                    ? context.colors.bgHover
                    : context.colors.bgSurface,
                border: Border.all(
                  color: widget.selected
                      ? AppTheme.primaryBlue
                      : (_hovering
                          ? AppTheme.primaryBlue.withValues(alpha: 0.38)
                          : context.colors.divider),
                  width: widget.selected ? 1.4 : 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: canvas,
                        border: Border.all(color: line),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Row(
                        children: [
                          Container(
                            width: 34,
                            color: card,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Column(
                              children: [
                                Container(
                                  width: 15,
                                  height: 15,
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryBlue,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                for (var i = 0; i < 3; i++) ...[
                                  Container(
                                    width: 14,
                                    height: 3,
                                    color: i == 0 ? AppTheme.primaryBlue : line,
                                  ),
                                  const SizedBox(height: 8),
                                ],
                              ],
                            ),
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.all(10),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(width: 62, height: 7, color: text),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      for (var i = 0; i < 3; i++)
                                        Expanded(
                                          child: Container(
                                            height: 46,
                                            margin: EdgeInsets.only(
                                                right: i == 2 ? 0 : 5),
                                            decoration: BoxDecoration(
                                              color: card,
                                              border: Border.all(color: line),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Container(height: 5, color: line),
                                  const SizedBox(height: 5),
                                  FractionallySizedBox(
                                    widthFactor: 0.66,
                                    child: Container(height: 5, color: line),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(
                        widget.selected
                            ? Icons.radio_button_checked_rounded
                            : Icons.radio_button_unchecked_rounded,
                        color: widget.selected
                            ? AppTheme.primaryBlue
                            : context.colors.textMuted,
                        size: 17,
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(widget.label,
                                style: Theme.of(context).textTheme.labelLarge),
                            Text(widget.description,
                                style: Theme.of(context).textTheme.bodySmall),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SettingsActionList extends StatelessWidget {
  const SettingsActionList({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.colors.bgSurface,
        border: Border(
          top: BorderSide(color: context.colors.divider),
          bottom: BorderSide(color: context.colors.divider),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var index = 0; index < children.length; index++) ...[
            children[index],
            if (index != children.length - 1)
              Divider(height: 1, color: context.colors.divider),
          ],
        ],
      ),
    );
  }
}

class SettingsActionRow extends StatefulWidget {
  const SettingsActionRow({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.statusLabel,
    this.statusTone = SettingsStatusTone.neutral,
    this.trailingText,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String? statusLabel;
  final SettingsStatusTone statusTone;
  final String? trailingText;
  final VoidCallback? onTap;

  @override
  State<SettingsActionRow> createState() => _SettingsActionRowState();
}

class _SettingsActionRowState extends State<SettingsActionRow> {
  bool _hovering = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final interactive = widget.onTap != null;
    final highlighted = _hovering || _focused;
    return Semantics(
      button: interactive,
      label: widget.title,
      child: MouseRegion(
        cursor: interactive ? SystemMouseCursors.click : MouseCursor.defer,
        onEnter: interactive ? (_) => setState(() => _hovering = true) : null,
        onExit: interactive ? (_) => setState(() => _hovering = false) : null,
        child: FocusableActionDetector(
          enabled: interactive,
          onShowFocusHighlight: (value) => setState(() => _focused = value),
          actions: interactive
              ? {
                  ActivateIntent: CallbackAction<ActivateIntent>(
                    onInvoke: (_) {
                      widget.onTap!();
                      return null;
                    },
                  ),
                }
              : const {},
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onTap,
            child: AnimatedContainer(
              duration: AppAnimations.fast,
              constraints: const BoxConstraints(minHeight: 70),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              color: highlighted ? context.colors.bgHover : Colors.transparent,
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: highlighted
                          ? AppTheme.primaryBlue.withValues(alpha: 0.13)
                          : context.colors.tagBg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      widget.icon,
                      color: highlighted
                          ? AppTheme.accentBlue
                          : context.colors.textSecondary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(widget.title,
                            style: Theme.of(context).textTheme.titleSmall),
                        const SizedBox(height: 3),
                        Text(widget.subtitle,
                            style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                  ),
                  if (widget.statusLabel != null)
                    _StatusBadge(
                        label: widget.statusLabel!, tone: widget.statusTone),
                  if (widget.trailingText != null) ...[
                    const SizedBox(width: 12),
                    Text(widget.trailingText!,
                        style: Theme.of(context).textTheme.labelMedium),
                  ],
                  if (interactive) ...[
                    const SizedBox(width: 8),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: highlighted
                          ? AppTheme.primaryBlue
                          : context.colors.textMuted,
                      size: 20,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class PluginStatusOverview extends StatelessWidget {
  const PluginStatusOverview({
    super.key,
    required this.enabledCount,
    required this.totalCount,
  });

  final int enabledCount;
  final int totalCount;

  @override
  Widget build(BuildContext context) {
    final ratio = totalCount == 0 ? 0.0 : enabledCount / totalCount;
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: context.colors.bgSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: context.colors.divider),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppTheme.primaryBlue.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(9),
            ),
            child: const Icon(
              Icons.hub_outlined,
              color: AppTheme.primaryBlue,
              size: 21,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '数据源运行状态',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                    Text(
                      '$enabledCount / $totalCount 已启用',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: AppTheme.primaryBlue,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 9),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: ratio,
                    minHeight: 5,
                    backgroundColor: context.colors.tagBg,
                    color: AppTheme.primaryBlue,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class StorageOverview extends StatelessWidget {
  const StorageOverview({
    super.key,
    required this.bytes,
    required this.loading,
    required this.clearing,
    required this.onRefresh,
    required this.onClear,
  });

  final int bytes;
  final bool loading;
  final bool clearing;
  final VoidCallback onRefresh;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    const referenceBytes = 512 * 1024 * 1024;
    final ratio = (bytes / referenceBytes).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.bgSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: context.colors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: context.colors.tagBg,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(
                  Icons.folder_copy_outlined,
                  color: context.colors.textSecondary,
                  size: 21,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('内存缓存', style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 3),
                    Text(
                      loading ? '正在计算占用空间' : _formatBytes(bytes),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: '重新扫描',
                mouseCursor: SystemMouseCursors.click,
                onPressed: loading || clearing ? null : onRefresh,
                icon: const Icon(Icons.refresh_rounded, size: 19),
              ),
              const SizedBox(width: 6),
              OutlinedButton.icon(
                onPressed: loading || clearing ? null : onClear,
                icon: clearing
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.cleaning_services_outlined, size: 17),
                label: Text(clearing ? '正在清理' : '清理缓存'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: loading ? null : ratio,
              minHeight: 6,
              backgroundColor: context.colors.tagBg,
              color: AppTheme.primaryBlue,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            '磁盘封面缓存由系统管理，清理时会一并移除',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _NavigationItem extends StatefulWidget {
  const _NavigationItem({
    required this.destination,
    required this.index,
    required this.selected,
    required this.onTap,
  });

  final SettingsNavDestination destination;
  final int index;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_NavigationItem> createState() => _NavigationItemState();
}

class _NavigationItemState extends State<_NavigationItem> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: AppAnimations.fast,
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: widget.selected
                ? AppTheme.primaryBlue.withValues(alpha: 0.14)
                : (_hovering ? context.colors.bgHover : Colors.transparent),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: widget.selected
                  ? AppTheme.primaryBlue.withValues(alpha: 0.34)
                  : Colors.transparent,
            ),
          ),
          child: Row(
            children: [
              Text(
                '${widget.index + 1}'.padLeft(2, '0'),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: widget.selected
                          ? AppTheme.primaryBlue
                          : context.colors.textMuted,
                    ),
              ),
              const SizedBox(width: 9),
              Icon(
                widget.selected
                    ? widget.destination.selectedIcon
                    : widget.destination.icon,
                size: 18,
                color: widget.selected
                    ? AppTheme.accentBlue
                    : context.colors.textSecondary,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  widget.destination.label,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: widget.selected
                            ? context.colors.textPrimary
                            : context.colors.textSecondary,
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompactNavItem extends StatefulWidget {
  const _CompactNavItem({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final SettingsNavDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_CompactNavItem> createState() => _CompactNavItemState();
}

class _CompactNavItemState extends State<_CompactNavItem> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: AppAnimations.fast,
          padding: const EdgeInsets.symmetric(horizontal: 11),
          decoration: BoxDecoration(
            color: widget.selected
                ? AppTheme.primaryBlue.withValues(alpha: 0.14)
                : (_hovering ? context.colors.bgHover : context.colors.bgCard),
            borderRadius: BorderRadius.circular(7),
            border: Border.all(
              color: widget.selected
                  ? AppTheme.primaryBlue.withValues(alpha: 0.34)
                  : context.colors.divider,
            ),
          ),
          child: Row(
            children: [
              Icon(
                widget.selected
                    ? widget.destination.selectedIcon
                    : widget.destination.icon,
                size: 16,
                color: widget.selected
                    ? AppTheme.primaryBlue
                    : context.colors.textMuted,
              ),
              const SizedBox(width: 6),
              Text(widget.destination.label,
                  style: Theme.of(context).textTheme.labelMedium),
            ],
          ),
        ),
      ),
    );
  }
}

class _SquareIconButton extends StatefulWidget {
  const _SquareIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  State<_SquareIconButton> createState() => _SquareIconButtonState();
}

class _SquareIconButtonState extends State<_SquareIconButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
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
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: context.colors.divider),
            ),
            child: Icon(
              widget.icon,
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

class _HeroMetric extends StatelessWidget {
  const _HeroMetric(
      {required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 126,
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
      decoration: BoxDecoration(
        color: context.colors.bgSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.colors.divider),
      ),
      child: Row(
        children: [
          Icon(icon, size: 17, color: AppTheme.primaryBlue),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.labelSmall),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.tone});

  final String label;
  final SettingsStatusTone tone;

  @override
  Widget build(BuildContext context) {
    final color = switch (tone) {
      SettingsStatusTone.success => AppTheme.scoreGreen,
      SettingsStatusTone.warning => AppTheme.scoreOrange,
      SettingsStatusTone.neutral => context.colors.textMuted,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.25)),
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
            label,
            style:
                Theme.of(context).textTheme.labelSmall?.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

String _formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  final kb = bytes / 1024;
  if (kb < 1024) return '${kb.toStringAsFixed(kb >= 100 ? 0 : 1)} KB';
  final mb = kb / 1024;
  if (mb < 1024) return '${mb.toStringAsFixed(mb >= 100 ? 0 : 1)} MB';
  return '${(mb / 1024).toStringAsFixed(2)} GB';
}
